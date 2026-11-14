/** Defesas das rotas de API: origem, tamanho da entrada e limite de tentativas. */
import "server-only";

/**
 * Só aceita chamadas feitas pela própria página (bloqueia CSRF e o uso do
 * site como proxy por outros sites). Navegadores sempre enviam Origin em POST.
 */
export function mesmaOrigem(req: Request): boolean {
  const secFetchSite = req.headers.get("sec-fetch-site");
  if (secFetchSite && secFetchSite !== "same-origin") return false;

  const origem = req.headers.get("origin");
  const hostBruto = req.headers.get("x-forwarded-host") ?? req.headers.get("host");
  const host = hostBruto?.split(",")[0]?.trim();
  if (!origem || !host) return false;
  try {
    const url = new URL(origem);
    const local = url.hostname === "localhost" || url.hostname === "127.0.0.1";
    if (process.env.NODE_ENV === "production" && !local && url.protocol !== "https:") {
      return false;
    }
    return url.host === host;
  } catch {
    return false;
  }
}

const JANELA_MS = 5 * 60_000;
const MAX_TENTATIVAS = 8;
const MAX_CHAVES = 5000;
const tentativas = new Map<string, number[]>();

function evictarSeCheio(agora: number) {
  for (const [k, arr] of tentativas) {
    const ultimo = arr.at(-1);
    if (ultimo === undefined || agora - ultimo >= JANELA_MS) {
      tentativas.delete(k);
    }
  }
  if (tentativas.size < MAX_CHAVES) return;

  // Evicta primeiro entradas não bloqueadas para que IPs forjados não apaguem bloqueios ativos.
  for (const [k, arr] of tentativas) {
    if (arr.length < MAX_TENTATIVAS) {
      tentativas.delete(k);
      if (tentativas.size < MAX_CHAVES) return;
    }
  }
  const maisAntiga = tentativas.keys().next().value;
  if (maisAntiga !== undefined) tentativas.delete(maisAntiga);
}

function consumirCota(chave: string, agora: number): boolean {
  const recentes = (tentativas.get(chave) ?? []).filter((t) => agora - t < JANELA_MS);
  tentativas.delete(chave);
  if (recentes.length >= MAX_TENTATIVAS) {
    tentativas.set(chave, recentes);
    return false;
  }
  if (tentativas.size >= MAX_CHAVES) evictarSeCheio(agora);
  recentes.push(agora);
  tentativas.set(chave, recentes);
  return true;
}

/**
 * Freio contra força bruta de senha através do site. É por instância (memória
 * do processo): em serverless reduz o abuso, não o elimina. O bloqueio de
 * verdade contra tentativas repetidas é o do próprio portal.
 */
export function dentroDoLimite(req: Request, agora = Date.now(), chaveExtra?: string): boolean {
  const realIp = req.headers.get("x-real-ip")?.trim();
  const xff = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const ip = (realIp || xff || "desconhecido").slice(0, 64);

  if (!consumirCota(`ip:${ip}`, agora)) return false;
  if (chaveExtra) {
    const norm = chaveExtra.trim().toLowerCase().slice(0, 64);
    if (norm && !consumirCota(`usr:${norm}`, agora)) return false;
  }
  return true;
}

export function dentroDoLimiteConta(usuario: string, agora = Date.now()): boolean {
  const norm = usuario.trim().toLowerCase().slice(0, 64);
  if (!norm) return true;
  return consumirCota(`usr:${norm}`, agora);
}

export function limparTentativas() {
  tentativas.clear();
}

/** Lê um JSON pequeno com limite real de bytes no stream; `null` se inválido ou maior que `maxBytes`. */
export async function lerCorpo(req: Request, maxBytes = 4096): Promise<Record<string, unknown> | null> {
  try {
    const contentLength = req.headers.get("content-length");
    if (contentLength !== null) {
      const declarado = Number(contentLength);
      if (Number.isFinite(declarado) && declarado > maxBytes) return null;
    }
    if (!req.body) return {};
    const reader = req.body.getReader();
    const chunks: Uint8Array[] = [];
    let totalBytes = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel().catch(() => {});
        return null;
      }
      chunks.push(value);
    }
    if (totalBytes === 0) return {};
    const buffer = new Uint8Array(totalBytes);
    let offset = 0;
    for (const chunk of chunks) {
      buffer.set(chunk, offset);
      offset += chunk.byteLength;
    }
    const texto = new TextDecoder("utf-8", { fatal: true }).decode(buffer);
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
