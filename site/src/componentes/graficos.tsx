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

/** Linha de uma série só, com o valor escrito em cada ponto e a linha do mínimo. */
export function GraficoEvolucao({ pontos }: { pontos: PontoEvolucao[] }) {
  const [ref, w] = useLargura<HTMLDivElement>();
  const h = 220;
  const m = { cima: 24, baixo: 28, esq: 12, dir: 12 };
  const menor = Math.min(...pontos.map((p) => p.valor), regras.notaMinima);
  const base = Math.max(0, Math.floor(menor) - 1);
  const x = (i: number) =>
    pontos.length === 1
      ? w / 2
      : m.esq + 16 + (i * (w - m.esq - m.dir - 32)) / (pontos.length - 1);
  const y = (v: number) =>
    m.cima + ((regras.notaMaxima - v) * (h - m.cima - m.baixo)) / (regras.notaMaxima - base);
  // Em telas estreitas os rótulos do eixo usam só "26/2".
  const curto = w < 420;

  return (
    <div ref={ref}>
      {w > 0 && (
        <svg
          className="grafico"
          width={w}
          height={h}
          role="img"
          aria-label={`Média por semestre: ${pontos.map((p) => `${p.rotulo} ${fmt(p.valor)}`).join(", ")}.`}
        >
          <line className="eixo" x1={m.esq} x2={w - m.dir} y1={h - m.baixo} y2={h - m.baixo} />
          <line
            className="referencia"
            x1={m.esq}
            x2={w - m.dir}
            y1={y(regras.notaMinima)}
            y2={y(regras.notaMinima)}
          />
          <text className="ref" x={w - m.dir} y={y(regras.notaMinima) + 14} textAnchor="end">
            mínimo {regras.notaMinima}
          </text>
          <polyline
            className="linha"
            points={pontos.map((p, i) => `${x(i)},${y(p.valor)}`).join(" ")}
          />
          {pontos.map((p, i) => (
            <g key={p.rotulo}>
              <circle
                className={`ponto${p.parcial ? " parcial" : ""}`}
                cx={x(i)}
                cy={y(p.valor)}
                r={4.5}
              >
                <title>{`${p.rotulo}: média ${fmt(p.valor)}${p.parcial ? " (parcial)" : ""}`}</title>
              </circle>
              <text className="valor" x={x(i)} y={y(p.valor) - 10} textAnchor="middle">
                {fmt(p.valor)}
              </text>
              <text x={x(i)} y={h - 8} textAnchor="middle">
                {curto ? p.rotulo.slice(2) : p.rotulo}
              </text>
            </g>
          ))}
        </svg>
      )}
    </div>
  );
}

/** Colunas de uma série só, com o valor em cima de cada uma. */
export function GraficoColunas({
  itens,
  maximo,
  inteiro = false,
  descricao,
}: {
  itens: { rotulo: string; valor: number }[];
  maximo?: number;
  inteiro?: boolean;
  descricao: string;
}) {
  const [ref, w] = useLargura<HTMLDivElement>();
  const h = 190;
  const m = { cima: 22, baixo: 28 };
  const teto = maximo ?? Math.max(1, ...itens.map((i) => i.valor));
  const passo = w / itens.length;
  const largura = Math.min(44, passo * 0.56);
  const altura = (v: number) => (v / teto) * (h - m.cima - m.baixo);
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
          <line className="eixo" x1={0} x2={w} y1={h - m.baixo} y2={h - m.baixo} />
          {itens.map((item, i) => {
            const cx = passo * i + passo / 2;
            const a = altura(item.valor);
            const topo = h - m.baixo - a;
            return (
              <g key={item.rotulo}>
                {a > 0 && (
                  <path
                    className="coluna"
                    d={`M${cx - largura / 2},${h - m.baixo} v${-(a - Math.min(4, a))} q0,${-Math.min(4, a)} ${Math.min(4, a)},${-Math.min(4, a)} h${largura - 2 * Math.min(4, a)} q${Math.min(4, a)},0 ${Math.min(4, a)},${Math.min(4, a)} v${a - Math.min(4, a)} z`}
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
