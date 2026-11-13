import type { Metadata } from "next";
import Link from "next/link";
import { instituicao } from "@/lib/config";
import { Logo } from "@/componentes/icones";

export const metadata: Metadata = { title: "Privacidade e funcionamento" };

export default function Privacidade() {
  return (
    <>
      <header className="topo">
        <div className="conteudo">
          <Link href="/" className="marca">
            <Logo />
            Boletim <small>{instituicao.nome}</small>
          </Link>
        </div>
      </header>
      <main>
        <article className="conteudo texto">
          <h1>Privacidade e funcionamento</h1>
          <p>
            Este site mostra as suas notas e faltas do portal acadêmico da {instituicao.nome} de um
            jeito mais fácil de ler. Ele é feito por estudantes, não é oficial e não tem vínculo
            com a {instituicao.nome} nem com a TOTVS.
          </p>

          <h2>O caminho da sua senha</h2>
          <ul>
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
              envia. O cookie vale 30 dias.
            </li>
            <li>
              Mesmo assim, quem hospeda o site tem meios técnicos de alterar o código e ver o que
              passa por ele. Use apenas se confiar em quem o publicou; o código é aberto para
              conferência.
            </li>
          </ul>

          <h2>O que fica no seu navegador</h2>
          <ul>
            <li>As notas e faltas de cada semestre, para abrir rápido e funcionar offline.</li>
            <li>A preferência de tema claro ou escuro.</li>
            <li>
              Sem “Manter conectado”, as notas ficam só na aba aberta e somem quando ela é
              fechada.
            </li>
          </ul>

          <h2>Como apagar tudo</h2>
          <p>
            O botão de sair, no canto superior direito, apaga o cookie de sessão e todos os dados
            salvos neste navegador. Nada muda no portal.
          </p>

          <h2>O que não existe aqui</h2>
          <ul>
            <li>Anúncios, rastreadores ou ferramentas de análise de uso.</li>
            <li>Cadastro, conta própria ou qualquer dado guardado no servidor.</li>
          </ul>

          <p>
            <Link href="/">Voltar ao boletim</Link>
          </p>
        </article>
      </main>
    </>
  );
}
