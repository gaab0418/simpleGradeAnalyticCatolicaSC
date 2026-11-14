/**
 * Estado do site no navegador. As notas ficam só aqui (localStorage, ou
 * sessionStorage quando a pessoa não quis manter o login); o servidor não
 * guarda nada.
 */
"use client";

import { useSyncExternalStore } from "react";
import { historicoDemo } from "../demo";
import { notasNovas } from "../dominio/novidades";
import { periodoPadrao, semestreConsolidado } from "../dominio/regras";
import { ordenarSemestres, type Aluno, type Historico, type Semestre } from "../dominio/tipos";

export type Fase = "carregando" | "deslogado" | "pronto";
export type Aba = "boletim" | "desempenho";

export interface Estado {
  fase: Fase;
  aba: Aba;
  historico: Historico | null;
  periodo: string | null;
  /** O servidor tem o cookie de sessão: dá para atualizar sem digitar a senha. */
  lembrado: boolean;
  demo: boolean;
  ocupado: boolean;
  erro: { mensagem: string; tipo: string } | null;
  novidades: string[];
}

const CHAVE = "boletim.v1";
const CHAVE_PASSADO = "boletim.passado.v1";
const VALIDADE_MS = 15 * 60_000;
const TTL_SALVO_MS = 7 * 86_400_000;

const inicial: Estado = {
  fase: "carregando",
  aba: "boletim",
  historico: null,
  periodo: null,
  lembrado: false,
  demo: false,
  ocupado: false,
  erro: null,
  novidades: [],
};

let estado = inicial;
let sessaoMemoria: { usuario: string; senha: string } | null = null;
let temCookieServidor = false;
let preferirLocal = false;
const ouvintes = new Set<() => void>();

function mudar(parcial: Partial<Estado>) {
  estado = { ...estado, ...parcial };
  ouvintes.forEach((f) => f());
}

export function useLoja(): Estado {
  return useSyncExternalStore(
    (f) => {
      ouvintes.add(f);
      return () => ouvintes.delete(f);
    },
    () => estado,
    () => inicial,
  );
}

// ---------- persistência ----------

interface Salvo {
  historico: Historico;
  lembrado: boolean;
  salvoEm: number;
}

function ler(): Salvo | null {
  for (const area of [localStorage, sessionStorage]) {
    try {
      const bruto = area.getItem(CHAVE);
      if (!bruto) continue;
      const salvo = JSON.parse(bruto) as Partial<Salvo>;
      if (!salvo?.historico?.semestres || !salvo.historico.aluno) continue;
      if (typeof salvo.salvoEm !== "number" || Date.now() - salvo.salvoEm > TTL_SALVO_MS) {
        apagar();
        return null;
      }
      return salvo as Salvo;
    } catch {
      // armazenamento bloqueado ou conteúdo inválido: ignora
    }
  }
  return null;
}

function salvar(historico: Historico, lembrado: boolean, usarLocal = lembrado) {
  apagar();
  try {
    (usarLocal ? localStorage : sessionStorage).setItem(
      CHAVE,
      JSON.stringify({ historico, lembrado, salvoEm: Date.now() } satisfies Salvo),
    );
  } catch {
    // sem espaço ou modo privado: o site segue funcionando só em memória
  }
}

function apagar() {
  for (const area of [localStorage, sessionStorage]) {
    try {
      area.removeItem(CHAVE);
    } catch {
      // nada a fazer
    }
  }
}

interface EntradaPassado {
  ra: string;
  semestres: Semestre[];
}

type ArquivoPassado = Record<string, EntradaPassado>;

const normalizarUsuario = (usuario: string) => usuario.trim().toLowerCase();

