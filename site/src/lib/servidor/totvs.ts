/**
 * Cliente do portal TOTVS RM. Roda só no servidor: o navegador não consegue
 * chamar o portal direto porque ele não envia cabeçalhos CORS.
 * Nada aqui é gravado nem logado; a senha existe só durante a requisição.
 */
import "server-only";
import { instituicao } from "../config";
import type { Aluno, Disciplina } from "../dominio/tipos";

export type Falha = "credenciais" | "rede" | "portal";

export class ErroPortal extends Error {
  constructor(
    readonly tipo: Falha,
    mensagem: string,
  ) {
    super(mensagem);
  }
}

export interface Contexto {
  /** IDCONTEXTOALUNO: valor do cookie que seleciona o período no portal. */
  id: string;
  codigo: string;
  curso: string;
}

const APP = "/FrameHTML/web/app/edu/PortalEducacional/";
const API = "/FrameHTML/RM/API/";
const COOKIE_CONTEXTO = "EduContextoAlunoResponsavelAPI";
const TEMPO_LIMITE_MS = 20_000;
const USER_AGENT =
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36";

const txt = (v: unknown) => (v === null || v === undefined ? "" : String(v));

/** O portal embrulha notas baixas em HTML (`<font color=red>3,3</font>`) e usa vírgula. */
export function parseNota(valor: unknown): number | null {
  if (valor === null || valor === undefined) return null;
  if (typeof valor === "number") return Number.isFinite(valor) ? valor : null;
  const limpo = String(valor).replace(/<[^>]+>/g, "").trim().replace(",", ".");
  if (limpo === "") return null;
  const n = Number(limpo);
  return Number.isFinite(n) ? n : null;
}

type Registro = Record<string, unknown>;
const registros = (v: unknown): Registro[] =>
  Array.isArray(v) ? v.filter((x): x is Registro => typeof x === "object" && x !== null) : [];

/** Cruza NotaEtapa com FaltaEtapa por IDTURMADISC. */
export function montarDisciplinas(notas: unknown, faltas: unknown): Disciplina[] {
  const faltasPorTurma = new Map(
    registros(faltas)
      .filter((f) => f.IDTURMADISC != null)
      .map((f) => [txt(f.IDTURMADISC), f]),
  );
  return registros(notas).map((n) => ({
    chave: txt(n.IDTURMADISC ?? n.CODDISC),
    codTurma: txt(n.CODTURMA),
    codDisc: txt(n.CODDISC),
    nome: txt(n.DISCIPLINA),
    situacao: txt(n.SITUACAO),
    notas: [
      parseNota(n["1 - Nota 1"]),
      parseNota(n["2 - Nota 2"]),
      parseNota(n["3 - Nota 3"]),
    ],
    mediaFinal: parseNota(n["6 - Média Final"] ?? n["4 - Média Final"]),
    faltas: Math.trunc(
      parseNota(faltasPorTurma.get(txt(n.IDTURMADISC))?.["1 - Faltas Sala de Aula"]) ?? 0,
    ),
  }));
}

interface Resposta {
  status: number;
  /** `null` quando o corpo não é JSON (página de erro em HTML, por exemplo). */
  json: unknown;
}

export class SessaoPortal {
  private readonly cookies = new Map<string, string>();
  aluno: Aluno = { nome: "", ra: "", curso: "" };
  contextos: Contexto[] = [];

  private constructor(
    private readonly base: URL,
    private readonly buscar: typeof fetch,
  ) {}

  /** Autentica e lê os períodos do aluno. Lança `ErroPortal`. */
  static async entrar(
    usuario: string,
    senha: string,
    opcoes: { base?: string; fetch?: typeof fetch } = {},
  ): Promise<SessaoPortal> {
    const s = new SessaoPortal(
      new URL(opcoes.base ?? instituicao.portal),
      opcoes.fetch ?? fetch,
    );
    await s.autenticar(usuario, senha);
    return s;
  }

