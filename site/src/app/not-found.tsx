import Link from "next/link";
import { Selo } from "@/componentes/Situacao";
import { Logo } from "@/componentes/icones";
import { Button } from "@/componentes/ui/button";
import {
  Card,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/componentes/ui/card";

export default function NaoEncontrado() {
  return (
    <>
      <header className="sticky top-0 z-20 border-b border-border bg-card/88 backdrop-blur-md">
        <div className="mx-auto flex min-h-[58px] w-full max-w-[1060px] flex-wrap items-center gap-x-4.5 gap-y-2 px-4 md:px-5">
          <Link
            href="/"
            className="flex items-center gap-2.5 font-bold tracking-tight text-foreground no-underline [&_svg]:size-[22px] [&_svg]:shrink-0 [&_svg]:text-primary"
          >
            <Logo />
            <span>
              Grade Analytic{" "}
              <small className="hidden text-[13px] font-normal text-texto-3 sm:inline">
                Boletim
              </small>
            </span>
          </Link>
        </div>
      </header>
      <main className="flex flex-1 items-center px-4 py-12 md:px-5">
        <Card className="mx-auto w-full max-w-[540px]">
          <CardHeader className="space-y-3 px-6 pt-6">
            <div>
              <Selo tom="atencao">Erro 404</Selo>
            </div>
            <CardTitle className="text-2xl font-bold tracking-tight">
              Página não encontrada
            </CardTitle>
            <CardDescription className="text-sm text-muted-foreground">
              O endereço que você tentou acessar não existe ou foi movido.
            </CardDescription>
          </CardHeader>
          <CardFooter className="flex flex-wrap gap-2.5 px-6 pt-2 pb-6">
            <Button asChild>
              <Link href="/">Voltar ao boletim</Link>
            </Button>
            <Button asChild variant="outline">
              <Link href="/privacidade">Termos e privacidade</Link>
            </Button>
          </CardFooter>
        </Card>
      </main>
    </>
  );
}
