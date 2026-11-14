import { cookies } from "next/headers";
import { baixarBoletim, respostaDeErro, SEM_CACHE } from "@/lib/servidor/boletim";
import {
  campoTexto,
  dentroDoLimite,
  dentroDoLimiteConta,
  extrairPular,
  lerCorpo,
  mesmaOrigem,
} from "@/lib/servidor/protecao";
import { COOKIE_SESSAO, abrir, opcoesCookie } from "@/lib/servidor/sessao";
import { ErroPortal } from "@/lib/servidor/totvs";

export const maxDuration = 60;

/** Atualiza usando o cookie de sessão ou credenciais da sessão ativa; `pular` lista semestres já encerrados no cache. */
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
  const corpo = await lerCorpo(req);
  let credenciais = abrir(jar.get(COOKIE_SESSAO)?.value);
  if (!credenciais) {
    const usuario = campoTexto(corpo?.usuario)?.trim();
    const senha = campoTexto(corpo?.senha);
    if (usuario && senha) {
      if (!dentroDoLimiteConta(usuario)) {
        return Response.json(
          { erro: "Muitas tentativas para esta conta. Espere alguns minutos e tente de novo.", tipo: "limite" },
          { status: 429, headers: SEM_CACHE },
        );
      }
      credenciais = { usuario, senha };
    }
  }
  if (!credenciais) {
    return Response.json(
      { erro: "Sua sessão expirou. Entre de novo.", tipo: "credenciais" },
      { status: 401, headers: SEM_CACHE },
    );
  }
  const pular = extrairPular(corpo);

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
