/**
 * Tudo o que é específico da instituição fica aqui. Para adaptar o site a
 * outro portal TOTVS RM, troque estes valores (ou as variáveis de ambiente).
 */
export const instituicao = {
  nome: process.env.NEXT_PUBLIC_INSTITUICAO ?? "Grade Analytic",
  /** Só o servidor usa. Sem barra no fim. */
  portal: process.env.PORTAL_URL ?? "https://portal.catolicasc.org.br",
} as const;

export const regras = {
  /** Soma das três notas para aprovar (média 6). */
  somaAprovacao: 18,
  notaMaxima: 10,
  notaMinima: 6,
  /** Acima disso reprova por falta (5 dias de 4 aulas). */
  limiteFaltas: 20,
  /** Limite de faltas no PAC (2 dias de 4 aulas). */
  limiteFaltasPac: 8,
  aulasPorDia: 4,
  /** A partir daqui resta só um dia de falta. */
  alertaFaltas: 16,
  /** A partir daqui resta só um dia de falta no PAC. */
  alertaFaltasPac: 4,
} as const;
