"use client";

import { useEffect } from "react";
import { acoes, useLoja } from "@/lib/cliente/loja";
import { instituicao } from "@/lib/config";
import { quando } from "@/lib/dominio/formato";
import { Boletim } from "./Boletim";
import { Desempenho } from "./Desempenho";
import { Entrada } from "./Entrada";
import { IconeAtualizar, IconeSair, IconeTema, Logo } from "./icones";

function alternarTema() {
  const raiz = document.documentElement;
  const atual =
    raiz.dataset.tema ?? (matchMedia("(prefers-color-scheme: dark)").matches ? "escuro" : "claro");
  const novo = atual === "escuro" ? "claro" : "escuro";
  raiz.dataset.tema = novo;
  try {
    localStorage.setItem("boletim.tema", novo);
  } catch {
    // preferência só não persiste
  }
}

export function Aplicativo() {
  const estado = useLoja();
  useEffect(() => acoes.iniciar(), []);

  const pronto = estado.fase === "pronto";
  const ultima = estado.historico?.semestres
    .map((s) => s.atualizadoEm)
    .sort()
    .at(-1);

  return (
    <>
      <header className="topo">
        <div className="conteudo">
          <span className="marca">
            <Logo />
            Boletim <small>{instituicao.nome}</small>
          </span>
          {pronto && (
            <nav className="abas" aria-label="Seções">
              {(["boletim", "desempenho"] as const).map((aba) => (
                <button
                  key={aba}
                  className="aba"
                  aria-current={estado.aba === aba ? "page" : undefined}
                  onClick={() => acoes.abrirAba(aba)}
                >
                  {aba === "boletim" ? "Boletim" : "Desempenho"}
                </button>
              ))}
            </nav>
          )}
          <div className="acoes">
            {pronto && estado.lembrado && (
              <>
                {ultima && <span className="atualizado">Atualizado {quando(ultima)}</span>}
                <button
                  className={`botao${estado.ocupado ? " girando" : ""}`}
                  onClick={() => acoes.sincronizar()}
                  disabled={estado.ocupado}
                  title="Busca as notas de novo no portal"
                >
                  <IconeAtualizar />
                  {estado.ocupado ? "Atualizando…" : "Atualizar"}
                </button>
              </>
            )}
            <button className="botao icone" onClick={alternarTema} aria-label="Alternar tema claro e escuro">
              <IconeTema />
            </button>
            {pronto && (
              <button
                className="botao icone"
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
              </button>
            )}
          </div>
        </div>
      </header>

      <main>
        {estado.fase === "carregando" && <div className="conteudo vazio" aria-busy="true" />}
        {estado.fase === "deslogado" && <Entrada />}
        {pronto && (estado.aba === "boletim" ? <Boletim /> : <Desempenho />)}
      </main>
    </>
  );
}
