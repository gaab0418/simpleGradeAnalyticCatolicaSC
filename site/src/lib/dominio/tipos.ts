export interface Aluno {
  nome: string;
  ra: string;
  curso: string;
}

export interface Disciplina {
  /** IDTURMADISC do portal (ou CODDISC quando ele não vem). */
  chave: string;
  codTurma: string;
  codDisc: string;
  /** Nome como vem do portal: "MATÉRIA - SIGLA". */
  nome: string;
  /** Situação oficial do portal ("Aprovado", "Matriculado"...). */
  situacao: string;
  /** N1, N2 e N3; `null` = ainda não lançada. */
  notas: [number | null, number | null, number | null];
  mediaFinal: number | null;
  faltas: number;
}

export interface Semestre {
  /** CODPERLET do portal, ex.: "202623". */
  codigo: string;
  curso: string;
  disciplinas: Disciplina[];
  /** ISO 8601. */
  atualizadoEm: string;
}

export interface Historico {
  aluno: Aluno;
  /** Do mais recente para o mais antigo. */
  semestres: Semestre[];
}

export function ordenarSemestres(semestres: Semestre[]): Semestre[] {
  return [...semestres].sort((a, b) => b.codigo.localeCompare(a.codigo));
}
