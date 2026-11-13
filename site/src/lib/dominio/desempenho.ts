/** Análise de desempenho ao longo do curso, calculada só com o histórico local. */
import { regras } from "../config";
import { fmt, nomeMateria, rotuloPeriodo } from "./formato";
import { analisar, passou, semestreEncerrado, type Analise } from "./regras";
import type { Historico } from "./tipos";

const media = (v: number[]) => (v.length ? v.reduce((a, b) => a + b, 0) / v.length : null);

export interface ResumoSemestre {
  codigo: string;
  rotulo: string;
  encerrado: boolean;
  faltas: number;
  /** Média das disciplinas; parcial enquanto o semestre está em andamento. */
  media: number | null;
  analises: Analise[];
}

export interface MateriaRanqueada {
  nome: string;
  periodo: string;
  media: number;
}

export interface Faixa {
  rotulo: string;
  quantidade: number;
  abaixoDaMedia: boolean;
}

export interface Desempenho {
  /** Do mais antigo para o mais recente, só semestres com matéria. */
  semestres: ResumoSemestre[];
  /** Semestres com média, na ordem do gráfico de evolução. */
  evolucao: (ResumoSemestre & { media: number })[];
  concluidas: number;
  aprovadas: number;
  mediaGeral: number | null;
  taxaAprovacao: number | null;
  faltasTotais: number;
  /** Diferença de média entre os dois últimos semestres encerrados. */
  tendencia: number | null;
  melhorSemestre: (ResumoSemestre & { media: number }) | null;
  /** Média geral em cada etapa (N1, N2, N3). */
  mediaPorEtapa: (number | null)[];
  distribuicao: Faixa[];
  melhores: MateriaRanqueada[];
  piores: MateriaRanqueada[];
  /** Quanto a média cai nas matérias com mais faltas; `null` sem base para comparar. */
  custoDasFaltas: number | null;
  observacoes: string[];
}

export function calcularDesempenho(h: Historico, top = 3): Desempenho {
  const semestres: ResumoSemestre[] = [...h.semestres]
    .reverse()
    .filter((s) => s.disciplinas.length > 0)
    .map((s) => {
      const analises = s.disciplinas.map(analisar);
      return {
        codigo: s.codigo,
        rotulo: rotuloPeriodo(s.codigo),
        encerrado: semestreEncerrado(s),
        faltas: analises.reduce((a, x) => a + x.disciplina.faltas, 0),
        media: media(analises.map((a) => a.media).filter((m): m is number => m !== null)),
        analises,
      };
    });

  const todas = semestres.flatMap((s) => s.analises);
  // Só disciplinas com resultado definitivo entram nas médias do curso.
  const concluidas = todas.filter((a) => a.mediaDefinitiva && a.media !== null);
  const medias = concluidas.map((a) => a.media!);

  const evolucao = semestres.filter(
    (s): s is ResumoSemestre & { media: number } => s.media !== null,
  );
  const fechados = evolucao.filter((s) => s.encerrado);
  const tendencia =
    fechados.length < 2 ? null : fechados.at(-1)!.media - fechados.at(-2)!.media;
  const melhorSemestre = fechados.length
    ? fechados.reduce((a, b) => (b.media > a.media ? b : a))
    : null;

  const mediaPorEtapa = [0, 1, 2].map((i) =>
    media(todas.map((a) => a.disciplina.notas[i]).filter((n): n is number => n !== null)),
  );

  const entre = (de: number, ate: number) => medias.filter((m) => m >= de && m < ate).length;
  const distribuicao: Faixa[] = [
    { rotulo: "Abaixo de 6", quantidade: entre(0, regras.notaMinima), abaixoDaMedia: true },
    { rotulo: "6 a 6,9", quantidade: entre(6, 7), abaixoDaMedia: false },
    { rotulo: "7 a 7,9", quantidade: entre(7, 8), abaixoDaMedia: false },
    { rotulo: "8 a 8,9", quantidade: entre(8, 9), abaixoDaMedia: false },
    { rotulo: "9 a 10", quantidade: entre(9, 10.01), abaixoDaMedia: false },
  ];

  const ranking: MateriaRanqueada[] = semestres
    .flatMap((s) =>
      s.analises
        .filter((a) => a.mediaDefinitiva && a.media !== null)
        .map((a) => ({
          nome: nomeMateria(a.disciplina.nome).nome,
          periodo: s.rotulo,
          media: a.media!,
        })),
    )
    .sort((a, b) => b.media - a.media);

  // Metade com menos faltas contra metade com mais faltas.
  let custoDasFaltas: number | null = null;
  if (concluidas.length >= 6) {
    const ord = [...concluidas].sort((a, b) => a.disciplina.faltas - b.disciplina.faltas);
    const meio = Math.floor(ord.length / 2);
    const poucas = ord.slice(0, meio);
    const muitas = ord.slice(ord.length - meio);
    if (poucas.at(-1)!.disciplina.faltas !== muitas[0].disciplina.faltas) {
      custoDasFaltas =
        media(poucas.map((a) => a.media!))! - media(muitas.map((a) => a.media!))!;
    }
  }

  const aprovadas = concluidas.filter((a) => passou(a.situacao)).length;
  const observacoes: string[] = [];
  if (tendencia !== null && Math.abs(tendencia) >= 0.2) {
    observacoes.push(
      tendencia > 0
        ? `Sua média subiu ${fmt(tendencia)} no último semestre encerrado.`
        : `Sua média caiu ${fmt(-tendencia)} no último semestre encerrado.`,
    );
  }
  if (mediaPorEtapa.every((v) => v !== null)) {
    const d = mediaPorEtapa[2]! - mediaPorEtapa[0]!;
    if (d >= 0.4) observacoes.push(`Você costuma melhorar ao longo do semestre: a N3 fica ${fmt(d)} acima da N1.`);
    else if (d <= -0.4) observacoes.push(`Você começa bem e cai no fim: a N3 fica ${fmt(-d)} abaixo da N1.`);
  }
  if (custoDasFaltas !== null && custoDasFaltas >= 0.3) {
    observacoes.push(`Nas matérias em que você mais falta, a média é ${fmt(custoDasFaltas)} menor.`);
  }
  if (melhorSemestre && fechados.length > 1) {
    observacoes.push(`Melhor semestre: ${melhorSemestre.rotulo}, com média ${fmt(melhorSemestre.media)}.`);
  }
  if (concluidas.length >= 4 && aprovadas === concluidas.length) {
    observacoes.push(`Nenhuma reprovação em ${concluidas.length} matérias.`);
  }

  return {
    semestres,
    evolucao,
    concluidas: concluidas.length,
    aprovadas,
    mediaGeral: media(medias),
    taxaAprovacao: concluidas.length ? aprovadas / concluidas.length : null,
    faltasTotais: semestres.reduce((a, s) => a + s.faltas, 0),
    tendencia,
    melhorSemestre,
    mediaPorEtapa,
    distribuicao,
    melhores: ranking.slice(0, top),
    piores: ranking.slice(top).reverse().slice(0, top),
    custoDasFaltas,
    observacoes,
  };
}
