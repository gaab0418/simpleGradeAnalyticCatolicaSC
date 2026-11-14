import type { Metadata } from "next";
import Link from "next/link";
import { instituicao } from "@/lib/config";
import { Logo } from "@/componentes/icones";

export const metadata: Metadata = { title: "Privacidade e funcionamento" };

export default function Privacidade() {
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
              Boletim{" "}
              <small className="hidden text-[13px] font-normal text-texto-3 sm:inline">
                {instituicao.nome}
              </small>
            </span>
          </Link>
        </div>
      </header>
      <main className="flex-1 pt-5 pb-12 md:pt-7">
        <article className="mx-auto w-full max-w-[680px] space-y-4 px-4 md:px-5">
          <h1 className="text-[26px] font-bold leading-tight tracking-tight">
            Privacidade e funcionamento
          </h1>
          <p>
            Este site mostra as suas notas e faltas do portal acadêmico da {instituicao.nome} de um
            jeito mais fácil de ler. Ele é feito por estudantes, não é oficial e não tem vínculo
            com a {instituicao.nome} nem com a TOTVS.
          </p>

          <h2 className="mt-4 text-[17px] font-semibold">O caminho da sua senha</h2>
          <ul className="list-disc space-y-1.5 pl-5">
            <li>
              O navegador não consegue acessar o portal diretamente, então o servidor deste site
              faz o login em seu nome. A senha trafega por HTTPS até ele e dele até o portal.
            </li>
            <li>
              O servidor não tem banco de dados e não grava nem registra a senha. Ela existe na
              memória apenas enquanto a consulta acontece.
            </li>
            <li>
              Se você marcar “Manter conectado”, usuário e senha são cifrados (AES-256-GCM) com
              uma chave que só o servidor conhece e devolvidos ao seu navegador em um cookie que
              a página não consegue ler. O servidor só consegue usá-lo quando o seu navegador o
              envia. O cookie vale 7 dias.
            </li>
            <li>
              Mesmo assim, quem hospeda o site tem meios técnicos de alterar o código e ver o que
              passa por ele. Use apenas se confiar em quem o publicou; o código é aberto para
              conferência.
            </li>
          </ul>

          <h2 className="mt-4 text-[17px] font-semibold">O que fica no seu navegador</h2>
          <ul className="list-disc space-y-1.5 pl-5">
            <li>
              As notas e faltas de cada semestre, para abrir rápido e funcionar offline (expiram
              automaticamente após 7 dias sem uso).
            </li>
            <li>A preferência de tema claro ou escuro.</li>
            <li>
              Sem “Manter conectado”, as notas ficam só na aba aberta e somem quando ela é
              fechada.
            </li>
          </ul>

          <h2 className="mt-4 text-[17px] font-semibold">Como apagar tudo</h2>
          <p>
            O botão de sair, no canto superior direito, apaga o cookie de sessão e todos os dados
            salvos neste navegador. Nada muda no portal.
          </p>

          <h2 className="mt-4 text-[17px] font-semibold">O que não existe aqui</h2>
          <ul className="list-disc space-y-1.5 pl-5">
            <li>Anúncios, rastreadores ou ferramentas de análise de uso.</li>
            <li>Cadastro, conta própria ou qualquer dado guardado no servidor.</li>
          </ul>

          <p className="pt-2">
            <Link href="/" className="underline hover:brightness-110">
              Voltar ao boletim
            </Link>
          </p>
        </article>
      </main>
    </>
  );
}
