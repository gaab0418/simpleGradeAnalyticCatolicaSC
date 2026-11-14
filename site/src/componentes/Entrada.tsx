"use client";

import Link from "next/link";
import { useState } from "react";
import { Button } from "@/componentes/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/componentes/ui/card";
import { Checkbox } from "@/componentes/ui/checkbox";
import { Input } from "@/componentes/ui/input";
import { Label } from "@/componentes/ui/label";
import { acoes, useLoja } from "@/lib/cliente/loja";
import { instituicao } from "@/lib/config";
import { Faltas } from "./Boletim";
import { IconeEscudo } from "./icones";
import { Selo } from "./Situacao";

export function Entrada() {
  const { ocupado } = useLoja();
  const [mostrar, setMostrar] = useState(false);
  const [lembrar, setLembrar] = useState(true);
  const [erro, setErro] = useState<string | null>(null);

  async function enviar(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const dados = new FormData(e.currentTarget);
    setErro(null);
    setErro(
      await acoes.entrar(String(dados.get("usuario") ?? ""), String(dados.get("senha") ?? ""), lembrar),
    );
  }

  return (
    <div className="mx-auto grid w-full max-w-[1060px] grid-cols-1 items-start gap-7 px-4 pt-1 md:grid-cols-[minmax(0,400px)_minmax(0,1fr)] md:gap-12 md:px-5 md:pt-5">
      <section>
        <h1 className="mb-2 text-[30px] font-bold leading-[1.15] tracking-tight">
          Suas notas e faltas, com o que falta para passar.
        </h1>
        <p className="text-muted-foreground">
          Entre com o mesmo usuário e senha do portal da {instituicao.nome}.
        </p>

        <form onSubmit={enviar} className="mt-6 grid gap-3.5">
          <div className="grid gap-1.5">
            <Label htmlFor="usuario">Usuário do portal</Label>
            <Input
              id="usuario"
              name="usuario"
              type="text"
              autoComplete="username"
              autoCapitalize="none"
              spellCheck={false}
              required
              disabled={ocupado}
            />
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor="senha">Senha</Label>
            <div className="relative">
              <Input
                id="senha"
                name="senha"
                type={mostrar ? "text" : "password"}
                autoComplete="current-password"
                className="pr-[76px]"
                required
                disabled={ocupado}
              />
              <Button
                type="button"
                variant="ghost"
                onClick={() => setMostrar(!mostrar)}
                aria-pressed={mostrar}
                className="absolute top-1.5 right-1.5 h-8 px-2 text-[13px] font-normal text-muted-foreground hover:bg-secondary/60 hover:text-foreground"
              >
                {mostrar ? "Esconder" : "Mostrar"}
              </Button>
            </div>
          </div>
          <div className="flex items-start gap-2.5 text-sm">
            <Checkbox
              id="lembrar"
              checked={lembrar}
              onCheckedChange={(v) => setLembrar(v === true)}
              disabled={ocupado}
              className="mt-0.5"
            />
            <Label
              htmlFor="lembrar"
              className="grid cursor-pointer gap-0.5 text-sm font-normal leading-snug text-foreground"
            >
              <span>Manter conectado neste navegador</span>
              <small className="block text-[13px] text-texto-3">
                {lembrar
                  ? "Válido por 7 dias. Não marque em computador compartilhado."
                  : "Ao fechar a aba, as notas somem e você entra de novo."}
              </small>
            </Label>
          </div>
          {erro && (
            <p className="text-sm text-critico" role="alert">
              {erro}
            </p>
          )}
          <Button type="submit" size="lg" className="w-full" disabled={ocupado}>
            {ocupado ? "Buscando suas notas no portal…" : "Entrar"}
          </Button>
          <Button
            type="button"
            variant="ghost"
            className="w-full"
            onClick={acoes.entrarDemo}
            disabled={ocupado}
          >
            Ver uma demonstração sem conta
          </Button>
        </form>
      </section>

      <div className="grid gap-4">
        <Card className="grid gap-3.5 px-5 py-4" aria-hidden="true">
          <div className="flex items-start justify-between gap-3">
            <div>
              <strong className="block font-semibold leading-[1.3]">Compiladores</strong>
              <span className="text-xs text-texto-3">CMP · Exemplo de cálculo automático</span>
            </div>
            <Selo tom="apertado">Limite de faltas</Selo>
          </div>
          <div className="grid grid-cols-3 items-center gap-3 border-t border-border pt-2.5 min-[521px]:grid-cols-[repeat(3,minmax(0,1fr))_auto]">
            <div className="grid gap-0.5 tabular-nums">
              <span className="text-[11px] text-texto-3">N1</span>
              <strong className="text-[15px] font-semibold text-critico">3,5</strong>
            </div>
            <div className="grid justify-items-start gap-0.5 tabular-nums">
              <span className="text-[11px] text-texto-3">N2</span>
              <strong className="inline-block rounded-[5px] border border-dashed border-borda-forte bg-secondary px-1.5 py-px text-[13px] font-semibold text-muted-foreground animate-revelar-nota [animation-delay:80ms]">
                ≥7,3
              </strong>
            </div>
            <div className="grid justify-items-start gap-0.5 tabular-nums">
              <span className="text-[11px] text-texto-3">N3</span>
              <strong className="inline-block rounded-[5px] border border-dashed border-borda-forte bg-secondary px-1.5 py-px text-[13px] font-semibold text-muted-foreground animate-revelar-nota [animation-delay:125ms]">
                ≥7,3
              </strong>
            </div>
            <div className="col-span-full grid justify-items-start gap-0.5 tabular-nums min-[521px]:col-auto min-[521px]:justify-items-end">
              <span className="text-[11px] text-texto-3">Faltas</span>
              <Faltas faltas={17} />
            </div>
          </div>
        </Card>

        <aside>
          <Card>
            <CardHeader className="px-[22px] pt-[22px]">
              <CardTitle className="flex items-center gap-2 [&_svg]:size-[17px] [&_svg]:shrink-0 [&_svg]:text-primary">
                <IconeEscudo />
                O que acontece com a sua senha
              </CardTitle>
            </CardHeader>
            <CardContent className="grid gap-4.5 px-[22px] pt-4.5 pb-[22px]">
              <dl className="grid gap-3.5">
                <div>
                  <dt className="font-semibold">Ela vai para o portal, passando por este site.</dt>
                  <dd className="mt-0.5 text-sm text-muted-foreground">
                    O navegador não consegue falar direto com o portal, então o servidor deste site
                    faz o login por você. Ele não grava nem registra a senha.
                  </dd>
                </div>
                <div>
                  <dt className="font-semibold">
                    “Manter conectado” guarda a senha cifrada em um cookie.
                  </dt>
                  <dd className="mt-0.5 text-sm text-muted-foreground">
                    O cookie fica só no seu navegador por até 7 dias e a página não consegue lê-lo.
                    “Sair” apaga tudo.
                  </dd>
                </div>
                <div>
                  <dt className="font-semibold">As notas ficam só neste navegador.</dt>
                  <dd className="mt-0.5 text-sm text-muted-foreground">
                    Não existe banco de dados: nada sobre você é armazenado no servidor (os dados
                    salvos aqui expiram em 7 dias).
                  </dd>
                </div>
              </dl>
              <p className="text-[13px] text-texto-3">
                Projeto de estudantes, sem vínculo com a {instituicao.nome} ou a TOTVS.{" "}
                <Link href="/privacidade" className="underline hover:brightness-110">
                  Privacidade e funcionamento
                </Link>
              </p>
            </CardContent>
          </Card>
        </aside>
      </div>
    </div>
  );
}
