import type { Tom } from "@/lib/dominio/regras";

/** Selo de situação: ponto + rótulo. A cor reforça, o texto é que informa. */
export function Selo({ tom, children }: { tom: Tom; children: React.ReactNode }) {
  return <span className={`situacao tom-${tom}`}>{children}</span>;
}