function lerArquivoPassado(): ArquivoPassado {
  try {
    const bruto = localStorage.getItem(CHAVE_PASSADO);
    if (!bruto) return {};
    const json: unknown = JSON.parse(bruto);
    if (typeof json !== "object" || json === null || Array.isArray(json)) return {};
    const valido: ArquivoPassado = {};
    for (const [k, v] of Object.entries(json)) {
      if (
        typeof v === "object" &&
        v !== null &&
        !Array.isArray(v) &&
        typeof (v as Partial<EntradaPassado>).ra === "string" &&
        Array.isArray((v as Partial<EntradaPassado>).semestres)
      ) {
        valido[k] = {
          ra: (v as EntradaPassado).ra,
          semestres: (v as EntradaPassado).semestres.filter(
            (s): s is Semestre =>
              typeof s === "object" &&
              s !== null &&
              typeof s.codigo === "string" &&
              Array.isArray(s.disciplinas),
          ),
        };
      }
    }
    return valido;
  } catch {
    return {};
  }
}

function lerPassado(usuario: string): Semestre[] {
  const chave = normalizarUsuario(usuario);
  if (!chave) return [];
  const entrada = lerArquivoPassado()[chave];
  return (entrada?.semestres ?? []).filter((s) => semestreConsolidado(s));
}

function salvarPassado(historico: Historico, usuario?: string | null) {
  try {
    const arquivo = lerArquivoPassado();
    const chavePorUsuario = usuario ? normalizarUsuario(usuario) : "";
    const chavePorRa =
      !chavePorUsuario && historico.aluno.ra
        ? (Object.entries(arquivo).find(([, e]) => e.ra === historico.aluno.ra)?.[0] ?? "")
        : "";
    const chave = chavePorUsuario || chavePorRa;
    if (!chave) return;

    const consolidados = ordenarSemestres(
      historico.semestres.filter((s) => semestreConsolidado(s)),
    );
    arquivo[chave] = {
      ra: historico.aluno.ra || arquivo[chave]?.ra || "",
      semestres: consolidados,
    };
    localStorage.setItem(CHAVE_PASSADO, JSON.stringify(arquivo));
  } catch {
    // sem espaço ou modo privado: o site segue funcionando só em memória
  }
}

// ---------- API do próprio site ----------

interface RespostaApi {
  aluno: Aluno;
  periodos: string[];
  semestres: Semestre[];
  lembrado?: boolean;
}

class ErroApi extends Error {
  constructor(
    mensagem: string,
    readonly tipo: string,
  ) {
    super(mensagem);
  }
}

async function chamar(rota: string, corpo: unknown): Promise<RespostaApi> {
  let resp: Response;
  try {
    resp = await fetch(rota, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(corpo),
      credentials: "same-origin",
    });
  } catch {
    throw new ErroApi("Sem conexão. Confira sua internet.", "rede");
  }
  const json = await resp.json().catch(() => null);
  if (!resp.ok) {
    throw new ErroApi(json?.erro ?? `O servidor respondeu ${resp.status}.`, json?.tipo ?? "portal");
  }
  return json as RespostaApi;
}

/** Junta o que veio agora com o que já estava salvo, mantendo só períodos que ainda existem. */
function mesclar(anterior: Historico | null, r: RespostaApi): Historico {
  const novos = new Map(r.semestres.map((s) => [s.codigo, s]));
  const semestres = r.periodos
    .map((cod) => novos.get(cod) ?? anterior?.semestres.find((s) => s.codigo === cod))
    .filter((s): s is Semestre => s !== undefined);
  return { aluno: r.aluno, semestres: ordenarSemestres(semestres) };
}

function periodoInicial(h: Historico): string | null {
  const padrao = periodoPadrao(new Date());
  return (h.semestres.find((s) => s.codigo === padrao) ?? h.semestres[0])?.codigo ?? null;
}

// ---------- ações ----------

