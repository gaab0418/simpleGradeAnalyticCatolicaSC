"use client";

import { useEffect, useSyncExternalStore } from "react";
import { Button } from "@/componentes/ui/button";
import { Card } from "@/componentes/ui/card";
import { Skeleton } from "@/componentes/ui/skeleton";
import { Tabs, TabsList, TabsTrigger } from "@/componentes/ui/tabs";
import { acoes, useLoja } from "@/lib/cliente/loja";
import { quando } from "@/lib/dominio/formato";
import { Boletim } from "./Boletim";
import { Desempenho } from "./Desempenho";
import { Entrada } from "./Entrada";
import {
  IconeAtualizar,
  IconeHistorico,
  IconeLua,
  IconeSair,
  IconeSistema,
  IconeSol,
  Logo,
} from "./icones";

type Tema = "sistema" | "claro" | "escuro";
const ouvintesTema = new Set<() => void>();

function lerTema(): Tema {
  try {
    const t = localStorage.getItem("boletim.tema");
    return t === "claro" || t === "escuro" ? t : "sistema";
  } catch {
    return "sistema";
  }
}

function definirTema(novo: Tema) {
  const raiz = document.documentElement;
  if (novo === "sistema") delete raiz.dataset.tema;
  else raiz.dataset.tema = novo;
  try {
    if (novo === "sistema") localStorage.removeItem("boletim.tema");
    else localStorage.setItem("boletim.tema", novo);
  } catch {
    // preferência só não persiste
  }
  ouvintesTema.forEach((f) => f());
}

function useTema(): Tema {
  return useSyncExternalStore(
    (f) => {
      ouvintesTema.add(f);
      return () => ouvintesTema.delete(f);
    },
    lerTema,
    () => "sistema",
  );
}

const OPCOES_TEMA: { id: Tema; rotulo: string; icone: React.ReactNode }[] = [
  { id: "sistema", rotulo: "Tema do sistema", icone: <IconeSistema /> },
  { id: "claro", rotulo: "Tema claro", icone: <IconeSol /> },
  { id: "escuro", rotulo: "Tema escuro", icone: <IconeLua /> },
];

