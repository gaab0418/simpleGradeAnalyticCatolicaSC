/** Caso de uso do servidor: entra no portal e devolve os semestres pedidos. */
import "server-only";
import type { Aluno, Semestre } from "../dominio/tipos";
import type { Credenciais } from "./sessao";
import { ErroPortal, SessaoPortal, type Contexto } from "./totvs";

export interface RespostaBoletim {
  aluno: Aluno;
  /** Todos os períodos em que o aluno tem matrícula. */
  periodos: string[];
  /** Só os que foram consultados agora (os de `pular` ficam de fora). */
  semestres: Semestre[];
}

const MAX_PERIODOS = 24;
const MAX_CONTEXTOS_POR_PERIODO = 4;

export async function baixarBoletim(
  c: Credenciais,
  pular: ReadonlySet<string> = new Set(),
): Promise<RespostaBoletim> {
  const sessao = await SessaoPortal.entrar(c.usuario, c.senha);
  if (sessao.contextos.length === 0) {
    throw new ErroPortal("portal", "O portal não retornou nenhuma matrícula para este usuário.");
  }
  // Um aluno pode ter mais de um contexto no mesmo período.
  const porPeriodo = new Map<string, Contexto[]>();
  for (const ctx of sessao.contextos) {
    porPeriodo.set(ctx.codigo, [...(porPeriodo.get(ctx.codigo) ?? []), ctx]);
  }

  const periodos = [...porPeriodo.keys()].slice(0, MAX_PERIODOS);
  const semestres: Semestre[] = [];
  // Em sequência: o período é escolhido por cookie na sessão do portal.
  for (const codigo of periodos) {
    if (pular.has(codigo)) continue;
    const ctxs = porPeriodo.get(codigo)!.slice(0, MAX_CONTEXTOS_POR_PERIODO);
    const disciplinas = new Map<string, Semestre["disciplinas"][number]>();
    for (const ctx of ctxs) {
      for (const d of await sessao.disciplinas(ctx)) {
        if (!disciplinas.has(d.chave)) disciplinas.set(d.chave, d);
      }
    }
    semestres.push({
      codigo,
      curso: ctxs[0].curso,
      disciplinas: [...disciplinas.values()],
      atualizadoEm: new Date().toISOString(),
    });
  }
  return { aluno: sessao.aluno, periodos, semestres };
}

/** Converte qualquer erro em resposta JSON sem vazar detalhes internos. */
export function respostaDeErro(e: unknown): Response {
  if (e instanceof ErroPortal) {
    const status = e.tipo === "credenciais" ? 401 : e.tipo === "rede" ? 504 : 502;
    return Response.json({ erro: e.message, tipo: e.tipo }, { status, headers: SEM_CACHE });
  }
  return Response.json(
    { erro: "Algo deu errado ao ler os dados do portal.", tipo: "portal" },
    { status: 500, headers: SEM_CACHE },
  );
}

export const SEM_CACHE = { "cache-control": "no-store" } as const;