export const acoes = {
  iniciar() {
    if (estado.fase !== "carregando") return;
    const salvo = ler();
    if (!salvo) return mudar({ fase: "deslogado" });
    temCookieServidor = salvo.lembrado;
    preferirLocal = salvo.lembrado;
    mudar({
      fase: "pronto",
      historico: salvo.historico,
      periodo: periodoInicial(salvo.historico),
      lembrado: salvo.lembrado,
    });
    const ultima = Math.max(0, ...salvo.historico.semestres.map((s) => Date.parse(s.atualizadoEm) || 0));
    if (salvo.lembrado && Date.now() - ultima > VALIDADE_MS) void acoes.sincronizar();
  },

  /** Devolve a mensagem de erro, ou `null` se entrou. */
  async entrar(usuario: string, senha: string, lembrar: boolean): Promise<string | null> {
    mudar({ ocupado: true, erro: null });
    try {
      const passado = lerPassado(usuario);
      const r = await chamar("/api/entrar", {
        usuario,
        senha,
        lembrar,
        pular: passado.map((s) => s.codigo),
      });
      const historico = mesclar(passado.length ? { aluno: r.aluno, semestres: passado } : null, r);
      temCookieServidor = r.lembrado === true;
      preferirLocal = lembrar;
      sessaoMemoria = { usuario: usuario.trim(), senha };
      salvar(historico, temCookieServidor, preferirLocal);
      if (lembrar) salvarPassado(historico, usuario);
      mudar({
        fase: "pronto",
        aba: "boletim",
        demo: false,
        historico,
        periodo: periodoInicial(historico),
        lembrado: true,
        novidades: [],
      });
      return null;
    } catch (e) {
      return e instanceof Error ? e.message : "Algo deu errado.";
    } finally {
      mudar({ ocupado: false });
    }
  },

  entrarDemo() {
    sessaoMemoria = null;
    temCookieServidor = false;
    preferirLocal = false;
    const historico = historicoDemo();
    mudar({
      fase: "pronto",
      aba: "boletim",
      demo: true,
      historico,
      periodo: periodoInicial(historico),
      lembrado: false,
      erro: null,
      novidades: [],
    });
  },

  /** Semestres consolidados só são buscados de novo com `completo`. */
  async sincronizar(completo = false) {
    const anterior = estado.historico;
    if (estado.ocupado || estado.demo || !estado.lembrado || !anterior) return;
    mudar({ ocupado: true, erro: null });
    try {
      const pular = completo
        ? []
        : anterior.semestres.filter((s) => semestreConsolidado(s)).map((s) => s.codigo);
      const historico = mesclar(
        anterior,
        await chamar("/api/sincronizar", { pular, ...(sessaoMemoria ?? {}) }),
      );
      salvar(historico, temCookieServidor, preferirLocal);
      if (preferirLocal) salvarPassado(historico, sessaoMemoria?.usuario);
      mudar({
        historico,
        novidades: notasNovas(anterior, historico),
        periodo: historico.semestres.some((s) => s.codigo === estado.periodo)
          ? estado.periodo
          : periodoInicial(historico),
      });
    } catch (e) {
      const erro = e instanceof ErroApi ? e : new ErroApi("Algo deu errado.", "portal");
      // Sessão inválida: o cookie já foi apagado pelo servidor.
      if (erro.tipo === "credenciais") {
        sessaoMemoria = null;
        temCookieServidor = false;
        salvar(anterior, false, preferirLocal);
      }
      mudar({
        erro: { mensagem: erro.message, tipo: erro.tipo },
        lembrado: erro.tipo === "credenciais" ? false : estado.lembrado,
      });
    } finally {
      mudar({ ocupado: false });
    }
  },

  /** Apaga o cookie de sessão e tudo o que está salvo neste navegador. */
  async sair() {
    const eraDemo = estado.demo;
    sessaoMemoria = null;
    temCookieServidor = false;
    preferirLocal = false;
    apagar();
    mudar({ ...inicial, fase: "deslogado" });
    if (!eraDemo) {
      const encerrar = () => fetch("/api/sair", { method: "POST", credentials: "same-origin" });
      try {
        const resp = await encerrar();
        if (!resp.ok) await encerrar().catch(() => {});
      } catch {
        await encerrar().catch(() => {});
      }
    }
  },

  selecionarPeriodo: (periodo: string) => mudar({ periodo }),
  abrirAba: (aba: Aba) => mudar({ aba }),
  dispensarNovidades: () => mudar({ novidades: [] }),
  dispensarErro: () => mudar({ erro: null }),
};