export function Aplicativo() {
  const estado = useLoja();
  const tema = useTema();
  useEffect(() => acoes.iniciar(), []);

  const pronto = estado.fase === "pronto";
  const ultima = estado.historico?.semestres
    .map((s) => s.atualizadoEm)
    .sort()
    .at(-1);

  return (
    <>
      <header className="sticky top-0 z-20 border-b border-border bg-card/88 backdrop-blur-md">
        <div className="mx-auto flex min-h-[58px] w-full max-w-[1060px] flex-wrap items-center gap-x-4.5 gap-y-2 px-4 md:px-5">
          <span className="flex items-center gap-2.5 font-bold tracking-tight [&_svg]:size-[22px] [&_svg]:shrink-0 [&_svg]:text-primary">
            <Logo />
            <span>
              Grade Analytic{" "}
              <small className="hidden text-[13px] font-normal text-texto-3 sm:inline">
                Boletim
              </small>
            </span>
          </span>
          {pronto && (
            <Tabs
              value={estado.aba}
              onValueChange={(v) => acoes.abrirAba(v as "boletim" | "desempenho")}
              className="order-3 mb-2 w-full md:order-none md:mb-0 md:w-auto"
            >
              <TabsList className="w-full md:w-auto" aria-label="Seções">
                <TabsTrigger value="boletim" className="flex-1 md:flex-initial">
                  Boletim
                </TabsTrigger>
                <TabsTrigger value="desempenho" className="flex-1 md:flex-initial">
                  Desempenho
                </TabsTrigger>
              </TabsList>
            </Tabs>
          )}
          <div className="ml-auto flex items-center gap-1.5">
            {pronto && estado.lembrado && (
              <>
                {ultima && (
                  <span className="mr-1 hidden text-xs text-texto-3 md:inline">
                    Atualizado {quando(ultima)}
                  </span>
                )}
                <Button
                  type="button"
                  variant="outline"
                  className={
                    estado.ocupado
                      ? "max-[520px]:size-9 max-[520px]:p-0 [&_svg]:animate-spin"
                      : "max-[520px]:size-9 max-[520px]:p-0"
                  }
                  onClick={() => acoes.sincronizar()}
                  disabled={estado.ocupado}
                  title="Busca as notas do semestre atual no portal"
                  aria-label="Atualizar notas do semestre atual"
                >
                  <IconeAtualizar />
                  <span className="max-[520px]:hidden">
                    {estado.ocupado ? "Atualizando…" : "Atualizar"}
                  </span>
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  size="icon"
                  onClick={() => acoes.sincronizar(true)}
                  disabled={estado.ocupado}
                  title="Rebaixar histórico: atualiza também todos os semestres já encerrados"
                  aria-label="Rebaixar histórico completo de todos os semestres"
                >
                  <IconeHistorico />
                </Button>
              </>
            )}
            <div
              className="inline-flex h-9 items-center rounded-lg border border-borda-forte bg-card p-0.5"
              role="group"
              aria-label="Aparência"
            >
              {OPCOES_TEMA.map((op) => {
                const ativo = tema === op.id;
                return (
                  <Button
                    key={op.id}
                    type="button"
                    variant="ghost"
                    size="icon"
                    className={
                      ativo
                        ? "h-[30px] w-7 rounded-md bg-secondary text-foreground [&_svg]:size-[15px]"
                        : "h-[30px] w-7 rounded-md text-texto-3 [&_svg]:size-[15px]"
                    }
                    aria-pressed={ativo}
                    aria-label={op.rotulo}
                    title={op.rotulo}
                    onClick={() => definirTema(op.id)}
                  >
                    {op.icone}
                  </Button>
                );
              })}
            </div>
            {pronto && (
              <Button
                type="button"
                variant="outline"
                size="icon"
                onClick={() => {
                  if (
                    estado.demo ||
                    confirm("Sair e apagar a senha e as notas salvas neste navegador?")
                  ) {
                    void acoes.sair();
                  }
                }}
                aria-label={estado.demo ? "Sair da demonstração" : "Sair e apagar dados"}
                title={estado.demo ? "Sair da demonstração" : "Sair e apagar dados"}
              >
                <IconeSair />
              </Button>
            )}
          </div>
        </div>
      </header>

      <main className="flex-1 pt-5 pb-12 md:pt-7">
        {estado.fase === "carregando" && <Esqueleto />}
        {estado.fase === "deslogado" && <Entrada />}
        {pronto && (estado.aba === "boletim" ? <Boletim /> : <Desempenho />)}
      </main>
    </>
  );
}

function Esqueleto() {
  return (
    <div className="mx-auto w-full max-w-[1060px] px-4 md:px-5" aria-busy="true">
      <span className="sr-only">Carregando boletim…</span>
      <div className="mb-5 grid gap-2">
        <Skeleton className="h-7 w-[42%]" />
        <Skeleton className="h-4 w-[26%]" />
      </div>
      <Card className="mb-4 grid grid-cols-2 overflow-hidden md:grid-cols-4">
        {Array.from({ length: 4 }, (_, i) => (
          <div
            key={i}
            className={[
              "border-border px-4 py-3 md:px-5 md:py-3.5",
              i % 2 === 1 ? "border-l" : i > 0 ? "md:border-l" : "",
              i >= 2 ? "max-md:border-t" : "",
            ]
              .filter(Boolean)
              .join(" ")}
          >
            <Skeleton className="h-3 w-[55%]" />
            <Skeleton className="mt-2 h-6 w-[40%]" />
          </div>
        ))}
      </Card>
      <Card className="divide-y divide-border overflow-hidden">
        {["48%", "36%", "56%", "40%"].map((largura, i) => (
          <div key={i} className="flex items-center justify-between gap-4 px-5 py-4">
            <Skeleton className="h-[15px]" style={{ width: largura }} />
            <Skeleton className="h-[22px] w-[88px]" />
          </div>
        ))}
      </Card>
    </div>
  );
}
