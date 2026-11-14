import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center gap-1.5 whitespace-nowrap border text-[13px] font-semibold transition-colors",
  {
    variants: {
      variant: {
        default: "rounded-md border-transparent bg-primary text-primary-foreground px-2 py-0.5 text-xs",
        secondary: "rounded-md border-transparent bg-secondary text-secondary-foreground px-2 py-0.5 text-xs",
        outline: "rounded-md border-borda-forte bg-card text-foreground px-2 py-0.5 text-xs",
        ok: "rounded-[6px_11px_6px_11px] border-ok/25 bg-ok-fundo text-ok px-2.5 py-0.5",
        calmo: "rounded-[6px_11px_6px_11px] border-calmo/25 bg-calmo-fundo text-calmo px-2.5 py-0.5",
        atencao: "rounded-[6px_11px_6px_11px] border-atencao/25 bg-atencao-fundo text-atencao px-2.5 py-0.5",
        apertado: "rounded-[6px_11px_6px_11px] border-apertado/25 bg-apertado-fundo text-apertado px-2.5 py-0.5",
        critico: "rounded-[6px_11px_6px_11px] border-critico/25 bg-critico-fundo text-critico px-2.5 py-0.5",
        neutro: "rounded-[6px_11px_6px_11px] border-neutro/25 bg-neutro-fundo text-neutro px-2.5 py-0.5",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}

export { Badge, badgeVariants };
