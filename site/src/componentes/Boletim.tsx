"use client";

import { Fragment, useState } from "react";
import { acoes, useLoja } from "@/lib/cliente/loja";
import { regras } from "@/lib/config";
import { dias, fmt, nomeMateria, quando, rotuloPeriodo, titulo } from "@/lib/dominio/formato";
import { analisarSemestre, encerrada, passou, simular, type Analise } from "@/lib/dominio/regras";
import { resumir } from "@/lib/dominio/resumo";
import { IconeSeta } from "./icones";
import { Selo } from "./Situacao";

export function Boletim() {
  const { historico, periodo, erro, novidades, demo, lembrado } = useLoja();
  const [abertas, setAbertas] = useState<ReadonlySet<string>>(new Set());
  if (!historico) return null;

  const semestre = historico.semestres.find((s) => s.codigo === periodo);
  const materias = semestre ? analisarSemestre(semestre) : [];
  const r = resumir(materias);
  const { aluno } = historico;

  const alternar = (chave: string) =>
    setAbertas((atual) => {
      const novo = new Set(atual);
      if (!novo.delete(chave)) novo.add(chave);
      return novo;
    });

  return (
    <div className="conteudo">
      <div className="cabecalho-pagina">
        <div>
          <h1>{r.titulo}</h1>
          <p className="sub">
            {[titulo(aluno.nome), titulo(aluno.curso), aluno.ra && `RA ${aluno.ra}`]
              .filter(Boolean)
              .join(" · ")}
          </p>
        </div>
        <label>
          <span className="so-leitor">Semestre</span>
          <select
            className="seletor"
            value={periodo ?? ""}
            onChange={(e) => {
              setAbertas(new Set());
              acoes.selecionarPeriodo(e.target.value);
            }}
          >
            {historico.semestres.map((s) => (
              <option key={s.codigo} value={s.codigo}>
                {rotuloPeriodo(s.codigo)}
              </option>
            ))}
          </select>
        </label>
      </div>

      {demo && (
        <div className="aviso">
          <p>Demonstração com dados fictícios. Nada é salvo.</p>
        </div>
      )}
      {erro && (
        <div className="aviso erro" role="alert">
          <p>
            {erro.mensagem}
            {semestre && ` Mostrando os dados salvos ${quando(semestre.atualizadoEm)}.`}
          </p>
          {erro.tipo === "credenciais" ? (
            <button className="botao" onClick={acoes.sair}>
              Entrar de novo
            </button>
          ) : (
            <button className="botao" onClick={() => acoes.sincronizar()}>
              Tentar de novo
            </button>
          )}
        </div>
      )}
      {!erro && !demo && !lembrado && (
        <div className="aviso">
          <p>Você não está conectado: para atualizar as notas, saia e entre de novo.</p>
        </div>
      )}
      {novidades.length > 0 && (
        <div className="aviso novo" role="status">
          <p>{`Nota nova no portal:\n${novidades.join("\n")}`}</p>
          <button className="botao" onClick={acoes.dispensarNovidades}>
            Ok
          </button>
        </div>
      )}
      {r.foco && (
        <div className="aviso foco">
          <p>{r.foco}</p>
        </div>
      )}

      <dl className="indicadores">
        <div className="indicador">
          <dt>Garantidas</dt>
          <dd>
            {r.garantidas} <small>de {r.materias}</small>
          </dd>
        </div>
        <div className="indicador">
          <dt>Em aberto</dt>
          <dd>{materias.filter((m) => !passou(m.situacao) && !encerrada(m.situacao)).length}</dd>
        </div>
        <div className="indicador">
          <dt>Sem nota ainda</dt>
          <dd>{r.semNota}</dd>
        </div>
        <div className="indicador">
          <dt>Faltas no semestre</dt>
          <dd>
            {r.faltas} <small>aulas</small>
          </dd>
        </div>
      </dl>

      <section className="painel" aria-label="Boletim do semestre">
        {materias.length === 0 ? (
          <p className="vazio">Nenhuma matéria neste semestre. Escolha outro lá em cima.</p>
        ) : (
          <table className="boletim">
            <thead>
              <tr>
                <th scope="col">Matéria</th>
                <th scope="col">N1</th>
                <th scope="col">N2</th>
                <th scope="col">N3</th>
                <th scope="col">Soma</th>
                <th scope="col" title="Média mínima nas provas que faltam para fechar média 6">
                  Precisa de
                </th>
                <th scope="col" className="esq">
                  Faltas
                </th>
                <th scope="col" className="esq">
                  Situação
                </th>
              </tr>
            </thead>
            <tbody>
              {materias.map((m) => {
                const chave = m.disciplina.chave;
                const aberta = abertas.has(chave);
                return (
                  <Fragment key={chave}>
                    <Linha m={m} aberta={aberta} alternar={() => alternar(chave)} />
                    {aberta && (
                      <tr className="detalhe">
                        <td colSpan={8} id={`detalhe-${chave}`}>
                          <Detalhe m={m} />
                        </td>
                      </tr>
                    )}
                  </Fragment>
                );
              })}
            </tbody>
          </table>
        )}
      </section>
      <p className="pequeno" style={{ marginTop: 12 }}>
        Clique em uma matéria para simular as notas que faltam.
        {semestre && ` Dados do portal consultados ${quando(semestre.atualizadoEm)}.`}
      </p>
    </div>
  );
}