  private async autenticar(usuario: string, senha: string) {
    // 1. Página inicial: recebe os cookies de sessão.
    await this.requisitar("GET", APP);
    if (!this.cookies.has("DefaultAlias")) this.cookies.set("DefaultAlias", "CorporeRM");
    if (!this.cookies.has("EduMascaras")) {
      this.cookies.set(
        "EduMascaras",
        '{"mascaraTelefone": "(99) 9?9999-9999", "mascaraCEP": ""}',
      );
    }

    // 2. Login.
    const login = await this.requisitar("POST", `${API}TOTVSEducacional/Login`, {
      corpo: { user: usuario, password: senha, alias: "CorporeRM" },
      referer: `${APP}login/`,
    });
    const token =
      login.status === 200
        ? (login.json as { data?: { value?: unknown } } | null)?.data?.value
        : null;
    if (typeof token !== "string" || token === "") {
      throw login.status >= 500
        ? new ErroPortal("portal", "O portal está fora do ar. Tente de novo em instantes.")
        : new ErroPortal("credenciais", "Usuário ou senha não conferem com o portal.");
    }

    // 3. O token é um contexto em base64; vira cookie e chave de auto-login.
    let chave: string;
    try {
      chave = decodeURIComponent(token);
      this.cookies.set(COOKIE_CONTEXTO, Buffer.from(chave, "base64").toString("utf8"));
    } catch {
      throw new ErroPortal("portal", "O portal respondeu de um jeito inesperado no login.");
    }
    await this.requisitar("GET", `${API}user/AutoLoginPortal?key=${encodeURIComponent(chave)}`);

    // 4. Períodos letivos.
    const dados = registros(
      this.dados(await this.requisitar("GET", `${API}TOTVSEducacional/Contexto`)),
    );
    this.contextos = dados
      .filter((c) => txt(c.IDCONTEXTOALUNO) !== "")
      .map((c) => ({
        id: txt(c.IDCONTEXTOALUNO),
        codigo: txt(c.CODPERLET),
        curso: txt(c.NOMECURSO),
      }));
    const primeiro = dados[0];
    this.aluno = {
      nome: txt(primeiro?.NOMEALUNO),
      ra: txt(primeiro?.RA),
      curso: txt(primeiro?.NOMECURSO),
    };
  }

  async disciplinas(contexto: Contexto): Promise<Disciplina[]> {
    this.cookies.set(COOKIE_CONTEXTO, contexto.id);
    const notas = this.dados(await this.requisitar("GET", `${API}TOTVSEducacional/NotaEtapa`));
    const faltas = this.dados(await this.requisitar("GET", `${API}TOTVSEducacional/FaltaEtapa`));
    return montarDisciplinas(
      (notas as Registro | null)?.Notas,
      (faltas as Registro | null)?.FaltasEtapa,
    );
  }

  private dados(r: Resposta): unknown {
    if (r.status === 401 || r.status === 403) {
      throw new ErroPortal("credenciais", "O portal encerrou a sessão. Entre de novo.");
    }
    if (r.status !== 200 || typeof r.json !== "object" || r.json === null) {
      throw new ErroPortal(
        "portal",
        `O portal respondeu com erro (${r.status}). Tente de novo em instantes.`,
      );
    }
    return (r.json as Registro).data;
  }

  /**
   * Cookies próprios e redirecionamento manual: os cookies de cada salto são
   * guardados e nada (senha, sessão) sai do host do portal.
   */
  private async requisitar(
    metodo: "GET" | "POST",
    caminho: string,
    opcoes: { corpo?: unknown; referer?: string } = {},
  ): Promise<Resposta> {
    let url = new URL(caminho, this.base);
    let corpo = opcoes.corpo;
    for (let salto = 0; salto < 6; salto++) {
      if (url.origin !== this.base.origin) {
        throw new ErroPortal("portal", "O portal tentou redirecionar para outro endereço.");
      }
      const headers: Record<string, string> = {
        accept: "application/json, text/plain, */*",
        "accept-language": "pt-BR,pt;q=0.9",
        "user-agent": USER_AGENT,
        referer: new URL(opcoes.referer ?? APP, this.base).toString(),
      };
      if (this.cookies.size) {
        headers.cookie = [...this.cookies].map(([k, v]) => `${k}=${v}`).join("; ");
      }
      if (corpo !== undefined) {
        headers["content-type"] = "application/json;charset=UTF-8";
        headers.origin = this.base.origin;
      }

      let resp: Response;
      try {
        resp = await this.buscar(url, {
          method: metodo,
          headers,
          body: corpo === undefined ? undefined : JSON.stringify(corpo),
          redirect: "manual",
          cache: "no-store",
          signal: AbortSignal.timeout(TEMPO_LIMITE_MS),
        });
      } catch (e) {
        throw new ErroPortal(
          "rede",
          e instanceof Error && e.name === "TimeoutError"
            ? "O portal demorou demais para responder."
            : "Não foi possível falar com o portal agora.",
        );
      }
      this.guardarCookies(resp);

      const destino = resp.headers.get("location");
      if (resp.status >= 300 && resp.status < 400 && destino) {
        await resp.body?.cancel();
        url = new URL(destino, url);
        if (resp.status !== 307 && resp.status !== 308) {
          metodo = "GET";
          corpo = undefined;
        }
        continue;
      }
      const texto = await resp.text();
      let json: unknown = null;
      try {
        json = JSON.parse(texto);
      } catch {
        // corpo não é JSON
      }
      return { status: resp.status, json };
    }
    throw new ErroPortal("portal", "O portal entrou em um ciclo de redirecionamentos.");
  }

  private guardarCookies(resp: Response) {
    for (const linha of resp.headers.getSetCookie()) {
      const par = linha.split(";")[0];
      const i = par.indexOf("=");
      if (i <= 0) continue;
      const nome = par.slice(0, i).trim();
      const valor = par.slice(i + 1).trim();
      if (valor === "") this.cookies.delete(nome);
      else this.cookies.set(nome, valor);
    }
  }
}
