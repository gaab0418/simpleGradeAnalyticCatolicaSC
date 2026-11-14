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
    { media: "(prefers-color-scheme: light)", color: "#f5f4ef" },
    { media: "(prefers-color-scheme: dark)", color: "#171a1e" },
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
        <footer className="border-t border-border bg-card py-5 pb-6 text-[13px] text-texto-3">
          <div className="mx-auto flex w-full max-w-[1060px] flex-wrap justify-between gap-x-5 gap-y-1.5 px-4 md:px-5">
            <span>
              Projeto de estudantes, sem vínculo com a {instituicao.nome} ou a TOTVS. Uso apenas
              para estudo.
            </span>
            <span>
              <Link href="/privacidade" className="text-muted-foreground underline hover:text-foreground">
                Privacidade e funcionamento
              </Link>
              {" · "}
              <a
                href="https://github.com/gaab0418/simpleGradeAnalyticCatolicaSC"
                rel="noopener"
                className="text-muted-foreground underline hover:text-foreground"
              >
                Código-fonte
              </a>
            </span>
          </div>
        </footer>
      </body>
    </html>
  );
}
