import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import Link from "next/link";
import { instituicao } from "@/lib/config";
import "./globals.css";

const fonte = localFont({ src: "./fontes/SchibstedGrotesk.ttf", display: "swap" });

export const metadata: Metadata = {
  title: `Boletim ${instituicao.nome}`,
  description:
    "Notas, faltas e quanto falta para passar em cada matéria, com análise de desempenho ao longo do curso.",
  robots: { index: false },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#191a1d" },
  ],
};

// Aplica o tema escolhido antes da primeira pintura, sem piscar.
const temaInicial = `try{var t=localStorage.getItem("boletim.tema");if(t==="claro"||t==="escuro")document.documentElement.dataset.tema=t}catch(e){}`;

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={fonte.className} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: temaInicial }} />
      </head>
      <body>
        {children}
        <footer>
          <div className="conteudo">
            <span>
              Projeto de estudantes, sem vínculo com a {instituicao.nome} ou a TOTVS. Uso apenas
              para estudo.
            </span>
            <span>
              <Link href="/privacidade">Privacidade e funcionamento</Link>
              {" · "}
              <a href="https://github.com/gaab0418/simpleGradeAnalyticCatolicaSC" rel="noopener">
                Código-fonte
              </a>
            </span>
          </div>
        </footer>
      </body>
    </html>
  );
}
