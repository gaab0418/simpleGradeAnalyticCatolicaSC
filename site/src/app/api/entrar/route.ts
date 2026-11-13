import { cookies } from "next/headers";
import { baixarBoletim, respostaDeErro, SEM_CACHE } from "@/lib/servidor/boletim";
import { campoTexto, dentroDoLimite, lerCorpo, mesmaOrigem } from "@/lib/servidor/protecao";
import { COOKIE_SESSAO, VALIDADE_SEGUNDOS, opcoesCookie, selar } from "@/lib/servidor/sessao";

export const maxDuration = 60;

export async function POST(req: Request) {
  if (!mesmaOrigem(req)) {
    return Response.json({ erro: "Origem não permitida." }, { status: 403, headers: SEM_CACHE });
  }
  if (!dentroDoLimite(req)) {
    return Response.json(
      { erro: "Muitas tentativas. Espere alguns minutos e tente de novo.", tipo: "limite" },
      { status: 429, headers: SEM_CACHE },
    );
  }
  const corpo = await lerCorpo(req);
  const usuario = campoTexto(corpo?.usuario)?.trim();
  const senha = campoTexto(corpo?.senha);
  if (!usuario || !senha) {
    return Response.json({ erro: "Informe usuário e senha." }, { status: 400, headers: SEM_CACHE });
  }

  try {
    const dados = await baixarBoletim({ usuario, senha });
    const selo = corpo?.lembrar === true ? selar({ usuario, senha }) : null;
    const jar = await cookies();
    if (selo) jar.set(COOKIE_SESSAO, selo, { ...opcoesCookie, maxAge: VALIDADE_SEGUNDOS });
    else jar.delete({ name: COOKIE_SESSAO, ...opcoesCookie });
    return Response.json({ ...dados, lembrado: selo !== null }, { headers: SEM_CACHE });
  } catch (e) {
    return respostaDeErro(e);
  }
}
