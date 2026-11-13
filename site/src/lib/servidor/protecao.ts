/** Defesas das rotas de API: origem, tamanho da entrada e limite de tentativas. */
import "server-only";

/**
 * Só aceita chamadas feitas pela própria página (bloqueia CSRF e o uso do
 * site como proxy por outros sites). Navegadores sempre enviam Origin em POST.
 */
export function mesmaOrigem(req: Request): boolean {
  const origem = req.headers.get("origin");
  const host = req.headers.get("x-forwarded-host") ?? req.headers.get("host");
  if (!origem || !host) return false;
  try {
    return new URL(origem).host === host;
  } catch {
    return false;
  }
}

const JANELA_MS = 5 * 60_000;
const MAX_TENTATIVAS = 8;
const tentativas = new Map<string, number[]>();

/**
 * Freio contra força bruta de senha através do site. É por instância (memória
 * do processo): em serverless reduz o abuso, não o elimina. O bloqueio de
 * verdade contra tentativas repetidas é o do próprio portal.
 */
export function dentroDoLimite(req: Request, agora = Date.now()): boolean {
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "desconhecido";
  const recentes = (tentativas.get(ip) ?? []).filter((t) => agora - t < JANELA_MS);
  if (recentes.length >= MAX_TENTATIVAS) {
    tentativas.set(ip, recentes);
    return false;
  }
  recentes.push(agora);
  tentativas.set(ip, recentes);
  if (tentativas.size > 5000) tentativas.clear();
  return true;
}

/** Lê um JSON pequeno; `null` se não for objeto ou passar do tamanho. */
export async function lerCorpo(req: Request, maxBytes = 4096): Promise<Record<string, unknown> | null> {
  try {
    const texto = await req.text();
    if (texto.length > maxBytes) return null;
    const json: unknown = texto === "" ? {} : JSON.parse(texto);
    return typeof json === "object" && json !== null && !Array.isArray(json)
      ? (json as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

export const campoTexto = (v: unknown, max = 200): string | null =>
  typeof v === "string" && v.length > 0 && v.length <= max ? v : null;
