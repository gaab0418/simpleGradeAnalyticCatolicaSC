/**
 * Regras acadêmicas. A situação de uma matéria é dada pela média que ainda
 * falta tirar nas provas restantes, não pelo total de pontos que faltam.
 * (Mesma lógica do app mobile, em mobile/lib/domain/regras.dart.)
 */
import { regras } from "../config";
import type { Disciplina, Semestre } from "./tipos";

export type Tom = "ok" | "calmo" | "atencao" | "apertado" | "critico" | "neutro";

export type SituacaoId =
  | "reprovadaPorFalta"
  | "reprovada"
  | "foraDeAlcance"
  | "critica"
  | "limiteDeFaltas"
  | "apertada"
  | "atencao"
  | "tranquila"
  | "semNotas"
  | "garantida"
  | "aprovada";

export interface Situacao {
  id: SituacaoId;
  /** Maior = aparece primeiro no boletim. */
  urgencia: number;
  tom: Tom;
  rotulo: string;
}

const S = (id: SituacaoId, urgencia: number, tom: Tom, rotulo: string): Situacao => ({
  id,
  urgencia,
  tom,
  rotulo,
});

export const SITUACOES: Record<SituacaoId, Situacao> = {
  reprovadaPorFalta: S("reprovadaPorFalta", 9, "critico", "Reprovada por falta"),
  reprovada: S("reprovada", 8, "critico", "Reprovada"),
  foraDeAlcance: S("foraDeAlcance", 7, "critico", "Fora de alcance"),
  critica: S("critica", 6, "critico", "Crítica"),
  limiteDeFaltas: S("limiteDeFaltas", 5, "apertado", "Limite de faltas"),
  apertada: S("apertada", 4, "apertado", "Apertada"),
  atencao: S("atencao", 3, "atencao", "Atenção"),
  tranquila: S("tranquila", 2, "calmo", "Tranquila"),
  semNotas: S("semNotas", 1, "neutro", "Sem notas"),
  garantida: S("garantida", 0, "ok", "Garantida"),
  aprovada: S("aprovada", 0, "ok", "Aprovada"),
};

export const passou = (s: Situacao) => s.id === "garantida" || s.id === "aprovada";

/** Resultado definitivo: não há mais o que simular. */
export const encerrada = (s: Situacao) =>
  s.id === "aprovada" || s.id === "reprovada" || s.id === "reprovadaPorFalta";

function porNecessidade(media: number): SituacaoId {
  if (media > regras.notaMaxima) return "foraDeAlcance";
  if (media > 8.5) return "critica";
  if (media > 7) return "apertada";
  if (media > 5) return "atencao";
  return "tranquila";
}

/** Uma disciplina já interpretada pelas regras. */
export interface Analise {
  disciplina: Disciplina;
  soma: number;
  lancadas: number;
  restantes: number;
  /** Média mínima nas provas que faltam para fechar a soma; `null` sem prova pendente. */
  precisa: number | null;
  situacao: Situacao;
  /** Média oficial quando existe; senão a das notas lançadas. */
  media: number | null;
  /** A média acima já é definitiva. */
  mediaDefinitiva: boolean;
}

export function analisar(d: Disciplina): Analise {
  const lancadas = d.notas.filter((n): n is number => n !== null);
  const soma = lancadas.reduce((a, b) => a + b, 0);
  const restantes = d.notas.length - lancadas.length;
  const faltam = Math.max(0, regras.somaAprovacao - soma);
  // Arredonda para cima em 1 casa; o epsilon evita que um erro de ponto
  // flutuante (41,00000001) suba a exigência um décimo à toa.
  const precisa = restantes > 0 ? Math.ceil((faltam / restantes) * 10 - 1e-9) / 10 : null;
  const oficial = d.situacao.toLowerCase();

  let id: SituacaoId;
  if (d.faltas > regras.limiteFaltas) id = "reprovadaPorFalta";
  else if (oficial.startsWith("aprov")) id = "aprovada";
  else if (oficial.startsWith("reprov")) id = "reprovada";
  else if (lancadas.length === 0) id = "semNotas";
  else if (soma >= regras.somaAprovacao) id = "garantida";
  else if (restantes === 0) id = "reprovada";
  else id = porNecessidade(precisa!);

  // Faltas perto do limite pesam mais que nota tranquila.
  if (
    d.faltas >= regras.alertaFaltas &&
    SITUACOES[id].urgencia < SITUACOES.limiteDeFaltas.urgencia
  ) {
    id = "limiteDeFaltas";
  }

  return {
    disciplina: d,
    soma,
    lancadas: lancadas.length,
    restantes,
    precisa,
    situacao: SITUACOES[id],
    media: d.mediaFinal ?? (lancadas.length ? soma / lancadas.length : null),
    mediaDefinitiva: d.mediaFinal !== null || restantes === 0,
  };
}

/** Analisa e ordena: o mais urgente primeiro. */
export function analisarSemestre(s: Semestre): Analise[] {
  return s.disciplinas
    .map(analisar)
    .sort(
      (a, b) =>
        b.situacao.urgencia - a.situacao.urgencia || (b.precisa ?? 0) - (a.precisa ?? 0),
    );
}

/** Semestre fechado: nada mais muda no portal, não precisa buscar de novo. */
export const semestreEncerrado = (s: Semestre) =>
  s.disciplinas.length > 0 && s.disciplinas.every((d) => encerrada(analisar(d).situacao));

/** Período vigente pela data: até 01/08 é o primeiro (AAAA11), depois o segundo (AAAA23). */
export function periodoPadrao(agora: Date): string {
  const mes = agora.getMonth() + 1;
  const primeiro = mes < 8 || (mes === 8 && agora.getDate() === 1);
  return `${agora.getFullYear()}${primeiro ? "11" : "23"}`;
}

export interface Simulacao {
  soma: number;
  passa: boolean;
  media: number;
  faltariam: number;
}

/** "E se eu tirar...": soma as notas lançadas com os palpites. */
export function simular(a: Analise, palpites: number[]): Simulacao {
  const soma = palpites.reduce((s, v) => s + v, a.soma);
  const passa = soma >= regras.somaAprovacao;
  return { soma, passa, media: soma / 3, faltariam: passa ? 0 : regras.somaAprovacao - soma };
}
