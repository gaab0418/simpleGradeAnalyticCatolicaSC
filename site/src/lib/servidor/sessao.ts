/**
 * "Manter conectado": as credenciais ficam num cookie cifrado (AES-256-GCM)
 * com uma chave que só o servidor tem. O cookie é HttpOnly, então nenhum
 * JavaScript da página (nem um XSS) consegue ler a senha; e o servidor não
 * guarda nada: sem o cookie do navegador ele não tem credencial nenhuma.
 */
import "server-only";
import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";

export const COOKIE_SESSAO = "boletim_sessao";
export const VALIDADE_SEGUNDOS = 60 * 60 * 24 * 30;

export interface Credenciais {
  usuario: string;
  senha: string;
}

function chave(): Buffer | null {
  const segredo = process.env.SESSAO_SEGREDO;
  // Segredo curto = chave fraca; melhor recusar do que fingir segurança.
  if (!segredo || segredo.length < 32) return null;
  return createHash("sha256").update(segredo).digest();
}

/** Sem `SESSAO_SEGREDO` configurado o site funciona, mas não mantém login. */
export const podeLembrar = () => chave() !== null;

export function selar(c: Credenciais, agora = Date.now()): string | null {
  const k = chave();
  if (!k) return null;
  const iv = randomBytes(12);
  const cifra = createCipheriv("aes-256-gcm", k, iv);
  const claro = JSON.stringify({ u: c.usuario, s: c.senha, exp: agora + VALIDADE_SEGUNDOS * 1000 });
  const corpo = Buffer.concat([cifra.update(claro, "utf8"), cifra.final()]);
  return Buffer.concat([iv, cifra.getAuthTag(), corpo]).toString("base64url");
}

export function abrir(valor: string | undefined, agora = Date.now()): Credenciais | null {
  const k = chave();
  if (!k || !valor) return null;
  try {
    const bruto = Buffer.from(valor, "base64url");
    const decifra = createDecipheriv("aes-256-gcm", k, bruto.subarray(0, 12));
    decifra.setAuthTag(bruto.subarray(12, 28));
    const claro = Buffer.concat([decifra.update(bruto.subarray(28)), decifra.final()]);
    const { u, s, exp } = JSON.parse(claro.toString("utf8"));
    if (typeof u !== "string" || typeof s !== "string" || typeof exp !== "number") return null;
    return exp > agora ? { usuario: u, senha: s } : null;
  } catch {
    // adulterado, de outra chave ou corrompido
    return null;
  }
}

export const opcoesCookie = {
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "strict",
  // Só as rotas de API recebem o cookie; páginas e assets nunca.
  path: "/api",
} as const;
