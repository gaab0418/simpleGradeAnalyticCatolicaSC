/** A frase-resumo do semestre: onde está o foco agora. */
import { regras } from "../config";
import { fmt, nomeMateria } from "./formato";
import { SITUACOES, encerrada, passou, type Analise } from "./regras";

export interface ResumoBoletim {
  titulo: string;
  /** Recomendação em uma linha; vazia quando não há o que destacar. */
  foco: string;
  materias: number;
  garantidas: number;
  semNota: number;
  faltas: number;
}

/** `materias` já ordenadas por urgência (ver `analisarSemestre`). */
export function resumir(materias: Analise[]): ResumoBoletim {
  const n = materias.length;
  const ok = materias.filter((m) => passou(m.situacao)).length;
  const fechado = n > 0 && materias.every((m) => encerrada(m.situacao));
  const rf = materias.find((m) => m.situacao.id === "reprovadaPorFalta");
  const alvo = materias.find(
    (m) =>
      m.restantes > 0 &&
      (m.precisa ?? 0) > 0 &&
      m.situacao.urgencia >= SITUACOES.atencao.urgencia,
  );
  const nome = (a: Analise) => nomeMateria(a.disciplina.nome).nome;

  let titulo: string;
  let foco = "";
  if (n === 0) {
    titulo = "Nada lançado neste semestre";
  } else if (fechado) {
    const medias = materias
      .map((m) => m.disciplina.mediaFinal)
      .filter((v): v is number => v !== null);
    titulo = `Semestre encerrado: ${ok} de ${n} aprovadas`;
    if (medias.length) {
      foco = `Média geral ${fmt(medias.reduce((a, b) => a + b, 0) / medias.length)}.`;
    }
  } else {
    titulo =
      ok === 0
        ? `Nenhuma das ${n} matérias garantida ainda`
        : ok === n
          ? `Todas as ${n} matérias garantidas`
          : `${ok} de ${n} matérias garantidas`;
    if (rf) {
      foco = `${nome(rf)} passou do limite de faltas.`;
    } else if (alvo) {
      const precisa = alvo.precisa!;
      foco =
        precisa > regras.notaMaxima
          ? `${nome(alvo)}: nem com 10 fecha média 6. Vale conversar com o professor.`
          : alvo.restantes === 1
            ? `Prioridade: ${nome(alvo)} precisa de ${fmt(precisa)} na última prova.`
            : `Prioridade: ${nome(alvo)} precisa de média ${fmt(precisa)} nas ${alvo.restantes} provas que faltam.`;
    } else if (ok < n) {
      foco = "Nenhuma matéria pede mais que média 5 no que falta.";
    }
  }

  return {
    titulo,
    foco,
    materias: n,
    garantidas: ok,
    semNota: materias.filter((m) => m.situacao.id === "semNotas").length,
    faltas: materias.reduce((a, m) => a + m.disciplina.faltas, 0),
  };
}
