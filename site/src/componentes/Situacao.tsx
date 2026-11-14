import { Badge } from "@/componentes/ui/badge";
import type { Tom } from "@/lib/dominio/regras";

/** Selo de situação: ponto + rótulo. A cor reforça, o texto é que informa. */
export function Selo({ tom, children }: { tom: Tom; children: React.ReactNode }) {
  return (
    <Badge variant={tom}>
      <span className="size-1.5 shrink-0 rounded-full bg-current" aria-hidden="true" />
      {children}
    </Badge>
  );
}
