import { cookies } from "next/headers";
import { baixarBoletim, respostaDeErro, SEM_CACHE } from "@/lib/servidor/boletim";
import { dentroDoLimite, lerCorpo, mesmaOrigem } from "@/lib/servidor/protecao";
import { COOKIE_SESSAO, abrir, opcoesCookie } from "@/lib/servidor/sessao";
import { ErroPortal } from "@/lib/servidor/totvs";

export const maxDuration = 60;

/** Atualiza usando o cookie de sessão; `pular` lista semestres já encerrados no cache. */
export async function POST(req: Request) {
  if (!mesmaOrigem(req)) {
    return Response.json({ erro: "Origem não permitida." }, { status: 403, headers: SEM_CACHE });
  }
  if (!dentroDoLimite(req)) {
    return Response.json(
      { erro: "Muitas atualizações seguidas. Espere alguns minutos.", tipo: "limite" },
      { status: 429, headers: SEM_CACHE },
    );
  }
  const jar = await cookies();
  const credenciais = abrir(jar.get(COOKIE_SESSAO)?.value);
  if (!credenciais) {
    return Response.json(
      { erro: "Sua sessão expirou. Entre de novo.", tipo: "credenciais" },
      { status: 401, headers: SEM_CACHE },
    );
  }
  const corpo = await lerCorpo(req);
  const pular = new Set(
    Array.isArray(corpo?.pular)
      ? corpo.pular.filter((p): p is string => typeof p === "string").slice(0, 40)
      : [],
  );

  try {
    return Response.json(await baixarBoletim(credenciais, pular), { headers: SEM_CACHE });
  } catch (e) {
    // Senha trocada no portal: o cookie não serve mais.
    if (e instanceof ErroPortal && e.tipo === "credenciais") {
      jar.delete({ name: COOKIE_SESSAO, ...opcoesCookie });
    }
    return respostaDeErro(e);
  }
}
