import { cookies } from "next/headers";
import { SEM_CACHE } from "@/lib/servidor/boletim";
import { mesmaOrigem } from "@/lib/servidor/protecao";
import { COOKIE_SESSAO, opcoesCookie } from "@/lib/servidor/sessao";

export async function POST(req: Request) {
  if (!mesmaOrigem(req)) {
    return Response.json({ erro: "Origem não permitida." }, { status: 403, headers: SEM_CACHE });
  }
  (await cookies()).delete({ name: COOKIE_SESSAO, ...opcoesCookie });
  return Response.json({ ok: true }, { headers: SEM_CACHE });
}
