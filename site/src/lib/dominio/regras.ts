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
  apertada: S("apertada", 4, "apertado", "Em Risco"),
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

export interface ResultadoNota4 {
  efetivas: [number | null, number | null, number | null];
  indiceSubstituido: 0 | 1 | 2 | null;
  notaSubstituida: number | null;
}

/**
 * Aplica a N4 (substitutiva) sobre a menor das três notas (tratando `null` como `0`),
 * substituindo apenas quando `nota4 >= menor`.
 */
export function aplicarNota4(
  notas: readonly (number | null)[],
  nota4?: number | null,
): ResultadoNota4 {
  const efetivas: [number | null, number | null, number | null] = [
    notas[0] ?? null,
    notas[1] ?? null,
    notas[2] ?? null,
  ];
  if (nota4 === null || nota4 === undefined) {
    return { efetivas, indiceSubstituido: null, notaSubstituida: null };
  }
  let idx: 0 | 1 | 2 = 0;
  for (const i of [1, 2] as const) {
    if ((efetivas[i] ?? 0) < (efetivas[idx] ?? 0)) idx = i;
  }
  const original = efetivas[idx];
  if (original === null || nota4 >= original) {
    efetivas[idx] = nota4;
    return { efetivas, indiceSubstituido: idx, notaSubstituida: original };
  }
  return { efetivas, indiceSubstituido: null, notaSubstituida: null };
}

/** Uma disciplina já interpretada pelas regras. */
export interface Analise {
  disciplina: Disciplina;
  notasEfetivas: [number | null, number | null, number | null];
  nota4: number | null;
  indiceSubstituido: number | null;
  notaSubstituida: number | null;
  soma: number;
  lancadas: number;
  restantes: number;
  /** Média mínima nas provas que faltam para fechar a soma; `null` sem prova pendente. */
  precisa: number | null;
  /** Nota mínima na N4 para fechar a soma 18 substituindo a menor nota; `null` quando indisponível/impossível. */
  precisaN4: number | null;
  situacao: Situacao;
  /** Média oficial quando existe; senão a das notas lançadas. */
  media: number | null;
  /** A média acima já é definitiva. */
  mediaDefinitiva: boolean;
}

export function analisar(d: Disciplina): Analise {
  const nota4 = d.nota4 ?? null;
  const { efetivas, indiceSubstituido, notaSubstituida } = aplicarNota4(d.notas, nota4);
  const lancadas = efetivas.filter((n): n is number => n !== null);
  const soma = lancadas.reduce((a, b) => a + b, 0);
  const restantes = efetivas.length - lancadas.length;
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

  let precisaN4: number | null = null;
  if (
    nota4 === null &&
    lancadas.length > 0 &&
    soma < regras.somaAprovacao &&
    d.faltas <= regras.limiteFaltas &&
    !passou(SITUACOES[id])
  ) {
    const menorNota = Math.min(...efetivas.map((n) => n ?? 0));
    const somaDuasMaiores = soma - menorNota;
    const req = Math.ceil(Math.max(0, regras.somaAprovacao - somaDuasMaiores) * 10 - 1e-9) / 10;
    if (req <= regras.notaMaxima) {
      precisaN4 = req;
    }
  }

  return {
    disciplina: d,
    notasEfetivas: efetivas,
    nota4,
    indiceSubstituido,
    notaSubstituida,
    soma,
    lancadas: lancadas.length,
    restantes,
    precisa,
    precisaN4,
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

/**
 * Semestre consolidado (encerrado ou de ano letivo anterior): pode ficar em cache
 * persistente entre logins, exceto em sincronização completa.
 */
export function semestreConsolidado(s: Semestre, agora = new Date()): boolean {
  if (s.disciplinas.length === 0) return false;
  if (semestreEncerrado(s)) return true;
  const ano = /^\d{4}/.test(s.codigo) ? Number(s.codigo.slice(0, 4)) : NaN;
  return Number.isFinite(ano) && ano < agora.getFullYear();
}

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
  notasEfetivas: [number | null, number | null, number | null];
  indiceSubstituido: number | null;
  notaSubstituida: number | null;
  nota4: number | null;
}

/** "E se eu tirar...": soma as notas lançadas com os palpites, aplicando a N4 quando informada. */
export function simular(
  a: Analise,
  palpites: number[],
  nota4Simulada?: number | null,
): Simulacao {
  const preenchidas: [number | null, number | null, number | null] = [
    a.disciplina.notas[0],
    a.disciplina.notas[1],
    a.disciplina.notas[2],
  ];
  let p = 0;
  for (let i = 0; i < preenchidas.length; i++) {
    if (preenchidas[i] === null && p < palpites.length) {
      preenchidas[i] = palpites[p++];
    }
  }
  const nota4 = nota4Simulada !== undefined ? nota4Simulada : a.nota4;
  const { efetivas, indiceSubstituido, notaSubstituida } = aplicarNota4(preenchidas, nota4);
  const soma = efetivas.reduce<number>((s, v) => s + (v ?? 0), 0);
  const passa = soma >= regras.somaAprovacao;
  return {
    soma,
    passa,
    media: soma / 3,
    faltariam: passa ? 0 : Math.max(0, regras.somaAprovacao - soma),
    notasEfetivas: efetivas,
    indiceSubstituido,
    notaSubstituida,
    nota4,
  };
}
