"use client";

import { useEffect, useRef, useState } from "react";
import { regras } from "@/lib/config";
import { fmt } from "@/lib/dominio/formato";

/** Largura real do contêiner, para o SVG desenhar texto em tamanho fixo. */
function useLargura<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [largura, setLargura] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new ResizeObserver(([e]) => setLargura(Math.round(e.contentRect.width)));
    obs.observe(el);
    return () => obs.disconnect();
  }, []);
  return [ref, largura] as const;
}

export interface PontoEvolucao {
  rotulo: string;
  valor: number;
  parcial: boolean;
}

/** Linha com área suave, grade horizontal, trecho parcial tracejado e leitura ao passar o mouse. */
export function GraficoEvolucao({ pontos }: { pontos: PontoEvolucao[] }) {
  const [ref, w] = useLargura<HTMLDivElement>();
  const [ativo, setAtivo] = useState<number | null>(null);
  const h = 232;
  const m = { cima: 28, baixo: 30, esq: 28, dir: 16 };
  const menor = Math.min(...pontos.map((p) => p.valor), regras.notaMinima);
  const base = Math.max(0, Math.floor(menor) - 1);
  const x = (i: number) =>
    pontos.length === 1
      ? (w + m.esq - m.dir) / 2
      : m.esq + 16 + (i * (w - m.esq - m.dir - 32)) / (pontos.length - 1);
  const y = (v: number) =>
    m.cima + ((regras.notaMaxima - v) * (h - m.cima - m.baixo)) / (regras.notaMaxima - base);
  const curto = w < 440;

  const marcasY: number[] = [];
  for (let v = Math.ceil(base / 2) * 2; v <= regras.notaMaxima; v += 2) {
    marcasY.push(v);
  }

  const ultimoParcial = pontos.length >= 2 && pontos.at(-1)!.parcial;
  const firmes = ultimoParcial ? pontos.slice(0, -1) : pontos;
  const pontoAtivo = ativo !== null ? pontos[ativo] : null;

  const baseY = h - m.baixo;
  const areaD =
    pontos.length >= 2
      ? `M${x(0)},${baseY} ${pontos.map((p, i) => `L${x(i)},${y(p.valor)}`).join(" ")} L${x(pontos.length - 1)},${baseY} Z`
      : "";

  return (
    <div ref={ref} className="grafico-caixa">
      <div className="grafico-status" aria-live="polite">
        {pontoAtivo ? (
          <span>
            <strong>{pontoAtivo.rotulo}</strong> · média {fmt(pontoAtivo.valor)}
            {pontoAtivo.parcial ? " (em andamento)" : ""}
          </span>
        ) : (
          <span className="pequeno">Passe o mouse ou foque um ponto para inspecionar</span>
        )}
      </div>
      {w > 0 && (
        <svg
          className="grafico"
          width={w}
          height={h}
          role="img"
          aria-label={`Média por semestre: ${pontos.map((p) => `${p.rotulo} ${fmt(p.valor)}`).join(", ")}.`}
        >
          {marcasY.map((v) => (
            <g key={v}>
              <line className="grade-linha" x1={m.esq} x2={w - m.dir} y1={y(v)} y2={y(v)} />
              <text className="eixo-txt" x={m.esq - 6} y={y(v) + 4} textAnchor="end">
                {v}
              </text>
            </g>
          ))}
          <line className="eixo" x1={m.esq} x2={w - m.dir} y1={baseY} y2={baseY} />
          <line
            className="referencia"
            x1={m.esq}
            x2={w - m.dir}
            y1={y(regras.notaMinima)}
            y2={y(regras.notaMinima)}
          />
          <text className="ref" x={w - m.dir} y={y(regras.notaMinima) - 5} textAnchor="end">
            mínimo {regras.notaMinima}
          </text>
          {areaD && <path className="area" d={areaD} />}
          {firmes.length >= 2 && (
            <polyline
              className="linha"
              points={firmes.map((p, i) => `${x(i)},${y(p.valor)}`).join(" ")}
            />
          )}
          {ultimoParcial && (
            <line
              className="linha parcial"
              x1={x(pontos.length - 2)}
              y1={y(pontos[pontos.length - 2].valor)}
              x2={x(pontos.length - 1)}
              y2={y(pontos[pontos.length - 1].valor)}
            />
          )}
          {ativo !== null && (
            <line
              className="guia"
              x1={x(ativo)}
              x2={x(ativo)}
              y1={m.cima}
              y2={baseY}
            />
          )}
          {pontos.map((p, i) => {
            const focado = ativo === i;
            return (
              <g
                key={p.rotulo}
                className="alvo-ponto"
                tabIndex={0}
                role="button"
                aria-label={`${p.rotulo}: média ${fmt(p.valor)}${p.parcial ? " (parcial)" : ""}`}
                onMouseEnter={() => setAtivo(i)}
                onMouseLeave={() => setAtivo(null)}
                onFocus={() => setAtivo(i)}
                onBlur={() => setAtivo(null)}
              >
                <circle cx={x(i)} cy={y(p.valor)} r={16} fill="transparent" />
                <circle
                  className={`ponto${p.parcial ? " parcial" : ""}${focado ? " ativo" : ""}`}
                  cx={x(i)}
                  cy={y(p.valor)}
                  r={focado ? 6.5 : 4.5}
                >
                  <title>{`${p.rotulo}: média ${fmt(p.valor)}${p.parcial ? " (parcial)" : ""}`}</title>
                </circle>
                <text
                  className={`valor${focado ? " ativo" : ""}`}
                  x={x(i)}
                  y={y(p.valor) - 11}
                  textAnchor="middle"
                >
                  {fmt(p.valor)}
                </text>
                <text x={x(i)} y={h - 8} textAnchor="middle">
                  {curto && p.rotulo.length > 4 ? p.rotulo.slice(2) : p.rotulo}
                </text>
              </g>
            );
          })}
        </svg>
      )}
    </div>
  );
}

