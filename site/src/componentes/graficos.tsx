"use client";

import { useMemo, useSyncExternalStore } from "react";
import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Filler,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
  type ChartData,
  type ChartOptions,
  type Plugin,
  type ScriptableLineSegmentContext,
} from "chart.js";
import { Bar, Line } from "react-chartjs-2";
import { regras } from "@/lib/config";
import { fmt } from "@/lib/dominio/formato";

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Filler,
  Tooltip,
);

interface CoresGrafico {
  acento: string;
  acentoSuave: string;
  borda: string;
  texto2: string;
  texto3: string;
  superficie: string;
  critico: string;
  fonte: string;
}

const FALLBACK_CORES: CoresGrafico = {
  acento: "#1d4ed8",
  acentoSuave: "rgba(29, 78, 216, 0.08)",
  borda: "#dfddd3",
  texto2: "#555863",
  texto3: "#7b7f8c",
  superficie: "#ffffff",
  critico: "#b3261e",
  fonte: "sans-serif",
};

let cacheCores: CoresGrafico = FALLBACK_CORES;
let cacheChave = "";

function lerCoresComputadas(): CoresGrafico {
  if (typeof window === "undefined") return FALLBACK_CORES;
  const cs = getComputedStyle(document.documentElement);
  const v = (nome: string, padrao: string) => cs.getPropertyValue(nome).trim() || padrao;
  const acento = v("--acento", FALLBACK_CORES.acento);
  const acentoSuave = v("--acento-suave", FALLBACK_CORES.acentoSuave);
  const borda = v("--borda", FALLBACK_CORES.borda);
  const texto2 = v("--texto-2", FALLBACK_CORES.texto2);
  const texto3 = v("--texto-3", FALLBACK_CORES.texto3);
  const superficie = v("--superficie", FALLBACK_CORES.superficie);
  const critico = v("--critico", FALLBACK_CORES.critico);
  const fonte = cs.fontFamily || FALLBACK_CORES.fonte;
  const chave = `${acento}|${acentoSuave}|${borda}|${texto2}|${texto3}|${superficie}|${critico}|${fonte}`;
  if (chave !== cacheChave) {
    cacheChave = chave;
    cacheCores = { acento, acentoSuave, borda, texto2, texto3, superficie, critico, fonte };
  }
  return cacheCores;
}

function inscreverTema(aoMudar: () => void): () => void {
  const obs = new MutationObserver(() => aoMudar());
  obs.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["data-tema"],
  });
  const mq = window.matchMedia("(prefers-color-scheme: dark)");
  mq.addEventListener("change", aoMudar);
  return () => {
    obs.disconnect();
    mq.removeEventListener("change", aoMudar);
  };
}

function useCoresGrafico(): CoresGrafico {
  return useSyncExternalStore(inscreverTema, lerCoresComputadas, () => FALLBACK_CORES);
}

export interface PontoEvolucao {
  rotulo: string;
  valor: number;
  parcial: boolean;
}

/** Linha com área suave, grade horizontal, trecho parcial tracejado e linha de mínimo. */
export function GraficoEvolucao({ pontos }: { pontos: PontoEvolucao[] }) {
  const cores = useCoresGrafico();
  const menor = Math.min(...pontos.map((p) => p.valor), regras.notaMinima);
  const base = Math.max(0, Math.floor(menor) - 1);

  const data = useMemo<ChartData<"line">>(
    () => ({
      labels: pontos.map((p) => p.rotulo),
      datasets: [
        {
          label: "Média",
          data: pontos.map((p) => p.valor),
          borderColor: cores.acento,
          backgroundColor: cores.acentoSuave,
          borderWidth: 2.25,
          fill: true,
          tension: 0.25,
          pointRadius: 4.5,
          pointHoverRadius: 6.5,
          pointHitRadius: 14,
          pointBorderWidth: 2,
          pointBackgroundColor: pontos.map((p) => (p.parcial ? cores.superficie : cores.acento)),
          pointBorderColor: pontos.map((p) => (p.parcial ? cores.acento : cores.superficie)),
          segment: {
            borderDash: (ctx: ScriptableLineSegmentContext) =>
              pontos[ctx.p1DataIndex]?.parcial ? [5, 4] : undefined,
          },
        },
        {
          label: `Mínimo ${fmt(regras.notaMinima)}`,
          data: pontos.map(() => regras.notaMinima),
          borderColor: cores.critico,
          borderWidth: 1.25,
          borderDash: [4, 4],
          pointRadius: 0,
          pointHoverRadius: 0,
          pointHitRadius: 0,
          fill: false,
          tension: 0,
        },
      ],
    }),
    [pontos, cores],
  );

  const options = useMemo<ChartOptions<"line">>(
    () => ({
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: "index",
        intersect: false,
      },
      plugins: {
        tooltip: {
          backgroundColor: cores.superficie,
          titleColor: cores.texto2,
          bodyColor: cores.texto2,
          borderColor: cores.borda,
          borderWidth: 1,
          padding: 10,
          displayColors: false,
          titleFont: { family: cores.fonte, size: 12, weight: "bold" },
          bodyFont: { family: cores.fonte, size: 13 },
          filter: (item) => item.datasetIndex === 0,
          callbacks: {
            title: (items) => {
              const idx = items[0]?.dataIndex;
              if (idx === undefined) return "";
              const p = pontos[idx];
              return p ? `${p.rotulo}${p.parcial ? " (em andamento)" : ""}` : "";
            },
            label: (ctx) => `Média: ${fmt(Number(ctx.parsed.y))}`,
          },
        },
      },
      scales: {
        x: {
          grid: { display: false },
          border: { color: cores.borda },
          ticks: {
            color: cores.texto2,
            font: { family: cores.fonte, size: 12 },
          },
        },
        y: {
          min: base,
          max: regras.notaMaxima,
          border: { display: false },
          grid: { color: cores.borda },
          ticks: {
            color: cores.texto3,
            font: { family: cores.fonte, size: 11 },
            stepSize: 1,
            callback: (val) => fmt(Number(val)),
          },
        },
      },
    }),
    [cores, base, pontos],
  );

  return (
    <div className="grid gap-1.5">
      <div className="relative h-[232px] w-full">
        <Line
          data={data}
          options={options}
          role="img"
          aria-label={`Média por semestre: ${pontos.map((p) => `${p.rotulo} ${fmt(p.valor)}`).join(", ")}.`}
        />
      </div>
    </div>
  );
}

