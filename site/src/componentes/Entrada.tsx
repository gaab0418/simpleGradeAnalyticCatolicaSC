"use client";

import Link from "next/link";
import { useState } from "react";
import { acoes, useLoja } from "@/lib/cliente/loja";
import { instituicao } from "@/lib/config";

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
    <div className="conteudo entrada">
      <section>
        <h1>Suas notas e faltas, com o que falta para passar.</h1>
        <p className="sub">
          Entre com o mesmo usuário e senha do portal da {instituicao.nome}.
        </p>

        <form onSubmit={enviar}>
          <div className="campo">
            <label htmlFor="usuario">Usuário do portal</label>
            <input
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
          <div className="campo">
            <label htmlFor="senha">Senha</label>
            <div className="senha">
              <input
                id="senha"
                name="senha"
                type={mostrar ? "text" : "password"}
                autoComplete="current-password"
                required
                disabled={ocupado}
              />
              <button type="button" onClick={() => setMostrar(!mostrar)} aria-pressed={mostrar}>
                {mostrar ? "Esconder" : "Mostrar"}
              </button>
            </div>
          </div>
          <label className="opcao">
            <input
              type="checkbox"
              checked={lembrar}
              onChange={(e) => setLembrar(e.target.checked)}
              disabled={ocupado}
            />
            <span>
              Manter conectado neste navegador
              <small>
                {lembrar
                  ? "Não marque em computador compartilhado."
                  : "Ao fechar a aba, as notas somem e você entra de novo."}
              </small>
            </span>
          </label>
          {erro && (
            <p className="erro-form" role="alert">
              {erro}
            </p>
          )}
          <button className="botao primario" type="submit" disabled={ocupado}>
            {ocupado ? "Buscando suas notas no portal…" : "Entrar"}
          </button>
          <button className="botao discreto" type="button" onClick={acoes.entrarDemo} disabled={ocupado}>
            Ver uma demonstração sem conta
          </button>
        </form>
      </section>

      <aside className="painel como">
        <h2>O que acontece com a sua senha</h2>
        <dl>
          <div>
            <dt>Ela vai para o portal, passando por este site.</dt>
            <dd>
              O navegador não consegue falar direto com o portal, então o servidor deste site faz
              o login por você. Ele não grava nem registra a senha.
            </dd>
          </div>
          <div>
            <dt>“Manter conectado” guarda a senha cifrada em um cookie.</dt>
            <dd>
              O cookie fica só no seu navegador e a página não consegue lê-lo. “Sair” apaga tudo.
            </dd>
          </div>
          <div>
            <dt>As notas ficam só neste navegador.</dt>
            <dd>Não existe banco de dados: nada sobre você é armazenado no servidor.</dd>
          </div>
        </dl>
        <p className="pequeno">
          Projeto de estudantes, sem vínculo com a {instituicao.nome} ou a TOTVS.{" "}
          <Link href="/privacidade">Privacidade e funcionamento</Link>
        </p>
      </aside>
    </div>
  );
}
