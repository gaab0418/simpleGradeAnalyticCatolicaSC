"use client";

import { Fragment, useRef, useState } from "react";
import { Alert, AlertDescription } from "@/componentes/ui/alert";
import { Badge } from "@/componentes/ui/badge";
import { Button } from "@/componentes/ui/button";
import { Card } from "@/componentes/ui/card";
import { Progress } from "@/componentes/ui/progress";
import { Slider } from "@/componentes/ui/slider";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/componentes/ui/table";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/componentes/ui/tooltip";
import { acoes, CHAVE_LAYOUT, useLoja } from "@/lib/cliente/loja";
import { regras } from "@/lib/config";
import { agruparSemestresPorAno, dias, fmt, nomeMateria, partesPeriodo, quando, titulo } from "@/lib/dominio/formato";
import {
  analisar,
  encerrada,
  moverChave,
  ordenarAnalises,
  passou,
  simular,
  type Analise,
  type ModoOrdem,
  type Simulacao,
} from "@/lib/dominio/regras";
import { resumir } from "@/lib/dominio/resumo";
import { cn } from "@/lib/utils";
import {
  IconeDescer,
  IconeN4,
  IconeOlho,
  IconeOlhoFechado,
  IconeSeta,
  IconeSubir,
} from "./icones";
import { Selo } from "./Situacao";

interface EstadoSim {
  palpites: Record<number, number>;
  nota4Ativa: boolean;
  nota4: number;
}

interface LayoutSemestre {
  modo: ModoOrdem;
  ordem: string[];
  ocultas: string[];
}

const LAYOUT_PADRAO: LayoutSemestre = {
  modo: "urgencia",
  ordem: [],
  ocultas: [],
};

const MODOS_ORDEM: { id: ModoOrdem; rotulo: string }[] = [
  { id: "urgencia", rotulo: "Urgência" },
  { id: "nome", rotulo: "A–Z" },
  { id: "faltas", rotulo: "Mais faltas" },
  { id: "soma", rotulo: "Maior soma" },
];

function lerLayouts(): Record<string, LayoutSemestre> {
  if (typeof window === "undefined") return {};
  try {
    const bruto = localStorage.getItem(CHAVE_LAYOUT);
    if (!bruto) return {};
    const json: unknown = JSON.parse(bruto);
    if (typeof json !== "object" || json === null || Array.isArray(json)) return {};
    const out: Record<string, LayoutSemestre> = {};
    for (const [k, v] of Object.entries(json)) {
      if (typeof v !== "object" || v === null || Array.isArray(v)) continue;
      const item = v as Partial<LayoutSemestre>;
      const modo =
        item.modo === "urgencia" ||
        item.modo === "nome" ||
        item.modo === "faltas" ||
        item.modo === "soma" ||
        item.modo === "personalizada"
          ? item.modo
          : "urgencia";
      out[k] = {
        modo,
        ordem: Array.isArray(item.ordem) ? item.ordem.filter((x): x is string => typeof x === "string") : [],
        ocultas: Array.isArray(item.ocultas)
          ? item.ocultas.filter((x): x is string => typeof x === "string")
          : [],
      };
    }
    return out;
  } catch {
    return {};
  }
}

function salvarLayouts(layouts: Record<string, LayoutSemestre>) {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(CHAVE_LAYOUT, JSON.stringify(layouts));
  } catch {
    // armazenamento indisponível: segue apenas em memória
  }
}

const CONTEUDO = "mx-auto w-full max-w-[1060px] px-4 md:px-5";
const CELULA_TABELA = "md:py-[13px] max-md:block max-md:border-0 max-md:p-0 max-md:text-left";
const CELULA_ROTULO =
  "max-md:before:mb-0.5 max-md:before:block max-md:before:text-[11px] max-md:before:text-texto-3 max-md:before:content-[attr(data-rotulo)]";

const passoMeio = (v: number) => Math.min(regras.notaMaxima, Math.max(0, Math.ceil(v * 2) / 2));

function resolverSim(m: Analise, salvo?: EstadoSim): EstadoSim {
  const pendentes = m.disciplina.notas.flatMap((n, i) => (n === null ? [i] : []));
  const inicial = passoMeio(m.precisa ?? regras.notaMinima);
  const palpites: Record<number, number> = {};
  for (const i of pendentes) {
    palpites[i] = salvo?.palpites[i] ?? inicial;
  }
  const inicialN4 = passoMeio(m.precisaN4 ?? regras.notaMinima);
  return {
    palpites,
    nota4Ativa: salvo?.nota4Ativa ?? false,
    nota4: salvo?.nota4 ?? inicialN4,
  };
}

function materiaEncerradaOficial(m: Analise): boolean {
  const oficial = m.disciplina.situacao.toLowerCase();
  return (
    m.disciplina.faltas > m.limiteFaltas ||
    oficial.startsWith("aprov") ||
    oficial.startsWith("reprov")
  );
}

