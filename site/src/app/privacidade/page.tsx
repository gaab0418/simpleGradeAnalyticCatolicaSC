import type { Metadata } from "next";
import Link from "next/link";
import { Logo } from "@/componentes/icones";

export const metadata: Metadata = { title: "Termos de uso, privacidade e funcionamento" };

const REPO_URL = "https://github.com/gaab0418/simpleGradeAnalyticCatolicaSC";

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
              Grade Analytic{" "}
              <small className="hidden text-[13px] font-normal text-texto-3 sm:inline">
                Boletim
              </small>
            </span>
          </Link>
        </div>
      </header>
      <main className="flex-1 pt-5 pb-12 md:pt-7">
        <article className="mx-auto w-full max-w-[680px] space-y-4 px-4 md:px-5">
          <h1 className="text-[26px] font-bold leading-tight tracking-tight">
            Termos de uso, privacidade e funcionamento
          </h1>
          <p>
            O <strong>Grade Analytic</strong> mostra as suas notas e faltas do portal acadêmico de
            um jeito mais fácil de ler. Ele é um projeto criado{" "}
            <strong>de estudante para estudante</strong>, com o intuito educacional de aprender a
            usar, em um caso real, as ferramentas e tecnologias disponíveis e vistas durante as
            aulas — não é oficial e não tem vínculo com a instituição de ensino nem com a TOTVS.
          </p>

          <h2 className="mt-4 text-[17px] font-semibold">
            Termos de uso e isenção de responsabilidade
          </h2>
          <ul className="list-disc space-y-1.5 pl-5">
            <li>
              <strong>Finalidade de estudo:</strong> sistema sem fins lucrativos, disponibilizado
              para consulta pessoal e prática acadêmica.
            </li>
            <li>
              <strong>Sem garantias e sem responsabilidade:</strong> o site é fornecido “no estado
              em que se encontra” (<em>as-is</em>). O autor{" "}
              <strong>não se responsabiliza por nada</strong> decorrente do uso — incluindo
              eventuais divergências em notas, médias, substituição da N4, simulações, contagem de
              faltas, indisponibilidade do portal ou qualquer decisão acadêmica.
            </li>
            <li>
              <strong>Fonte oficial:</strong> confira sempre as informações oficiais diretamente no
              Portal do Aluno oficial da sua instituição.
            </li>
          </ul>

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

          <h2 className="mt-4 text-[17px] font-semibold">Licença de uso não comercial</h2>
          <p>
            O código-fonte é aberto sob a licença{" "}
            <a
              href={`${REPO_URL}/blob/main/LICENSE.md`}
              target="_blank"
              rel="noopener noreferrer"
              className="underline hover:brightness-110"
            >
              PolyForm Noncommercial 1.0.0
            </a>{" "}
            (permitido apenas uso pessoal, estudo e fins não comerciais). Os termos completos ficam
            em{" "}
            <a
              href={`${REPO_URL}/blob/main/TERMS.md`}
              target="_blank"
              rel="noopener noreferrer"
              className="underline hover:brightness-110"
            >
              TERMS.md
            </a>
            .
          </p>

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
