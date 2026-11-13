import { regras } from "../config";

/** 7.25 -> "7,3" */
export const fmt = (n: number) => n.toFixed(1).replace(".", ",");

const PEQUENAS = new Set(["de", "da", "do", "das", "dos", "e", "em", "para", "a", "o"]);

/** "CÁLCULO DIFERENCIAL E INTEGRAL II" -> "Cálculo Diferencial e Integral II" */
export function titulo(texto: string | null | undefined): string {
  if (!texto) return "";
  let primeira = true;
  return texto
    .toLowerCase()
    .split(/(\s+|-)/)
    .map((p) => {
      if (!p.trim() || p === "-") return p;
      const up = p.toUpperCase();
      const saida = /^[IVX]+$/.test(up)
        ? up
        : !primeira && PEQUENAS.has(p)
          ? p
          : p.charAt(0).toUpperCase() + p.slice(1);
      primeira = false;
      return saida;
    })
    .join("");
}

/** "MATÉRIA - SIGLA" -> nome legível + sigla original */
export function nomeMateria(bruto: string): { nome: string; sigla: string } {
  const [nome, ...resto] = bruto.split(" - ");
  return { nome: titulo(nome), sigla: resto.join(" - ") };
}

/** 202623 -> 2026/2 */
export const rotuloPeriodo = (cod: string) =>
  cod.length >= 5 ? `${cod.slice(0, 4)}/${cod.charAt(4)}` : cod;

/** 6 aulas -> "1,5 dias" */
export function dias(aulas: number): string {
  const d = aulas / regras.aulasPorDia;
  return `${Number.isInteger(d) ? d : fmt(d)} ${d === 1 ? "dia" : "dias"}`;
}

const dois = (n: number) => String(n).padStart(2, "0");

/** "hoje às 14:05", "ontem às 09:10" ou "03/11 às 18:00" */
export function quando(iso: string, agora = new Date()): string {
  const t = new Date(iso);
  if (Number.isNaN(t.getTime())) return "";
  const hora = `${dois(t.getHours())}:${dois(t.getMinutes())}`;
  const dia = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const diff = Math.round((dia(agora) - dia(t)) / 86_400_000);
  if (diff === 0) return `hoje às ${hora}`;
  if (diff === 1) return `ontem às ${hora}`;
  return `${dois(t.getDate())}/${dois(t.getMonth() + 1)} às ${hora}`;
}