const formatarValor = (v: number, inteiro: boolean) => (inteiro ? String(Math.round(v)) : fmt(v));

/** Colunas verticais com grade discreta e linha de referência opcional. */
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
  const cores = useCoresGrafico();

  const data = useMemo<ChartData<"bar">>(
    () => ({
      labels: itens.map((i) => i.rotulo),
      datasets: [
        {
          label: descricao,
          data: itens.map((i) => i.valor),
          backgroundColor: cores.acento,
          hoverBackgroundColor: cores.acento,
          borderRadius: 6,
          maxBarThickness: 48,
        },
      ],
    }),
    [itens, descricao, cores],
  );

  const options = useMemo<ChartOptions<"bar">>(
    () => ({
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        tooltip: {
          backgroundColor: cores.superficie,
          titleColor: cores.texto2,
          bodyColor: cores.texto2,
          borderColor: cores.borda,
          borderWidth: 1,
          padding: 10,
          displayColors: false,
          titleFont: { family: cores.fonte, size: 12, weight: "bold" },
          bodyFont: { family: cores.fonte, size: 13 },
          callbacks: {
            label: (ctx) => formatarValor(Number(ctx.parsed.y), inteiro),
          },
        },
      },
      scales: {
        x: {
          grid: { display: false },
          border: { color: cores.borda },
          ticks: {
            color: cores.texto2,
            font: { family: cores.fonte, size: 12 },
          },
        },
        y: {
          min: 0,
          max: maximo,
          suggestedMax: maximo ?? Math.max(1, ...itens.map((i) => i.valor), referencia ?? 0),
          border: { display: false },
          grid: { color: cores.borda },
          ticks: {
            color: cores.texto3,
            font: { family: cores.fonte, size: 11 },
            precision: inteiro ? 0 : undefined,
            callback: (val) => formatarValor(Number(val), inteiro),
          },
        },
      },
    }),
    [cores, maximo, inteiro, itens, referencia],
  );

  const plugins = useMemo<Plugin<"bar">[]>(() => {
    if (referencia === undefined) return [];
    return [
      {
        id: "linhaReferenciaColunas",
        afterDatasetsDraw(chart) {
          const yScale = chart.scales.y;
          if (!yScale) return;
          const y = yScale.getPixelForValue(referencia);
          const { left, right, top, bottom } = chart.chartArea;
          if (y < top || y > bottom) return;
          const cs = getComputedStyle(chart.canvas);
          const cor = cs.getPropertyValue("--critico").trim() || FALLBACK_CORES.critico;
          const { ctx } = chart;
          ctx.save();
          ctx.beginPath();
          ctx.setLineDash([4, 4]);
          ctx.lineWidth = 1.25;
          ctx.strokeStyle = cor;
          ctx.moveTo(left, y);
          ctx.lineTo(right, y);
          ctx.stroke();
          ctx.fillStyle = cor;
          ctx.font = `500 11px ${cs.fontFamily || "sans-serif"}`;
          ctx.textAlign = "right";
          ctx.textBaseline = "bottom";
          ctx.fillText(`mínimo ${referencia}`, right, y - 4);
          ctx.restore();
        },
      },
    ];
  }, [referencia]);

  return (
    <div className="grid gap-1.5">
      <div className="relative h-[196px] w-full">
        <Bar
          data={data}
          options={options}
          plugins={plugins}
          role="img"
          aria-label={`${descricao}: ${itens.map((i) => `${i.rotulo} ${formatarValor(i.valor, inteiro)}`).join(", ")}.`}
        />
      </div>
    </div>
  );
}