/** Colunas verticais com valores no topo, grade discreta e linha de referência opcional. */
export function GraficoColunas({
  itens,
  maximo,
  referencia,
  inteiro = false,
  descricao,
}: {
  itens: { rotulo: string; valor: number }[];
  maximo?: number;
  referencia?: number;
  inteiro?: boolean;
  descricao: string;
}) {
  const [ref, w] = useLargura<HTMLDivElement>();
  const [ativo, setAtivo] = useState<number | null>(null);
  const h = 196;
  const m = { cima: 24, baixo: 28 };
  const teto = maximo ?? Math.max(1, ...itens.map((i) => i.valor));
  const passo = w / Math.max(1, itens.length);
  const largura = Math.min(44, passo * 0.56);
  const utilH = h - m.cima - m.baixo;
  const altura = (v: number) => (v / teto) * utilH;
  const yDe = (v: number) => h - m.baixo - altura(v);
  const txt = (v: number) => (inteiro ? String(v) : fmt(v));
  const curto = passo < 56;

  return (
    <div ref={ref}>
      {w > 0 && (
        <svg
          className="grafico"
          width={w}
          height={h}
          role="img"
          aria-label={`${descricao}: ${itens.map((i) => `${i.rotulo} ${txt(i.valor)}`).join(", ")}.`}
        >
          {[0.5, 1].map((f) => (
            <line
              key={f}
              className="grade-linha"
              x1={0}
              x2={w}
              y1={h - m.baixo - utilH * f}
              y2={h - m.baixo - utilH * f}
            />
          ))}
          {referencia !== undefined && referencia <= teto && (
            <>
              <line
                className="referencia"
                x1={0}
                x2={w}
                y1={yDe(referencia)}
                y2={yDe(referencia)}
              />
              <text className="ref" x={w} y={yDe(referencia) - 4} textAnchor="end">
                mínimo {referencia}
              </text>
            </>
          )}
          <line className="eixo" x1={0} x2={w} y1={h - m.baixo} y2={h - m.baixo} />
          {itens.map((item, i) => {
            const cx = passo * i + passo / 2;
            const a = altura(item.valor);
            const topo = h - m.baixo - a;
            const focado = ativo === i;
            const raio = Math.min(4, a);
            return (
              <g
                key={item.rotulo}
                className="alvo-coluna"
                onMouseEnter={() => setAtivo(i)}
                onMouseLeave={() => setAtivo(null)}
              >
                {a > 0 && (
                  <path
                    className={`coluna${focado ? " ativa" : ""}`}
                    d={`M${cx - largura / 2},${h - m.baixo} v${-(a - raio)} q0,${-raio} ${raio},${-raio} h${largura - 2 * raio} q${raio},0 ${raio},${raio} v${a - raio} z`}
                  >
                    <title>{`${item.rotulo}: ${txt(item.valor)}`}</title>
                  </path>
                )}
                <text className="valor" x={cx} y={topo - 6} textAnchor="middle">
                  {txt(item.valor)}
                </text>
                <text x={cx} y={h - 8} textAnchor="middle">
                  {curto && item.rotulo.length > 4 ? item.rotulo.slice(2) : item.rotulo}
                </text>
              </g>
            );
          })}
        </svg>
      )}
    </div>
  );
}