function Linha({ m, aberta, alternar }: { m: Analise; aberta: boolean; alternar: () => void }) {
  const d = m.disciplina;
  const { nome, sigla } = nomeMateria(d.nome);
  const definida = encerrada(m.situacao) || passou(m.situacao) || m.precisa === null;

  return (
    <tr className="linha">
      <td className="c-materia">
        <button
          className="materia"
          aria-expanded={aberta}
          aria-controls={`detalhe-${d.chave}`}
          onClick={alternar}
        >
          <IconeSeta />
          <span>
            <strong>{nome}</strong>
            <span>{sigla || d.codDisc}</span>
          </span>
        </button>
      </td>
      {d.notas.map((n, i) => (
        <td key={i} data-rotulo={`N${i + 1}`}>
          {n === null ? (
            <span className="nota vazia">–</span>
          ) : (
            <span className={`nota${n < regras.notaMinima ? " baixa" : ""}`}>{fmt(n)}</span>
          )}
        </td>
      ))}
      <td data-rotulo="Soma">
        <span className="nota soma">{m.lancadas ? fmt(m.soma) : "–"}</span>
      </td>
      <td className="c-precisa" data-rotulo="Precisa de">
        {definida ? (
          <span className="nota vazia">–</span>
        ) : (
          <span className={`precisa${m.precisa! > regras.notaMaxima ? " fora" : ""}`}>
            {fmt(m.precisa!)}{" "}
            {m.restantes > 1 ? "de média" : `na N${d.notas.indexOf(null) + 1}`}
          </span>
        )}
      </td>
      <td className="esq c-faltas" data-rotulo="Faltas">
        <Faltas faltas={d.faltas} />
      </td>
      <td className="esq c-situacao">
        <Selo tom={m.situacao.tom}>{m.situacao.rotulo}</Selo>
      </td>
    </tr>
  );
}

/** Cinco blocos, um por dia de aula que pode ser perdido. */
function Faltas({ faltas }: { faltas: number }) {
  const diasTotais = regras.limiteFaltas / regras.aulasPorDia;
  const sobra = Math.max(0, regras.limiteFaltas - faltas);
  return (
    <span
      className={`faltas${faltas >= regras.alertaFaltas ? " alerta" : ""}`}
      title={`${faltas} de ${regras.limiteFaltas} faltas. Pode faltar mais ${dias(sobra)}.`}
    >
      <span className="barra" aria-hidden>
        {Array.from({ length: diasTotais }, (_, i) => {
          const usadas = Math.min(regras.aulasPorDia, Math.max(0, faltas - i * regras.aulasPorDia));
          return (
            <span className="dia" key={i}>
              <i style={{ width: `${(usadas / regras.aulasPorDia) * 100}%` }} />
            </span>
          );
        })}
      </span>
      {faltas}/{regras.limiteFaltas}
    </span>
  );
}

function Detalhe({ m }: { m: Analise }) {
  const d = m.disciplina;
  const pendentes = d.notas.flatMap((n, i) => (n === null ? [i] : []));
  const inicial = Math.ceil(Math.min(regras.notaMaxima, m.precisa ?? regras.notaMinima) * 2) / 2;
  const [palpites, setPalpites] = useState<Record<number, number>>(() =>
    Object.fromEntries(pendentes.map((i) => [i, inicial])),
  );
  const sobra = Math.max(0, regras.limiteFaltas - d.faltas);
  const fim = m.restantes === 0 || encerrada(m.situacao);
  const sim = simular(m, Object.values(palpites));

  return (
    <div className="grade">
      <div>
        {fim ? (
          <>
            <h3>Notas</h3>
            <p>
              {d.mediaFinal !== null
                ? `Média final ${fmt(d.mediaFinal)}. Situação no portal: ${d.situacao}.`
                : `Todas as notas lançadas. Soma ${fmt(m.soma)} de ${regras.somaAprovacao}.`}
            </p>
          </>
        ) : (
          <>
            <h3>E se eu tirar…</h3>
            {pendentes.map((i) => (
              <div className="controle" key={i}>
                <label htmlFor={`p-${d.chave}-${i}`}>N{i + 1}</label>
                <input
                  id={`p-${d.chave}-${i}`}
                  type="range"
                  min={0}
                  max={regras.notaMaxima}
                  step={0.5}
                  value={palpites[i]}
                  onChange={(e) => setPalpites({ ...palpites, [i]: Number(e.target.value) })}
                />
                <output htmlFor={`p-${d.chave}-${i}`}>{fmt(palpites[i])}</output>
              </div>
            ))}
            <p className="veredito" aria-live="polite">
              Soma {fmt(sim.soma)}:
              <Selo tom={sim.passa ? "ok" : "critico"}>
                {sim.passa
                  ? `passa com média ${fmt(sim.media)}`
                  : `faltariam ${fmt(sim.faltariam)} pontos`}
              </Selo>
            </p>
          </>
        )}
      </div>
      <div>
        <h3>Faltas</h3>
        <p>
          {d.faltas > regras.limiteFaltas
            ? `Você passou do limite: ${d.faltas} faltas de ${regras.limiteFaltas} permitidas.`
            : d.faltas === 0
              ? `Nenhuma falta até agora. Dá para faltar até ${dias(sobra)} antes de reprovar.`
              : `Você faltou ${dias(d.faltas)} (${d.faltas} aulas). Ainda pode faltar ${dias(sobra)} antes de reprovar.`}
        </p>
        <p className="pequeno" style={{ marginTop: 8 }}>
          Disciplina {d.codDisc}, turma {d.codTurma}
        </p>
      </div>
    </div>
  );
}
