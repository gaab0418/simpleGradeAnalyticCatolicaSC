import { describe, expect, it } from "vitest";
import { historicoDemo } from "@/lib/demo";
import { calcularDesempenho } from "@/lib/dominio/desempenho";
import { dias, fmt, nomeMateria, rotuloPeriodo, titulo } from "@/lib/dominio/formato";
import { notasNovas } from "@/lib/dominio/novidades";
import {
  analisar,
  analisarSemestre,
  periodoPadrao,
  semestreEncerrado,
  simular,
} from "@/lib/dominio/regras";
import { resumir } from "@/lib/dominio/resumo";
import type { Disciplina } from "@/lib/dominio/tipos";

const disc = (
  notas: Disciplina["notas"],
  extra: Partial<Disciplina> = {},
): Disciplina => ({
  chave: "x",
  codTurma: "T",
  codDisc: "D",
  nome: "CÁLCULO II - CAL2",
  situacao: "Matriculado",
  notas,
  mediaFinal: null,
  faltas: 0,
  ...extra,
});

describe("situação da matéria", () => {
  it("9,8 na N1 precisa de 4,1 nas outras duas: tranquila", () => {
    const a = analisar(disc([9.8, null, null]));
    expect(a.precisa).toBe(4.1);
    expect(a.situacao.id).toBe("tranquila");
  });

  it("faixas pela média que falta", () => {
    expect(analisar(disc([6, 6, null])).situacao.id).toBe("atencao");
    expect(analisar(disc([5, 5, null])).situacao.id).toBe("apertada");
    expect(analisar(disc([4.5, 4.5, null])).situacao.id).toBe("critica");
    expect(analisar(disc([2, 4.5, null])).situacao.id).toBe("foraDeAlcance");
    expect(analisar(disc([null, null, null])).situacao.id).toBe("semNotas");
    expect(analisar(disc([9, 9, null])).situacao.id).toBe("garantida");
    expect(analisar(disc([5, 5, 5])).situacao.id).toBe("reprovada");
  });

  it("situação oficial do portal prevalece", () => {
    const a = analisar(disc([5, 5, 5], { situacao: "Aprovado", mediaFinal: 6 }));
    expect(a.situacao.id).toBe("aprovada");
    expect(a.media).toBe(6);
  });

  it("faltas: alerta a partir de 16, reprova acima de 20", () => {
    expect(analisar(disc([9.8, null, null], { faltas: 16 })).situacao.id).toBe("limiteDeFaltas");
    expect(analisar(disc([10, 10, 10], { faltas: 21 })).situacao.id).toBe("reprovadaPorFalta");
    expect(analisar(disc([4.5, 4.5, null], { faltas: 16 })).situacao.id).toBe("critica");
  });

  it("simulador", () => {
    const a = analisar(disc([6, null, null]));
    expect(simular(a, [6, 6]).passa).toBe(true);
    expect(simular(a, [5, 6]).faltariam).toBe(1);
  });
});

it("período padrão vira em 2 de agosto", () => {
  expect(periodoPadrao(new Date(2026, 7, 1))).toBe("202611");
  expect(periodoPadrao(new Date(2026, 7, 2))).toBe("202623");
});

it("formatação", () => {
  expect(fmt(7.25)).toBe("7,3");
  expect(titulo("CÁLCULO DIFERENCIAL E INTEGRAL II")).toBe("Cálculo Diferencial e Integral II");
  expect(nomeMateria("BANCO DE DADOS - BD1")).toEqual({ nome: "Banco de Dados", sigla: "BD1" });
  expect(rotuloPeriodo("202623")).toBe("2026/2");
  expect(dias(4)).toBe("1 dia");
  expect(dias(6)).toBe("1,5 dias");
});

describe("com o histórico de demonstração", () => {
  const h = historicoDemo(new Date(2026, 10, 12));
  const sem = (cod: string) => h.semestres.find((s) => s.codigo === cod)!;

  it("resumo do semestre em andamento aponta a prioridade", () => {
    const r = resumir(analisarSemestre(sem("202623")));
    expect(r.titulo).toBe("1 de 6 matérias garantidas");
    expect(r.foco).toContain("Empreendedorismo");
    expect(r.semNota).toBe(1);
    expect(semestreEncerrado(sem("202623"))).toBe(false);
  });

  it("resumo de semestre encerrado", () => {
    const r = resumir(analisarSemestre(sem("202411")));
    expect(r.titulo).toBe("Semestre encerrado: 4 de 5 aprovadas");
    expect(semestreEncerrado(sem("202411"))).toBe(true);
  });

  it("desempenho no curso", () => {
    const d = calcularDesempenho(h);
    expect(d.concluidas).toBe(25);
    expect(d.aprovadas).toBe(24);
    expect(d.mediaGeral).toBeCloseTo(7.8, 0);
    expect(d.evolucao).toHaveLength(6);
    expect(d.evolucao.at(-1)!.encerrado).toBe(false);
    expect(d.tendencia).toBeGreaterThan(0);
    expect(d.melhorSemestre!.codigo).toBe("202611");
    expect(d.distribuicao.reduce((a, f) => a + f.quantidade, 0)).toBe(25);
    expect(d.melhores[0].nome).toBe("Desenvolvimento Mobile");
    expect(d.piores[0].nome).toBe("Cálculo I");
  });

  it("detecta nota nova", () => {
    const depois = structuredClone(h);
    depois.semestres[0].disciplinas[0].notas[1] = 9.5;
    expect(notasNovas(h, depois)).toEqual(["N2 de Inteligência Artificial: 9,5"]);
    expect(notasNovas(h, h)).toEqual([]);
  });
});
