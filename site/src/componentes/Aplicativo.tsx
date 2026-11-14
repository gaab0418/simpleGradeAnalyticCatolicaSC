"use client";

import { useEffect, useSyncExternalStore } from "react";
import { acoes, useLoja } from "@/lib/cliente/loja";
import { instituicao } from "@/lib/config";
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
      <header className="topo">
        <div className="conteudo">
          <span className="marca">
            <Logo />
            <span>
              Boletim <small>{instituicao.nome}</small>
            </span>
          </span>
          {pronto && (
            <nav className="abas" aria-label="Seções">
              {(["boletim", "desempenho"] as const).map((aba) => (
                <button
                  key={aba}
                  type="button"
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
                  type="button"
                  className={`botao botao-atualizar${estado.ocupado ? " girando" : ""}`}
                  onClick={() => acoes.sincronizar()}
                  disabled={estado.ocupado}
                  title="Busca as notas do semestre atual no portal"
                  aria-label="Atualizar notas do semestre atual"
                >
                  <IconeAtualizar />
                  <span className="rotulo-acao">{estado.ocupado ? "Atualizando…" : "Atualizar"}</span>
                </button>
                <button
                  type="button"
                  className="botao icone"
                  onClick={() => acoes.sincronizar(true)}
                  disabled={estado.ocupado}
                  title="Rebaixar histórico: atualiza também todos os semestres já encerrados"
                  aria-label="Rebaixar histórico completo de todos os semestres"
                >
                  <IconeHistorico />
                </button>
              </>
            )}
            <div className="tema-grupo" role="group" aria-label="Aparência">
              {OPCOES_TEMA.map((op) => (
                <button
                  key={op.id}
                  type="button"
                  className="tema-btn"
                  aria-pressed={tema === op.id}
                  aria-label={op.rotulo}
                  title={op.rotulo}
                  onClick={() => definirTema(op.id)}
                >
                  {op.icone}
                </button>
              ))}
            </div>
            {pronto && (
              <button
                type="button"
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
        {estado.fase === "carregando" && <Esqueleto />}
        {estado.fase === "deslogado" && <Entrada />}
        {pronto && (estado.aba === "boletim" ? <Boletim /> : <Desempenho />)}
      </main>
    </>
  );
}

function Esqueleto() {
  return (
    <div className="conteudo esqueleto" aria-busy="true">
      <span className="so-leitor">Carregando boletim…</span>
      <div className="esq-cabecalho">
        <span className="esq-bloco" style={{ width: "42%", height: 28 }} />
        <span className="esq-bloco" style={{ width: "26%", height: 16 }} />
      </div>
      <div className="indicadores">
        {Array.from({ length: 4 }, (_, i) => (
          <div className="indicador" key={i}>
            <span className="esq-bloco" style={{ width: "55%", height: 12 }} />
            <span className="esq-bloco" style={{ width: "40%", height: 24, marginTop: 8 }} />
          </div>
        ))}
      </div>
      <div className="painel">
        {["48%", "36%", "56%", "40%"].map((largura, i) => (
          <div className="esq-linha" key={i}>
            <span className="esq-bloco" style={{ width: largura, height: 15 }} />
            <span className="esq-bloco" style={{ width: 88, height: 22 }} />
          </div>
        ))}
      </div>
    </div>
  );
}
