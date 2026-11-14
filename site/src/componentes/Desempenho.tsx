"use client";

import { useMemo } from "react";
import { useLoja } from "@/lib/cliente/loja";
import { regras } from "@/lib/config";
import { calcularDesempenho, type MateriaRanqueada } from "@/lib/dominio/desempenho";
import { dias, fmt } from "@/lib/dominio/formato";
import { GraficoColunas, GraficoEvolucao } from "./graficos";
import { IconeTendenciaCai, IconeTendenciaSobe } from "./icones";

export function Desempenho() {
  const { historico } = useLoja();
  const d = useMemo(() => (historico ? calcularDesempenho(historico) : null), [historico]);

  if (!d || d.mediaGeral === null) {
    return (
      <div className="conteudo">
        <p className="vazio">
          A análise aparece quando houver pelo menos uma matéria com as três notas lançadas.
        </p>
      </div>
    );
  }
  const maiorFaixa = Math.max(1, ...d.distribuicao.map((f) => f.quantidade));
  const emAndamento = d.evolucao.some((s) => !s.encerrado);

  return (
    <div className="conteudo">
      <div className="cabecalho-pagina">
        <div>
          <h1>Desempenho no curso</h1>
          <p className="sub">
            Calculado com as {d.concluidas} matérias que já têm resultado definitivo.
          </p>
        </div>
      </div>

      <section className="painel hero-desempenho" aria-label="Resumo geral do curso">
        <div className="hero-media-bloco">
          <span className="hero-rotulo">Média geral</span>
          <div className="hero-linha">
            <strong className="hero-media">{fmt(d.mediaGeral)}</strong>
            {d.tendencia !== null && (
              <span
                className={`hero-tendencia${d.tendencia >= 0 ? " positiva" : " negativa"}`}
              >
                {d.tendencia >= 0 ? <IconeTendenciaSobe /> : <IconeTendenciaCai />}
                {d.tendencia >= 0 ? "+" : "−"}
                {fmt(Math.abs(d.tendencia))} no último semestre
              </span>
            )}
          </div>
        </div>
        <dl className="hero-metricas">
          <div className="indicador">
            <dt>Aprovação</dt>
            <dd>{Math.round((d.taxaAprovacao ?? 0) * 100)}%</dd>
          </div>
          <div className="indicador">
            <dt>Matérias concluídas</dt>
            <dd>
              {d.concluidas} <small>{d.aprovadas} aprovadas</small>
            </dd>
          </div>
          <div className="indicador">
            <dt>Faltas no curso</dt>
            <dd>
              {d.faltasTotais} <small>aulas · {dias(d.faltasTotais)}</small>
            </dd>
          </div>
        </dl>
      </section>

      <div className="duas-colunas">
        {d.observacoes.length > 0 && (
          <section className="painel larga">
            <header>
              <h2>O que os números mostram</h2>
            </header>
            <div className="corpo">
              <ul className="observacoes">
                {d.observacoes.map((o) => (
                  <li key={o}>{o}</li>
                ))}
              </ul>
            </div>
          </section>
        )}

        {d.evolucao.length >= 2 && (
          <section className="painel larga">
            <header>
              <h2>Média por semestre</h2>
              <p className="painel-sub">
                Média das matérias em cada semestre. Tracejado: mínimo para aprovar (
                {regras.notaMinima}).
              </p>
            </header>
            <div className="corpo">
              <GraficoEvolucao
                pontos={d.evolucao.map((s) => ({
                  rotulo: s.rotulo,
                  valor: s.media,
                  parcial: !s.encerrado,
                }))}
              />
              {emAndamento && (
                <p className="legenda">
                  Ponto vazado e trecho tracejado: semestre em andamento (média parcial das notas já
                  lançadas).
                </p>
              )}
            </div>
          </section>
        )}

        {d.mediaPorEtapa.every((v) => v !== null) && (
          <section className="painel">
            <header>
              <h2>Nota média em cada prova</h2>
              <p className="painel-sub">
                Ritmo dentro do semestre: sua média em N1, N2 e N3 ao longo do curso.
              </p>
            </header>
            <div className="corpo">
              <GraficoColunas
                descricao="Nota média em cada prova"
                maximo={regras.notaMaxima}
                referencia={regras.notaMinima}
                itens={d.mediaPorEtapa.map((v, i) => ({ rotulo: `N${i + 1}`, valor: v! }))}
              />
            </div>
          </section>
        )}

        <section className="painel">
          <header>
            <h2>Matérias por faixa de média</h2>
            <p className="painel-sub">
              Quantidade de matérias concluídas em cada faixa de nota.
            </p>
          </header>
          <div className="corpo faixas">
            {[...d.distribuicao].reverse().map((f) => (
              <div className={`faixa${f.abaixoDaMedia ? " abaixo" : ""}`} key={f.rotulo}>
                <span>{f.rotulo}</span>
                <span className="trilho">
                  {f.quantidade > 0 && (
                    <i style={{ width: `${(f.quantidade / maiorFaixa) * 100}%` }} />
                  )}
                </span>
                <b>{f.quantidade}</b>
              </div>
            ))}
          </div>
        </section>

        {d.semestres.length >= 2 && d.faltasTotais > 0 && (
          <section className="painel larga">
            <header>
              <h2>Faltas por semestre (aulas)</h2>
              <p className="painel-sub">
                Total de aulas perdidas, somando todas as matérias do período.
              </p>
            </header>
            <div className="corpo">
              <GraficoColunas
                descricao="Faltas por semestre, em aulas"
                inteiro
                itens={d.semestres.map((s) => ({ rotulo: s.rotulo, valor: s.faltas }))}
              />
            </div>
          </section>
        )}

        <Ranking titulo="Maiores médias" materias={d.melhores} />
        {d.piores.length > 0 && <Ranking titulo="Menores médias" materias={d.piores} />}
      </div>
    </div>
  );
}

function Ranking({ titulo, materias }: { titulo: string; materias: MateriaRanqueada[] }) {
  return (
    <section className="painel">
      <header>
        <h2>{titulo}</h2>
      </header>
      <div className="corpo">
        <table className="ranking">
          <tbody>
            {materias.map((m) => (
              <tr key={`${m.periodo}-${m.nome}`}>
                <td>
                  {m.nome}
                  <small>{m.periodo}</small>
                  <span className="ranking-trilho" aria-hidden="true">
                    <i
                      className={m.media < regras.notaMinima ? "critica" : undefined}
                      style={{ width: `${Math.min(100, (m.media / regras.notaMaxima) * 100)}%` }}
                    />
                  </span>
                </td>
                <td className={m.media < regras.notaMinima ? "critica" : undefined}>
                  {fmt(m.media)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
