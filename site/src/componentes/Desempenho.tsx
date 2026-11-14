"use client";

import { useMemo } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/componentes/ui/card";
import { Progress } from "@/componentes/ui/progress";
import { Table, TableBody, TableCell, TableRow } from "@/componentes/ui/table";
import { useLoja } from "@/lib/cliente/loja";
import { regras } from "@/lib/config";
import { calcularDesempenho, type MateriaRanqueada } from "@/lib/dominio/desempenho";
import { dias, fmt } from "@/lib/dominio/formato";
import { cn } from "@/lib/utils";
import { GraficoColunas, GraficoEvolucao } from "./graficos";
import { IconeTendenciaCai, IconeTendenciaSobe } from "./icones";

const CONTEUDO = "mx-auto w-full max-w-[1060px] px-4 md:px-5";
const HERO_METRICA = "flex flex-col justify-center px-4 py-3 md:px-5 md:py-3.5";
const HERO_METRICA_SEPARADOR =
  "border-t border-border min-[521px]:border-t-0 min-[521px]:border-l";

export function Desempenho() {
  const { historico } = useLoja();
  const d = useMemo(() => (historico ? calcularDesempenho(historico) : null), [historico]);

  if (!d || d.mediaGeral === null) {
    return (
      <div className={CONTEUDO}>
        <p className="px-5 py-10 text-center text-muted-foreground">
          A análise aparece quando houver pelo menos uma matéria com as três notas lançadas.
        </p>
      </div>
    );
  }
  const maiorFaixa = Math.max(1, ...d.distribuicao.map((f) => f.quantidade));
  const emAndamento = d.evolucao.some((s) => !s.encerrado);

  return (
    <div className={CONTEUDO}>
      <div className="mb-5">
        <h1 className="text-[26px] font-bold leading-tight tracking-[-0.025em]">
          Desempenho no curso
        </h1>
        <p className="mt-0.5 text-muted-foreground">
          Calculado com as {d.concluidas} matérias que já têm resultado definitivo.
        </p>
      </div>

      <Card
        role="region"
        aria-label="Resumo geral do curso"
        className="mb-4 grid grid-cols-1 overflow-hidden md:grid-cols-[minmax(0,1.15fr)_minmax(0,1.85fr)]"
      >
        <div className="flex flex-col justify-center px-[22px] py-[18px]">
          <span className="text-xs font-medium text-muted-foreground">Média geral</span>
          <div className="mt-1 flex flex-wrap items-baseline gap-x-3.5 gap-y-2">
            <strong className="text-[42px] font-bold leading-none tracking-[-0.03em] tabular-nums">
              {fmt(d.mediaGeral)}
            </strong>
            {d.tendencia !== null && (
              <span
                className={cn(
                  "inline-flex items-center gap-1 rounded-md px-2 py-0.5 text-[13px] font-semibold tabular-nums [&_svg]:size-3.5",
                  d.tendencia >= 0
                    ? "bg-ok-fundo text-ok"
                    : "bg-critico-fundo text-critico",
                )}
              >
                {d.tendencia >= 0 ? <IconeTendenciaSobe /> : <IconeTendenciaCai />}
                {d.tendencia >= 0 ? "+" : "−"}
                {fmt(Math.abs(d.tendencia))} no último semestre
              </span>
            )}
          </div>
        </div>
        <dl className="grid grid-cols-1 border-t border-border min-[521px]:grid-cols-3 md:border-t-0 md:border-l">
          <div className={HERO_METRICA}>
            <dt className="text-xs font-medium text-muted-foreground">Aprovação</dt>
            <dd className="mt-[3px] text-2xl font-bold tracking-[-0.02em] tabular-nums">
              {Math.round((d.taxaAprovacao ?? 0) * 100)}%
            </dd>
          </div>
          <div className={cn(HERO_METRICA, HERO_METRICA_SEPARADOR)}>
            <dt className="text-xs font-medium text-muted-foreground">Matérias concluídas</dt>
            <dd className="mt-[3px] text-2xl font-bold tracking-[-0.02em] tabular-nums">
              {d.concluidas}{" "}
              <small className="text-[13px] font-normal tracking-normal text-texto-3">
                {d.aprovadas} aprovadas
              </small>
            </dd>
          </div>
          <div className={cn(HERO_METRICA, HERO_METRICA_SEPARADOR)}>
            <dt className="text-xs font-medium text-muted-foreground">Faltas no curso</dt>
            <dd className="mt-[3px] text-2xl font-bold tracking-[-0.02em] tabular-nums">
              {d.faltasTotais}{" "}
              <small className="text-[13px] font-normal tracking-normal text-texto-3">
                aulas · {dias(d.faltasTotais)}
              </small>
            </dd>
          </div>
        </dl>
      </Card>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        {d.observacoes.length > 0 && (
          <Card className="md:col-span-2">
            <CardHeader>
              <CardTitle>O que os números mostram</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="m-0 list-none space-y-2 p-0">
                {d.observacoes.map((o) => (
                  <li key={o} className="relative pl-3.5">
                    <span
                      aria-hidden="true"
                      className="absolute left-0 top-[0.62em] size-[5px] rounded-full bg-primary"
                    />
                    {o}
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        )}

        {d.evolucao.length >= 2 && (
          <Card className="md:col-span-2">
            <CardHeader>
              <CardTitle>Média por semestre</CardTitle>
              <CardDescription>
                Média das matérias em cada semestre. Tracejado: mínimo para aprovar (
                {regras.notaMinima}).
              </CardDescription>
            </CardHeader>
            <CardContent>
              <GraficoEvolucao
                pontos={d.evolucao.map((s) => ({
                  rotulo: s.rotulo,
                  valor: s.media,
                  parcial: !s.encerrado,
                }))}
              />
              {emAndamento && (
                <p className="mt-2 text-xs text-texto-3">
                  Ponto vazado e trecho tracejado: semestre em andamento (média parcial das notas já
                  lançadas).
                </p>
              )}
            </CardContent>
          </Card>
        )}

        {d.mediaPorEtapa.every((v) => v !== null) && (
          <Card>
            <CardHeader>
              <CardTitle>Nota média em cada prova</CardTitle>
              <CardDescription>
                Ritmo dentro do semestre: sua média em N1, N2 e N3 ao longo do curso.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <GraficoColunas
                descricao="Nota média em cada prova"
                maximo={regras.notaMaxima}
                referencia={regras.notaMinima}
                itens={d.mediaPorEtapa.map((v, i) => ({ rotulo: `N${i + 1}`, valor: v! }))}
              />
            </CardContent>
          </Card>
        )}

        <Card>
          <CardHeader>
            <CardTitle>Matérias por faixa de média</CardTitle>
            <CardDescription>
              Quantidade de matérias concluídas em cada faixa de nota.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-2">
            {[...d.distribuicao].reverse().map((f) => (
              <div
                key={f.rotulo}
                className="grid grid-cols-[96px_minmax(0,1fr)_24px] items-center gap-3 text-[13px]"
              >
                <span className="text-muted-foreground">{f.rotulo}</span>
                <span className="h-3.5">
                  {f.quantidade > 0 && (
                    <span
                      className={cn(
                        "block h-full min-w-[2px] rounded-r-sm",
                        f.abaixoDaMedia ? "bg-critico" : "bg-primary",
                      )}
                      style={{ width: `${(f.quantidade / maiorFaixa) * 100}%` }}
                    />
                  )}
                </span>
                <b className="text-right tabular-nums">{f.quantidade}</b>
              </div>
            ))}
          </CardContent>
        </Card>

        {d.semestres.length >= 2 && d.faltasTotais > 0 && (
          <Card className="md:col-span-2">
            <CardHeader>
              <CardTitle>Faltas por semestre (aulas)</CardTitle>
              <CardDescription>
                Total de aulas perdidas, somando todas as matérias do período.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <GraficoColunas
                descricao="Faltas por semestre, em aulas"
                inteiro
                itens={d.semestres.map((s) => ({ rotulo: s.rotulo, valor: s.faltas }))}
              />
            </CardContent>
          </Card>
        )}

        <Ranking titulo="Maiores médias" materias={d.melhores} />
        {d.piores.length > 0 && <Ranking titulo="Menores médias" materias={d.piores} />}
      </div>
    </div>
  );
}

function Ranking({ titulo, materias }: { titulo: string; materias: MateriaRanqueada[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{titulo}</CardTitle>
      </CardHeader>
      <CardContent>
        <Table>
          <TableBody className="[&_tr:first-child_td]:border-t-0 [&_tr:first-child_td]:pt-0 [&_tr:last-child_td]:pb-0">
            {materias.map((m) => (
              <TableRow key={`${m.periodo}-${m.nome}`}>
                <TableCell className="px-0 py-[9px] text-left text-[15px]">
                  {m.nome}
                  <small className="block text-xs text-texto-3">{m.periodo}</small>
                  <Progress
                    value={Math.min(100, (m.media / regras.notaMaxima) * 100)}
                    className="mt-[5px] h-1 border-0"
                    indicatorClassName={m.media < regras.notaMinima ? "bg-critico" : "bg-primary"}
                    aria-hidden="true"
                  />
                </TableCell>
                <TableCell
                  className={cn(
                    "px-0 py-[9px] pl-4 text-right align-top text-[15px] font-bold tabular-nums",
                    m.media < regras.notaMinima && "text-critico",
                  )}
                >
                  {fmt(m.media)}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}