export function Boletim() {
  const { historico, periodo, erro, novidades, demo, lembrado } = useLoja();
  const [abertas, setAbertas] = useState<ReadonlySet<string>>(new Set());
  const [sims, setSims] = useState<Record<string, EstadoSim>>({});
  const [layouts, setLayouts] = useState<Record<string, LayoutSemestre>>(() => lerLayouts());
  const [mostrarOcultas, setMostrarOcultas] = useState(false);
  const [arrastando, setArrastando] = useState<string | null>(null);
  const [alvoArraste, setAlvoArraste] = useState<string | null>(null);
  if (!historico) return null;

  const semestre = historico.semestres.find((s) => s.codigo === periodo);
  const materiasBase = semestre ? semestre.disciplinas.map(analisar) : [];
  const layout = (periodo && layouts[periodo]) || LAYOUT_PADRAO;
  const materiasOrdenadas = ordenarAnalises(materiasBase, layout.modo, layout.ordem);
  const ocultasSet = new Set(layout.ocultas);
  const materias = materiasOrdenadas.filter((m) => !ocultasSet.has(m.disciplina.chave));
  const materiasOcultas = materiasOrdenadas.filter((m) => ocultasSet.has(m.disciplina.chave));
  const r = resumir(materiasOrdenadas);
  const foco = (materias.length > 0 ? resumir(materias) : r).foco;
  const { aluno } = historico;

  const pendentesNaMateria = (m: (typeof materias)[number]) =>
    encerrada(m.situacao) || passou(m.situacao) || m.precisa === null
      ? 0
      : m.disciplina.notas.filter((n) => n === null).length;
  const ordensVisiveis = materias.map((_, idx) =>
    materias.slice(0, idx).reduce((soma, ant) => soma + pendentesNaMateria(ant), 0),
  );
  const ordensOcultas = materiasOcultas.map((_, idx) =>
    materiasOcultas.slice(0, idx).reduce((soma, ant) => soma + pendentesNaMateria(ant), 0),
  );

  const atualizarLayout = (fn: (atual: LayoutSemestre) => LayoutSemestre) => {
    if (!periodo) return;
    setLayouts((prev) => {
      const atual = prev[periodo] ?? LAYOUT_PADRAO;
      const novo = { ...prev, [periodo]: fn(atual) };
      salvarLayouts(novo);
      return novo;
    });
  };

  const definirModo = (modo: ModoOrdem) =>
    atualizarLayout((atual) => ({
      ...atual,
      modo,
      ordem: modo === "urgencia" ? [] : atual.ordem,
    }));

  const mover = (chave: string, destino: "cima" | "baixo" | string) => {
    const base = materiasOrdenadas.map((m) => m.disciplina.chave);
    let chaveDestino = destino;
    if (destino === "cima" || destino === "baixo") {
      const visiveis = materias.map((m) => m.disciplina.chave);
      const idx = visiveis.indexOf(chave);
      const alvo = visiveis[destino === "cima" ? idx - 1 : idx + 1];
      if (!alvo) return;
      chaveDestino = alvo;
    }
    atualizarLayout((atual) => ({
      ...atual,
      modo: "personalizada",
      ordem: moverChave(base, chave, chaveDestino),
    }));
  };

  const alternarOculta = (chave: string) => {
    const estavaOculta = ocultasSet.has(chave);
    if (estavaOculta && materiasOcultas.length <= 1) {
      setMostrarOcultas(false);
    }
    atualizarLayout((atual) => {
      const ja = atual.ocultas.includes(chave);
      return {
        ...atual,
        ocultas: ja ? atual.ocultas.filter((c) => c !== chave) : [...atual.ocultas, chave],
      };
    });
  };

  const ocultarGarantidas = () => {
    const chaves = materias.filter((m) => passou(m.situacao)).map((m) => m.disciplina.chave);
    if (chaves.length === 0) return;
    atualizarLayout((atual) => ({
      ...atual,
      ocultas: Array.from(new Set([...atual.ocultas, ...chaves])),
    }));
  };

  const mostrarTodas = () => {
    setMostrarOcultas(false);
    atualizarLayout((atual) => ({ ...atual, ocultas: [] }));
  };

  const temGarantidasVisiveis = materias.some((m) => passou(m.situacao));

  const alternar = (chave: string) =>
    setAbertas((atual) => {
      const novo = new Set(atual);
      if (!novo.delete(chave)) novo.add(chave);
      return novo;
    });

  return (
    <TooltipProvider>
      <div className={CONTEUDO}>
        <div className="mb-5 flex flex-wrap items-end justify-between gap-x-6 gap-y-3.5">
          <div>
            <h1 className="text-[26px] font-bold leading-tight tracking-[-0.025em]">
              {r.titulo}
            </h1>
            <p className="mt-0.5 text-muted-foreground">
              {[titulo(aluno.nome), titulo(aluno.curso), aluno.ra && `RA ${aluno.ra}`]
                .filter(Boolean)
                .join(" · ")}
            </p>
          </div>
          <div
            className="flex flex-wrap items-center justify-end gap-2"
            role="group"
            aria-label="Semestres por ano"
          >
            {agruparSemestresPorAno(historico.semestres).map((grupo, idxAno) => {
              const anoAtivo = grupo.semestres.some((s) => s.codigo === periodo);
              return (
                <div
                  key={grupo.ano}
                  role="group"
                  aria-label={`Ano ${grupo.ano}`}
                  className={cn(
                    "inline-flex items-center gap-0.5 rounded-[10px] border p-[3px] transition-colors",
                    anoAtivo
                      ? "border-primary/45 bg-acento-suave shadow-2xs"
                      : idxAno % 2 === 0
                        ? "border-border bg-card"
                        : "border-borda-forte/75 bg-secondary/80",
                  )}
                >
                  {grupo.semestres.map((s) => {
                    const ativo = s.codigo === periodo;
                    const { ano, semestre } = partesPeriodo(s.codigo);
                    return (
                      <button
                        key={s.codigo}
                        type="button"
                        aria-pressed={ativo}
                        className={cn(
                          "cursor-pointer rounded-[7px] px-2.5 py-1.5 text-[13px] tabular-nums transition-colors",
                          ativo
                            ? "bg-foreground text-card shadow-xs"
                            : anoAtivo
                              ? "text-foreground/85 hover:bg-card/65 hover:text-foreground"
                              : "text-muted-foreground hover:text-foreground",
                        )}
                        onClick={() => {
                          if (ativo) return;
                          setAbertas(new Set());
                          setSims({});
                          setMostrarOcultas(false);
                          acoes.selecionarPeriodo(s.codigo);
                        }}
                      >
                        <span className="font-bold tracking-tight">{ano}</span>
                        {semestre && (
                          <span
                            className={cn(
                              "font-medium",
                              ativo ? "opacity-75" : "text-texto-3",
                            )}
                          >
                            /{semestre}
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>
              );
            })}
          </div>
        </div>

        {demo && (
          <Alert className="mb-4">
            <AlertDescription>Demonstração com dados fictícios. Nada é salvo.</AlertDescription>
          </Alert>
        )}
        {erro && (
          <Alert variant="destructive" role="alert" className="mb-4">
            <AlertDescription>
              {erro.mensagem}
              {semestre && ` Mostrando os dados salvos ${quando(semestre.atualizadoEm)}.`}
            </AlertDescription>
            {erro.tipo === "credenciais" ? (
              <Button type="button" variant="outline" size="sm" onClick={acoes.sair}>
                Entrar de novo
              </Button>
            ) : (
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => acoes.sincronizar()}
              >
                Tentar de novo
              </Button>
            )}
          </Alert>
        )}
        {!erro && !demo && !lembrado && (
          <Alert className="mb-4">
            <AlertDescription>
              Mostrando as notas salvas neste navegador. Para buscar atualizações no portal, entre
              de novo.
            </AlertDescription>
            <Button type="button" variant="outline" size="sm" onClick={acoes.sair}>
              Entrar de novo
            </Button>
          </Alert>
        )}
        {novidades.length > 0 && (
          <Alert variant="success" role="status" className="mb-4">
            <AlertDescription>{`Nota nova no portal:\n${novidades.join("\n")}`}</AlertDescription>
            <Button type="button" variant="outline" size="sm" onClick={acoes.dispensarNovidades}>
              Ok
            </Button>
          </Alert>
        )}
        {foco && (
          <Alert variant="info" className="mb-4">
            <Badge className="shrink-0 rounded-[5px] bg-acento-suave px-[7px] py-0.5 text-[11px] font-bold uppercase tracking-[0.05em] text-primary">
              Foco
            </Badge>
            <AlertDescription>{foco}</AlertDescription>
          </Alert>
        )}

        <Card className="mb-4 overflow-hidden">
          <dl className="grid grid-cols-2 md:grid-cols-4">
            <div className="px-4 py-3 md:px-5 md:py-3.5">
              <dt className="text-xs font-medium text-muted-foreground">Garantidas</dt>
              <dd className="mt-[3px] text-2xl font-bold tracking-[-0.02em] tabular-nums">
                {r.garantidas}{" "}
                <small className="text-[13px] font-normal tracking-normal text-texto-3">
                  de {r.materias}
                </small>
              </dd>
            </div>
            <div className="border-l border-border px-4 py-3 md:px-5 md:py-3.5">
              <dt className="text-xs font-medium text-muted-foreground">Em aberto</dt>
              <dd className="mt-[3px] text-2xl font-bold tracking-[-0.02em] tabular-nums">
                {materias.filter((m) => !passou(m.situacao) && !encerrada(m.situacao)).length}
              </dd>
            </div>
            <div className="border-t border-border px-4 py-3 md:border-t-0 md:border-l md:px-5 md:py-3.5">
              <dt className="text-xs font-medium text-muted-foreground">Sem nota ainda</dt>
              <dd className="mt-[3px] text-2xl font-bold tracking-[-0.02em] tabular-nums">
                {r.semNota}
              </dd>
            </div>
            <div className="border-t border-l border-border px-4 py-3 md:border-t-0 md:px-5 md:py-3.5">
              <dt className="text-xs font-medium text-muted-foreground">Faltas no semestre</dt>
              <dd className="mt-[3px] text-2xl font-bold tracking-[-0.02em] tabular-nums">
                {r.faltas}{" "}
                <small className="text-[13px] font-normal tracking-normal text-texto-3">
                  {r.faltas === 1 ? "aula" : "aulas"} · {dias(r.faltas)}
                </small>
              </dd>
            </div>
          </dl>
        </Card>

        <section aria-label="Boletim do semestre">
          {materiasOrdenadas.length > 0 && (
            <div className="mb-2.5 flex flex-wrap items-center justify-between gap-2">
              <div
                className="flex flex-wrap items-center gap-1.5"
                role="group"
                aria-label="Ordenar matérias"
              >
                <span className="mr-1 text-xs font-medium text-texto-3">Ordenar:</span>
                {MODOS_ORDEM.map((op) => {
                  const ativo = layout.modo === op.id;
                  return (
                    <Button
                      key={op.id}
                      type="button"
                      size="sm"
                      variant={ativo ? "default" : "outline"}
                      aria-pressed={ativo}
                      className="h-7 px-2.5 text-xs"
                      onClick={() => definirModo(op.id)}
                    >
                      {op.rotulo}
                    </Button>
                  );
                })}
                {layout.modo === "personalizada" && (
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    className="h-7 px-2 text-xs text-primary"
                    onClick={() => definirModo("urgencia")}
                  >
                    Restaurar ordem
                  </Button>
                )}
              </div>
              {temGarantidasVisiveis && (
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  className="h-7 gap-1.5 px-2.5 text-xs text-muted-foreground hover:text-foreground [&_svg]:size-3.5"
                  onClick={ocultarGarantidas}
                >
                  <IconeOlhoFechado />
                  Ocultar garantidas
                </Button>
              )}
            </div>
          )}
          <Card className="overflow-visible">
            {materiasOrdenadas.length === 0 ? (
              <p className="px-5 py-10 text-center text-muted-foreground">
                Nenhuma matéria neste semestre. Escolha outro lá em cima.
              </p>
            ) : materias.length === 0 ? (
              <div className="flex flex-col items-center gap-3 px-5 py-10 text-center">
                <p className="text-muted-foreground">
                  Todas as matérias deste semestre estão ocultas lá embaixo.
                </p>
                <Button type="button" variant="outline" size="sm" onClick={mostrarTodas}>
                  Mostrar todas ({materiasOcultas.length})
                </Button>
              </div>
            ) : (
              <TabelaMaterias
                materias={materias}
                periodo={periodo}
                abertas={abertas}
                sims={sims}
                ordens={ordensVisiveis}
                oculta={false}
                alternar={alternar}
                onChangeSim={(chave, novo) => setSims((prev) => ({ ...prev, [chave]: novo }))}
                onAlternarOculta={alternarOculta}
                onMover={mover}
                arrastando={arrastando}
                alvoArraste={alvoArraste}
                onArrastar={setArrastando}
                onAlvoArraste={setAlvoArraste}
              />
            )}
          </Card>
        </section>
        <p className="mt-3 text-[13px] text-texto-3">
          Notas precedidas por <strong>≥</strong> mostram o mínimo necessário em cada prova para
          fechar média {regras.notaMinima}. Clique em uma matéria para simular, arraste ou use as
          setas para reordenar.
          {semestre && ` Dados do portal consultados ${quando(semestre.atualizadoEm)}.`}
        </p>

        {materiasOcultas.length > 0 && (
          <section aria-label="Matérias ocultas" className="mt-6 border-t border-border pt-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <button
                type="button"
                className="inline-flex cursor-pointer items-center gap-2 rounded-md border-0 bg-transparent px-1 py-1 text-sm font-semibold text-muted-foreground transition-colors hover:text-foreground [&_svg]:size-3.5 [&_svg]:transition-transform [&_svg]:duration-[180ms]"
                aria-expanded={mostrarOcultas}
                onClick={() => setMostrarOcultas((atual) => !atual)}
              >
                <span
                  className={cn(
                    "inline-flex transition-transform duration-[180ms]",
                    mostrarOcultas ? "rotate-0" : "-rotate-90",
                  )}
                >
                  <IconeSeta />
                </span>
                <span>Matérias ocultas</span>
                <Badge variant="secondary" className="tabular-nums">
                  {materiasOcultas.length}
                </Badge>
              </button>
              <Button type="button" variant="ghost" size="sm" onClick={mostrarTodas}>
                Mostrar todas
              </Button>
            </div>
            {mostrarOcultas && (
              <Card className="mt-3 overflow-visible opacity-95">
                <TabelaMaterias
                  materias={materiasOcultas}
                  periodo={periodo}
                  abertas={abertas}
                  sims={sims}
                  ordens={ordensOcultas}
                  oculta={true}
                  alternar={alternar}
                  onChangeSim={(chave, novo) => setSims((prev) => ({ ...prev, [chave]: novo }))}
                  onAlternarOculta={alternarOculta}
                />
              </Card>
            )}
          </section>
        )}
      </div>
    </TooltipProvider>
  );
}

function TabelaMaterias({
  materias,
  periodo,
  abertas,
  sims,
  ordens,
  oculta,
  alternar,
  onChangeSim,
  onAlternarOculta,
  onMover,
  arrastando,
  alvoArraste,
  onArrastar,
  onAlvoArraste,
}: {
  materias: Analise[];
  periodo: string | null;
  abertas: ReadonlySet<string>;
  sims: Record<string, EstadoSim>;
  ordens: number[];
  oculta: boolean;
  alternar: (chave: string) => void;
  onChangeSim: (chave: string, novo: EstadoSim) => void;
  onAlternarOculta: (chave: string) => void;
  onMover?: (chave: string, destino: "cima" | "baixo" | string) => void;
  arrastando?: string | null;
  alvoArraste?: string | null;
  onArrastar?: (chave: string | null) => void;
  onAlvoArraste?: (chave: string | null) => void;
}) {
  return (
    <Table className="max-md:block md:table md:[&>thead>tr>th:first-child]:rounded-tl-xl md:[&>thead>tr>th:last-child]:rounded-tr-xl md:[&>tbody>tr:last-child>td:first-child]:rounded-bl-xl md:[&>tbody>tr:last-child>td:last-child]:rounded-br-xl max-md:[&>tbody>tr:first-child]:rounded-t-xl max-md:[&>tbody>tr:last-child]:rounded-b-xl">
      <TableHeader className="max-md:hidden">
        <TableRow>
          <TableHead scope="col" className="py-[11px] pl-5 text-left">
            Matéria
          </TableHead>
          <TableHead scope="col" className="py-[11px]">
            N1
          </TableHead>
          <TableHead scope="col" className="py-[11px]">
            N2
          </TableHead>
          <TableHead scope="col" className="py-[11px]">
            N3
          </TableHead>
          <TableHead scope="col" className="py-[11px]">
            Soma
          </TableHead>
          <TableHead
            scope="col"
            className="py-[11px]"
            title="Média mínima nas provas que faltam para fechar média 6"
          >
            Precisa de
          </TableHead>
          <TableHead scope="col" className="py-[11px] text-left">
            Faltas
          </TableHead>
          <TableHead scope="col" className="py-[11px] pr-5 text-left">
            Situação
          </TableHead>
        </TableRow>
      </TableHeader>
      <TableBody key={`${periodo ?? "sem"}-${oculta ? "ocultas" : "visiveis"}`} className="max-md:block">
        {materias.map((m, idx) => {
          const chave = m.disciplina.chave;
          const aberta = abertas.has(chave);
          const estadoSim = resolverSim(m, sims[chave]);
          const pendentes = m.disciplina.notas.flatMap((n, i) => (n === null ? [i] : []));
          const sim = simular(
            m,
            pendentes.map((i) => estadoSim.palpites[i]),
            estadoSim.nota4Ativa ? estadoSim.nota4 : undefined,
          );
          return (
            <Fragment key={chave}>
              <Linha
                m={m}
                aberta={aberta}
                ordemBase={ordens[idx]}
                simulacaoN4={aberta && estadoSim.nota4Ativa ? sim : null}
                alternar={() => alternar(chave)}
                oculta={oculta}
                onAlternarOculta={() => onAlternarOculta(chave)}
                podeSubir={!oculta && idx > 0}
                podeDescer={!oculta && idx < materias.length - 1}
                onSubir={onMover ? () => onMover(chave, "cima") : undefined}
                onDescer={onMover ? () => onMover(chave, "baixo") : undefined}
                arrastando={arrastando === chave}
                alvoArraste={alvoArraste === chave && arrastando !== chave}
                onDragStart={
                  !oculta && materias.length > 1
                    ? (e) => {
                        e.dataTransfer.effectAllowed = "move";
                        e.dataTransfer.setData("text/plain", chave);
                        onArrastar?.(chave);
                      }
                    : undefined
                }
                onDragOver={
                  !oculta && arrastando
                    ? (e) => {
                        e.preventDefault();
                        if (arrastando !== chave) onAlvoArraste?.(chave);
                      }
                    : undefined
                }
                onDragLeave={
                  !oculta
                    ? () => {
                        if (alvoArraste === chave) onAlvoArraste?.(null);
                      }
                    : undefined
                }
                onDrop={
                  !oculta
                    ? (e) => {
                        e.preventDefault();
                        const origem = arrastando || e.dataTransfer.getData("text/plain");
                        if (origem && origem !== chave) onMover?.(origem, chave);
                        onArrastar?.(null);
                        onAlvoArraste?.(null);
                      }
                    : undefined
                }
                onDragEnd={
                  !oculta
                    ? () => {
                        onArrastar?.(null);
                        onAlvoArraste?.(null);
                      }
                    : undefined
                }
              />
              {aberta && (
                <TableRow className="bg-secondary/60 max-md:block">
                  <TableCell
                    colSpan={8}
                    id={`detalhe-${chave}`}
                    className="border-t-0 bg-secondary/60 px-4 pt-0 pb-4 text-left md:px-5 md:pb-5 md:pl-[42px] max-md:block"
                  >
                    <Detalhe
                      m={m}
                      estadoSim={estadoSim}
                      sim={sim}
                      onChangeSim={(novo) => onChangeSim(chave, novo)}
                    />
                  </TableCell>
                </TableRow>
              )}
            </Fragment>
          );
        })}
      </TableBody>
    </Table>
  );
}

function NotaSubstituida({
  rotulo,
  original,
  nota4,
}: {
  rotulo: string;
  original: number | null;
  nota4: number;
}) {
  const [aberto, setAberto] = useState(false);
  const abertoAntesDoPointer = useRef<boolean | null>(null);
  const originalTxt = original !== null ? fmt(original) : "–";

  return (
    <Tooltip open={aberto} onOpenChange={setAberto}>
      <TooltipTrigger asChild>
        <button
          type="button"
          className="inline-flex cursor-help items-center rounded-md border-0 bg-transparent p-0 pt-2 pl-2 text-inherit focus-visible:outline-2 focus-visible:outline-ring"
          aria-label={`${rotulo}: ${fmt(nota4)} pela N4, substituindo ${original !== null ? fmt(original) : "nota não lançada"}`}
          onPointerDown={() => {
            abertoAntesDoPointer.current = aberto;
          }}
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            const antes = abertoAntesDoPointer.current;
            abertoAntesDoPointer.current = null;
            setAberto((atual) => (antes !== null ? !antes : !atual));
          }}
        >
          <span className="relative inline-flex min-w-[46px] items-center justify-center rounded-[7px] border border-primary/45 bg-card px-2.5 pt-1.5 pb-1 shadow-sm max-md:min-w-[36px] max-md:px-1.5 max-md:pt-1 max-md:pb-0.5">
            <span className="absolute -top-2 -left-2 inline-flex items-center gap-0.5 rounded-full bg-primary px-1.5 py-px text-[9px] font-bold leading-[1.2] tracking-[0.03em] text-primary-foreground shadow-xs [&_svg]:size-[9px]">
              <IconeN4 /> N4
            </span>
            <span
              className={cn(
                "text-[15px] font-medium",
                nota4 < regras.notaMinima && "font-semibold text-critico",
              )}
            >
              {fmt(nota4)}
            </span>
          </span>
        </button>
      </TooltipTrigger>
      <TooltipContent side="top">
        N4 substitutiva: {fmt(nota4)} no lugar da {rotulo} ({originalTxt})
      </TooltipContent>
    </Tooltip>
  );
}

function CelulaNota({
  indice,
  original,
  notaEfetiva,
  substituidaPorN4,
  nota4,
  precisa,
  definida,
  ordem,
}: {
  indice: number;
  original: number | null;
  notaEfetiva: number | null;
  substituidaPorN4: boolean;
  nota4: number | null;
  precisa: number | null;
  definida: boolean;
  ordem: number;
}) {
  const rotulo = `N${indice + 1}`;
  if (substituidaPorN4 && nota4 !== null) {
    return (
      <TableCell data-rotulo={rotulo} className={cn(CELULA_TABELA, CELULA_ROTULO)}>
        <NotaSubstituida rotulo={rotulo} original={original} nota4={nota4} />
      </TableCell>
    );
  }
  if (notaEfetiva !== null) {
    return (
      <TableCell data-rotulo={rotulo} className={cn(CELULA_TABELA, CELULA_ROTULO)}>
        <span
          className={cn(
            "text-[15px] font-medium",
            notaEfetiva < regras.notaMinima && "font-semibold text-critico",
          )}
        >
          {fmt(notaEfetiva)}
        </span>
      </TableCell>
    );
  }
  if (!definida && precisa !== null) {
    return (
      <TableCell data-rotulo={rotulo} className={cn(CELULA_TABELA, CELULA_ROTULO)}>
        <span
          className={cn(
            "inline-block animate-revelar-nota rounded-[5px] border border-dashed px-1.5 py-px text-[13px] font-semibold",
            precisa > regras.notaMaxima
              ? "border-critico/35 bg-critico-fundo text-critico"
              : "border-borda-forte bg-secondary text-muted-foreground",
          )}
          style={{ animationDelay: `${ordem * 45 + 80}ms` }}
          title={`Mínimo necessário nesta prova para fechar média ${regras.notaMinima}`}
          aria-label={`${rotulo} sem nota; precisa de pelo menos ${fmt(precisa)}`}
        >
          ≥{fmt(precisa)}
        </span>
      </TableCell>
    );
  }
  return (
    <TableCell data-rotulo={rotulo} className={cn(CELULA_TABELA, CELULA_ROTULO)}>
      <span className="text-[15px] font-medium text-texto-3" aria-label={`${rotulo} sem nota`}>
        –
      </span>
    </TableCell>
  );
}

function Linha({
  m,
  aberta,
  ordemBase,
  simulacaoN4,
  alternar,
  oculta,
  onAlternarOculta,
  podeSubir,
  podeDescer,
  onSubir,
  onDescer,
  arrastando,
  alvoArraste,
  onDragStart,
  onDragOver,
  onDragLeave,
  onDrop,
  onDragEnd,
}: {
  m: Analise;
  aberta: boolean;
  ordemBase: number;
  simulacaoN4: Simulacao | null;
  alternar: () => void;
  oculta: boolean;
  onAlternarOculta: () => void;
  podeSubir?: boolean;
  podeDescer?: boolean;
  onSubir?: () => void;
  onDescer?: () => void;
  arrastando?: boolean;
  alvoArraste?: boolean;
  onDragStart?: (e: React.DragEvent<HTMLTableRowElement>) => void;
  onDragOver?: (e: React.DragEvent<HTMLTableRowElement>) => void;
  onDragLeave?: () => void;
  onDrop?: (e: React.DragEvent<HTMLTableRowElement>) => void;
  onDragEnd?: () => void;
}) {
  const d = m.disciplina;
  const { nome, sigla } = nomeMateria(d.nome);
  const encerradaOficial = materiaEncerradaOficial(m);
  const podeN4 = !encerradaOficial && !passou(m.situacao) && d.nota4 == null;
  const definida =
    encerradaOficial ||
    passou(m.situacao) ||
    (m.precisa === null && !(podeN4 && m.precisaN4 !== null));

  const indiceN4 = simulacaoN4 ? simulacaoN4.indiceSubstituido : m.indiceSubstituido;
  const valorN4 = simulacaoN4 ? simulacaoN4.nota4 : m.nota4;

  return (
    <TableRow
      draggable={Boolean(onDragStart)}
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDragLeave={onDragLeave}
      onDrop={onDrop}
      onDragEnd={onDragEnd}
      className={cn(
        "hover:bg-secondary/60 max-md:grid max-md:grid-cols-4 max-md:gap-x-2 max-md:gap-y-2.5 max-md:border-t max-md:border-border max-md:p-4 max-md:first:border-t-0",
        aberta && "bg-secondary/60",
        onDragStart && "cursor-grab active:cursor-grabbing",
        arrastando && "opacity-45",
        alvoArraste && "bg-acento-suave/50 ring-1 ring-inset ring-primary/40",
      )}
    >
      <TableCell className={cn(CELULA_TABELA, "md:pl-4 md:text-left max-md:col-span-full")}>
        <div className="flex items-center gap-1.5">
          <button
            type="button"
            className="inline-flex size-7 shrink-0 cursor-pointer items-center justify-center rounded-md border-0 bg-transparent p-0 text-texto-3 transition-colors hover:bg-secondary hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring [&_svg]:size-3.5"
            aria-label={oculta ? `Mostrar ${nome}` : `Ocultar ${nome}`}
            title={oculta ? `Mostrar ${nome} no boletim` : `Ocultar ${nome}`}
            onClick={(e) => {
              e.stopPropagation();
              onAlternarOculta();
            }}
          >
            {oculta ? <IconeOlho /> : <IconeOlhoFechado />}
          </button>
          <button
            type="button"
            className={cn(
              "flex min-w-0 flex-1 cursor-pointer items-center gap-2 border-0 bg-transparent p-0 text-left [&_svg]:size-3.5 [&_svg]:shrink-0 [&_svg]:transition-transform [&_svg]:duration-[180ms] [&_svg]:ease-out",
              aberta
                ? "[&_svg]:rotate-0 [&_svg]:text-primary"
                : "[&_svg]:-rotate-90 [&_svg]:text-texto-3",
            )}
            aria-expanded={aberta}
            aria-controls={`detalhe-${d.chave}`}
            onClick={alternar}
          >
            <IconeSeta />
            <span className="min-w-0">
              <strong className="block text-[15px] font-semibold leading-[1.3]">{nome}</strong>
              <span className="text-xs text-texto-3">{sigla || d.codDisc}</span>
            </span>
          </button>
          {(podeSubir || podeDescer) && (
            <span className="ml-1 inline-flex shrink-0 items-center gap-0.5">
              <button
                type="button"
                disabled={!podeSubir}
                className="inline-flex size-6 cursor-pointer items-center justify-center rounded border-0 bg-transparent p-0 text-texto-3 transition-colors hover:bg-secondary hover:text-foreground disabled:cursor-default disabled:opacity-25 [&_svg]:size-3"
                aria-label={`Mover ${nome} para cima`}
                title="Mover para cima"
                onClick={(e) => {
                  e.stopPropagation();
                  onSubir?.();
                }}
              >
                <IconeSubir />
              </button>
              <button
                type="button"
                disabled={!podeDescer}
                className="inline-flex size-6 cursor-pointer items-center justify-center rounded border-0 bg-transparent p-0 text-texto-3 transition-colors hover:bg-secondary hover:text-foreground disabled:cursor-default disabled:opacity-25 [&_svg]:size-3"
                aria-label={`Mover ${nome} para baixo`}
                title="Mover para baixo"
                onClick={(e) => {
                  e.stopPropagation();
                  onDescer?.();
                }}
              >
                <IconeDescer />
              </button>
            </span>
          )}
        </div>
      </TableCell>
      {d.notas.map((n, i) => {
        const ordem = ordemBase + d.notas.slice(0, i).filter((x) => x === null).length;
        const substituida = indiceN4 === i && valorN4 !== null;
        return (
          <CelulaNota
            key={i}
            indice={i}
            original={n}
            notaEfetiva={substituida ? valorN4 : m.notasEfetivas[i]}
            substituidaPorN4={substituida}
            nota4={valorN4}
            precisa={m.precisa}
            definida={definida}
            ordem={ordem}
          />
        );
      })}
      <TableCell data-rotulo="Soma" className={cn(CELULA_TABELA, CELULA_ROTULO)}>
        {m.lancadas ? (
          <span className="text-[15px] font-bold">
            {fmt(m.soma)}
            <small className="ml-px text-[11px] font-normal text-texto-3">
              /{regras.somaAprovacao}
            </small>
          </span>
        ) : (
          <span className="text-[15px] font-medium text-texto-3">–</span>
        )}
      </TableCell>
      <TableCell
        data-rotulo="Precisa de"
        className={cn(CELULA_TABELA, CELULA_ROTULO, "max-md:col-span-2")}
      >
        {definida ? (
          <span className="text-[15px] font-medium text-texto-3">–</span>
        ) : m.precisa !== null && m.precisa > regras.notaMaxima && m.precisaN4 !== null ? (
          <span className="text-sm text-muted-foreground">≥{fmt(m.precisaN4)} na N4</span>
        ) : m.precisa === null && m.precisaN4 !== null ? (
          <span className="text-sm text-muted-foreground">≥{fmt(m.precisaN4)} na N4</span>
        ) : (
          <span
            className={cn(
              "text-sm",
              m.precisa! > regras.notaMaxima
                ? "font-semibold text-critico"
                : "text-muted-foreground",
            )}
          >
            {fmt(m.precisa!)}{" "}
            {m.restantes > 1 ? "de média" : `na N${m.notasEfetivas.indexOf(null) + 1}`}
          </span>
        )}
      </TableCell>
      <TableCell
        data-rotulo="Faltas"
        className={cn(CELULA_TABELA, CELULA_ROTULO, "md:text-left max-md:col-span-2")}
      >
        <Faltas faltas={d.faltas} limite={m.limiteFaltas} alerta={m.alertaFaltas} />
      </TableCell>
      <TableCell className={cn(CELULA_TABELA, "md:pr-5 md:text-left max-md:col-span-full")}>
        <div className="inline-flex flex-col items-start gap-0.5 max-md:flex-row max-md:items-center max-md:gap-2.5">
          <Selo tom={m.situacao.tom}>{m.situacao.rotulo}</Selo>
          {encerrada(m.situacao) && d.mediaFinal !== null && (
            <span className="pl-0.5 text-xs text-texto-3">média {fmt(d.mediaFinal)}</span>
          )}
        </div>
      </TableCell>
    </TableRow>
  );
}

/** Blocos de 4 tracinhos, um por dia de aula que pode ser perdido. */
export function Faltas({
  faltas,
  limite = regras.limiteFaltas,
  alerta: limiteAlerta = regras.alertaFaltas,
}: {
  faltas: number;
  limite?: number;
  alerta?: number;
}) {
  const diasTotais = limite / regras.aulasPorDia;
  const sobra = Math.max(0, limite - faltas);
  const alerta = faltas >= limiteAlerta;
  return (
    <span
      className={cn(
        "inline-flex items-center gap-2 text-[13px]",
        alerta ? "font-semibold text-critico" : "text-muted-foreground",
      )}
      title={`${faltas} de ${limite} faltas. Pode faltar mais ${dias(sobra)}.`}
    >
      <span className="inline-flex items-center gap-[5px]" aria-hidden="true">
        {Array.from({ length: diasTotais }, (_, d) => {
          const usadas = Math.min(
            regras.aulasPorDia,
            Math.max(0, faltas - d * regras.aulasPorDia),
          );
          const diaCheio = usadas === regras.aulasPorDia;
          return (
            <span
              key={d}
              className={cn(
                "relative inline-flex gap-0.5 px-px",
                diaCheio &&
                  'after:absolute after:-inset-x-0.5 after:top-[6px] after:h-[1.75px] after:-rotate-[28deg] after:rounded-xs after:bg-critico after:content-[""]',
              )}
            >
              {Array.from({ length: regras.aulasPorDia }, (_, t) => {
                const on = t < usadas;
                return (
                  <span
                    key={t}
                    className={cn(
                      "block h-3.5 w-[2.5px] rounded-[2px]",
                      on
                        ? alerta
                          ? "bg-critico opacity-100"
                          : "bg-foreground opacity-100"
                        : "bg-borda-forte opacity-45",
                    )}
                  />
                );
              })}
            </span>
          );
        })}
      </span>
      <span className="tabular-nums">
        {faltas}/{limite}
      </span>
    </span>
  );
}

function Detalhe({
  m,
  estadoSim,
  sim,
  onChangeSim,
}: {
  m: Analise;
  estadoSim: EstadoSim;
  sim: Simulacao;
  onChangeSim: (novo: EstadoSim) => void;
}) {
  const d = m.disciplina;
  const pendentes = d.notas.flatMap((n, i) => (n === null ? [i] : []));
  const inicial = passoMeio(m.precisa ?? regras.notaMinima);
  const sobra = Math.max(0, m.limiteFaltas - d.faltas);
  const encerradaOficial = materiaEncerradaOficial(m);
  const podeSimularN4 = !encerradaOficial && !passou(m.situacao) && d.nota4 == null;
  const fim = (m.restantes === 0 && !podeSimularN4) || encerradaOficial;

  const aplicarAlvo = (valor: number) =>
    onChangeSim({
      ...estadoSim,
      palpites: Object.fromEntries(pendentes.map((i) => [i, passoMeio(valor)])),
    });

  const somaMaxima = regras.notaMaxima * d.notas.length;
  const pctSoma = Math.min(100, Math.max(0, (sim.soma / somaMaxima) * 100));
  const pctMeta = (regras.somaAprovacao / somaMaxima) * 100;

  return (
    <div className="animate-abrir-detalhe">
      <div className="grid grid-cols-1 gap-x-10 gap-y-4.5 rounded-lg border border-border bg-card p-4.5 md:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
        <div>
          {fim ? (
            <>
              <h3 className="mb-2 text-[13px] font-semibold">Notas</h3>
              <p className="text-[15px] leading-relaxed">
                {d.mediaFinal !== null
                  ? `Média final ${fmt(d.mediaFinal)}. Situação no portal: ${d.situacao}.`
                  : `Todas as notas lançadas. Soma ${fmt(m.soma)} de ${regras.somaAprovacao}.`}
              </p>
              {m.indiceSubstituido !== null && m.nota4 !== null && (
                <p className="mt-1.5 text-[13px] text-texto-3">
                  N4 substitutiva: tirou {fmt(m.nota4)}, substituindo a N{m.indiceSubstituido + 1}{" "}
                  ({m.notaSubstituida !== null ? fmt(m.notaSubstituida) : "–"}).
                </p>
              )}
            </>
          ) : (
            <>
              <div className="mb-2.5 flex flex-wrap items-center justify-between gap-2">
                <h3 className="text-[13px] font-semibold">
                  {pendentes.length > 0 ? "E se eu tirar…" : "E se eu fizer a N4…"}
                </h3>
                {pendentes.length > 0 && (
                  <div className="flex flex-wrap gap-1.5">
                    <Button
                      type="button"
                      variant="secondary"
                      size="sm"
                      onClick={() => aplicarAlvo(m.precisa ?? regras.notaMinima)}
                    >
                      Mínimo ({fmt(inicial)})
                    </Button>
                    <Button
                      type="button"
                      variant="secondary"
                      size="sm"
                      onClick={() => aplicarAlvo((24 - m.soma) / Math.max(1, m.restantes))}
                    >
                      Média 8
                    </Button>
                    <Button
                      type="button"
                      variant="secondary"
                      size="sm"
                      onClick={() => aplicarAlvo(regras.notaMaxima)}
                    >
                      Tudo 10
                    </Button>
                  </div>
                )}
              </div>
              {pendentes.map((i) => (
                <div
                  className="mb-1 grid grid-cols-[28px_minmax(0,1fr)_42px] items-center gap-3"
                  key={i}
                >
                  <span className="text-[13px] text-muted-foreground">N{i + 1}</span>
                  <Slider
                    min={0}
                    max={regras.notaMaxima}
                    step={0.5}
                    value={[estadoSim.palpites[i]]}
                    onValueChange={([val]) =>
                      onChangeSim({
                        ...estadoSim,
                        palpites: { ...estadoSim.palpites, [i]: val },
                      })
                    }
                    aria-label={`Nota simulada N${i + 1}`}
                  />
                  <output className="text-right font-semibold tabular-nums">
                    {fmt(estadoSim.palpites[i])}
                  </output>
                </div>
              ))}
              {podeSimularN4 && (
                <div className="mt-2.5 grid gap-2 border-t border-dashed border-border pt-2.5">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="inline-flex items-center gap-1.5 text-[13px] font-medium text-muted-foreground [&_svg]:size-3.5 [&_svg]:shrink-0 [&_svg]:text-primary">
                      <IconeN4 />
                      N4 (Recuperação — substitui a menor nota)
                    </span>
                    <Button
                      type="button"
                      variant="secondary"
                      size="sm"
                      className={cn(
                        estadoSim.nota4Ativa &&
                          "border-primary bg-acento-suave text-primary hover:bg-acento-suave/80",
                      )}
                      aria-pressed={estadoSim.nota4Ativa}
                      onClick={() =>
                        onChangeSim({
                          ...estadoSim,
                          nota4Ativa: !estadoSim.nota4Ativa,
                        })
                      }
                    >
                      {estadoSim.nota4Ativa ? "Remover N4" : "Simular N4"}
                    </Button>
                  </div>
                  {estadoSim.nota4Ativa && (
                    <div className="mb-1 grid grid-cols-[28px_minmax(0,1fr)_42px] items-center gap-3">
                      <span className="text-[13px] text-muted-foreground">N4</span>
                      <Slider
                        min={0}
                        max={regras.notaMaxima}
                        step={0.5}
                        value={[estadoSim.nota4]}
                        onValueChange={([val]) =>
                          onChangeSim({
                            ...estadoSim,
                            nota4: val,
                          })
                        }
                        aria-label="Nota simulada N4"
                      />
                      <output className="text-right font-semibold tabular-nums">
                        {fmt(estadoSim.nota4)}
                      </output>
                    </div>
                  )}
                </div>
              )}
              <div className="relative mt-3" aria-hidden="true">
                <Progress
                  value={pctSoma}
                  className="h-[7px]"
                  indicatorClassName={sim.passa ? "bg-ok" : "bg-critico"}
                />
                <span
                  className="absolute -top-[3px] -bottom-[3px] w-0.5 rounded-[1px] bg-foreground"
                  style={{ left: `${pctMeta}%` }}
                  title={`Meta para aprovar: ${regras.somaAprovacao}`}
                />
              </div>
              <p className="mt-2.5 flex flex-wrap items-center gap-2 text-sm" aria-live="polite">
                Soma <strong>{fmt(sim.soma)}</strong> de {somaMaxima}:
                <Selo tom={sim.passa ? "ok" : "critico"}>
                  {sim.passa
                    ? `passa com média ${fmt(sim.media)}`
                    : `faltariam ${fmt(sim.faltariam)} pontos`}
                </Selo>
                {estadoSim.nota4Ativa && sim.indiceSubstituido !== null && (
                  <span className="text-[13px] text-texto-3">
                    (N4 substitui N{sim.indiceSubstituido + 1})
                  </span>
                )}
              </p>
            </>
          )}
        </div>
        <div>
          <h3 className="mb-2 text-[13px] font-semibold">Faltas</h3>
          <p className="text-[15px] leading-relaxed">
            {d.faltas > m.limiteFaltas
              ? `Você passou do limite: ${d.faltas} faltas de ${m.limiteFaltas} permitidas.`
              : d.faltas === 0
                ? `Nenhuma falta até agora. Dá para faltar até ${dias(sobra)} antes de reprovar.`
                : `Você faltou ${dias(d.faltas)} (${d.faltas} aulas). Ainda pode faltar ${dias(sobra)} antes de reprovar.`}
          </p>
          <div className="mt-2.5">
            <Faltas faltas={d.faltas} limite={m.limiteFaltas} alerta={m.alertaFaltas} />
          </div>
          <p className="mt-2.5 text-[13px] text-texto-3">
            Disciplina {d.codDisc}, turma {d.codTurma}
          </p>
        </div>
      </div>
    </div>
  );
}
