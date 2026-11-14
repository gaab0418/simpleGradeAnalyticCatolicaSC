// Fluxo real de login contra um portal falso em localhost (cookies, token em
// base64, redirecionamento, troca de período) e a cifra do cookie de sessão.
import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { analisar } from "@/lib/dominio/regras";
import {
  dentroDoLimite,
  dentroDoLimiteConta,
  extrairPular,
  lerCorpo,
  limparTentativas,
  mesmaOrigem,
} from "@/lib/servidor/protecao";
import { abrir, podeLembrar, selar } from "@/lib/servidor/sessao";
import { ErroPortal, SessaoPortal, extrairNota4, montarDisciplinas, parseNota } from "@/lib/servidor/totvs";

const USUARIO = "aluno";
const SENHA = 's3nh@ "com" espaço';
const CTX_LOGIN = '{"ctx":"inicial"}';

let servidor: Server;
let base: string;
let pedidos: string[] = [];
let falharNotas = false;

function cookies(req: IncomingMessage): Record<string, string> {
  return Object.fromEntries(
    (req.headers.cookie ?? "")
      .split("; ")
      .filter((p) => p.includes("="))
      .map((p) => [p.slice(0, p.indexOf("=")), p.slice(p.indexOf("=") + 1)]),
  );
}
const json = (res: ServerResponse, corpo: unknown, status = 200) => {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(corpo));
};

beforeAll(async () => {
  servidor = createServer(async (req, res) => {
    const url = new URL(req.url!, "http://x");
    const rota = url.pathname.split("/").pop();
    pedidos.push(`${req.method} ${url.pathname}`);
    const ck = cookies(req);
    const logado = ck.SESSAO === "abc" && ck.AUTO === "ok";

    if (rota === "") {
      res.writeHead(200, { "set-cookie": "SESSAO=abc; Path=/; HttpOnly" });
      return res.end();
    }
    if (rota === "Login") {
      let bruto = "";
      for await (const parte of req) bruto += parte;
      const corpo = JSON.parse(bruto);
      if (ck.SESSAO !== "abc" || corpo.user !== USUARIO || corpo.password !== SENHA) {
        return json(res, { messages: "inválido" }, 401);
      }
      return json(res, {
        data: { value: encodeURIComponent(Buffer.from(CTX_LOGIN).toString("base64")) },
      });
    }
    if (rota === "AutoLoginPortal") {
      const chave = url.searchParams.get("key") ?? "";
      const ok =
        Buffer.from(chave, "base64").toString() === CTX_LOGIN &&
        ck.EduContextoAlunoResponsavelAPI === CTX_LOGIN;
      // Redireciona para provar que cookies de saltos intermediários são mantidos.
      res.writeHead(302, {
        location: "/FrameHTML/RM/API/user/Fim",
        "set-cookie": `AUTO=${ok ? "ok" : "falhou"}`,
      });
      return res.end();
    }
    if (rota === "Fim") return json(res, {});
    if (rota === "Contexto") {
      if (!logado) return json(res, {}, 401);
      const ctx = (id: string, cod: number) => ({
        IDCONTEXTOALUNO: id,
        CODPERLET: cod,
        NOMECURSO: "ENG. DE SOFTWARE",
        NOMEALUNO: "FULANO DE TAL",
        RA: "123",
      });
      return json(res, { data: [ctx("CTX-2", 202623), ctx("CTX-1", 202611)] });
    }
    if (rota === "NotaEtapa") {
      if (!logado) return json(res, {}, 401);
      if (falharNotas) {
        res.writeHead(500, { "content-type": "text/html" });
        return res.end("<html>erro</html>");
      }
      const atual = ck.EduContextoAlunoResponsavelAPI === "CTX-2";
      return json(res, {
        data: {
          Notas: [
            {
              IDTURMADISC: atual ? 2 : 1,
              CODTURMA: "T",
              CODDISC: "D",
              DISCIPLINA: atual ? "COMPILADORES - CMP" : "REDES - RED",
              SITUACAO: atual ? "Matriculado" : "Aprovado",
              "1 - Nota 1": atual ? "<font color=red>3,5</font>" : "8,0",
              "2 - Nota 2": atual ? null : "7,0",
              "3 - Nota 3": atual ? null : "9,0",
              "6 - Média Final": atual ? null : "8,0",
            },
          ],
        },
      });
    }
    if (rota === "FaltaEtapa") {
      return json(res, {
        data: { FaltasEtapa: [{ IDTURMADISC: 2, "1 - Faltas Sala de Aula": "12" }] },
      });
    }
    res.writeHead(404);
    res.end();
  });
  await new Promise<void>((ok) => servidor.listen(0, "127.0.0.1", ok));
  base = `http://127.0.0.1:${(servidor.address() as AddressInfo).port}`;
});
afterAll(() => servidor.close());
beforeEach(() => {
  pedidos = [];
  falharNotas = false;
});

describe("cliente do portal", () => {
  it("login completo e leitura de dois períodos", async () => {
    const s = await SessaoPortal.entrar(USUARIO, SENHA, { base });
    expect(s.aluno.nome).toBe("FULANO DE TAL");
    expect(s.contextos.map((c) => c.codigo)).toEqual(["202623", "202611"]);

    const [atual] = await s.disciplinas(s.contextos[0]);
    expect(atual.nome).toBe("COMPILADORES - CMP");
    expect(atual.notas).toEqual([3.5, null, null]);
    expect(atual.faltas).toBe(12);

    const [antigo] = await s.disciplinas(s.contextos[1]);
    expect(antigo.nome).toBe("REDES - RED");
    expect(antigo.mediaFinal).toBe(8);
    expect(antigo.faltas).toBe(0);
  });

  it("senha errada vira erro de credenciais e para no login", async () => {
    await expect(SessaoPortal.entrar(USUARIO, "errada", { base })).rejects.toMatchObject({
      tipo: "credenciais",
    });
    expect(pedidos.some((p) => p.includes("Contexto"))).toBe(false);
  });

  it("erro 500 com HTML vira erro do portal", async () => {
    const s = await SessaoPortal.entrar(USUARIO, SENHA, { base });
    falharNotas = true;
    await expect(s.disciplinas(s.contextos[0])).rejects.toBeInstanceOf(ErroPortal);
  });

  it("portal inalcançável vira erro de rede", async () => {
    await expect(
      SessaoPortal.entrar(USUARIO, SENHA, { base: "http://127.0.0.1:1" }),
    ).rejects.toMatchObject({ tipo: "rede" });
  });

  it("recusa redirecionamento para outro host", async () => {
    const falso: typeof fetch = async () =>
      new Response(null, { status: 302, headers: { location: "https://malicioso.example/x" } });
    await expect(
      SessaoPortal.entrar(USUARIO, SENHA, { base, fetch: falso }),
    ).rejects.toMatchObject({ tipo: "portal" });
  });

  it("rejeita cookie injetado no token de login", async () => {
    const falso: typeof fetch = async (input) => {
      const u = String(input);
      if (u.endsWith("/Login")) {
        const token = encodeURIComponent(Buffer.from("ok; ADMIN=1\r\nX-Test: 1").toString("base64"));
        return new Response(JSON.stringify({ data: { value: token } }), { status: 200 });
      }
      return new Response(null, { status: 200 });
    };
    await expect(
      SessaoPortal.entrar(USUARIO, SENHA, { base, fetch: falso }),
    ).rejects.toMatchObject({ tipo: "portal" });
  });

  it("ignora Set-Cookie inválido e rejeita resposta maior que 2 MB", async () => {
    let cookiesEnviados = "";
    const falso: typeof fetch = async (input, init) => {
      const u = String(input);
      if (u.endsWith("/PortalEducacional/")) {
        const resp = new Response("", { status: 200 });
        Object.defineProperty(resp.headers, "getSetCookie", {
          value: () => ["SESSAO=abc; Path=/", "bad name=1; Path=/", "INJ=x\r\nEvil: 1"],
        });
        return resp;
      }
      if (u.endsWith("/Login")) {
        cookiesEnviados = (init?.headers as Record<string, string>)?.cookie ?? "";
        return new Response("x".repeat(2 * 1024 * 1024 + 16), { status: 200 });
      }
      return new Response("{}", { status: 200 });
    };
    await expect(
      SessaoPortal.entrar(USUARIO, SENHA, { base, fetch: falso }),
    ).rejects.toMatchObject({ tipo: "portal" });
    expect(cookiesEnviados).toContain("SESSAO=abc");
    expect(cookiesEnviados).not.toContain("bad name");
    expect(cookiesEnviados).not.toContain("INJ=");
  });

  it("nota embrulhada em HTML e com vírgula", () => {
    expect(parseNota("<font color=red>3,3</font>")).toBe(3.3);
    expect(parseNota("")).toBeNull();
    expect(parseNota(null)).toBeNull();
  });

  it("extrai N4 de 4 - Nota 4 ou coluna 4 alternativa, ignorando 4 - Média Final", () => {
    expect(extrairNota4({ "4 - Nota 4": "<font color=red>5,5</font>" })).toBe(5.5);
    expect(extrairNota4({ "4 - Substitutiva": "7,0" })).toBe(7);
    expect(extrairNota4({ "4 - Média Final": "8,0" })).toBeNull();
    expect(extrairNota4({ "4 - Nota 4": null, "4 - Média Final": "8,0" })).toBeNull();

    const [d] = montarDisciplinas(
      [
        {
          IDTURMADISC: 10,
          CODTURMA: "T1",
          CODDISC: "PES",
          DISCIPLINA: "PROBABILIDADE - PES",
          SITUACAO: "Aprovado",
          "1 - Nota 1": "<font color=red>3,5</font>",
          "2 - Nota 2": "6,8",
          "3 - Nota 3": "7,0",
          "4 - Nota 4": "5,5",
          "6 - Média Final": "6,4",
        },
      ],
      [],
    );
    expect(d.notas).toEqual([3.5, 6.8, 7]);
    expect(d.nota4).toBe(5.5);
    expect(d.mediaFinal).toBe(6.4);

    const [pss] = montarDisciplinas(
      [
        {
          IDTURMADISC: 11,
          CODTURMA: "ESW-N",
          CODDISC: "PSS",
          DISCIPLINA: "PROGRAMAÇÃO SERVER-SIDE - PSS",
          SITUACAO: "Aprovado",
          "1 - Nota 1": "7,3",
          "2 - Nota 2": "6,0",
          "3 - Nota 3": "7,0",
          "4 - Nota Substitutiva": "8,4",
          "6 - Média Final": "7,6",
        },
      ],
      [],
    );
    expect(pss.nota4).toBe(8.4);
    const analisePss = analisar(pss);
    expect(analisePss.notasEfetivas).toEqual([7.3, 8.4, 7]);
    expect(analisePss.indiceSubstituido).toBe(1);
    expect(analisePss.notaSubstituida).toBe(6);
    expect(analisePss.soma).toBeCloseTo(22.7, 5);
    expect(analisePss.media).toBe(7.6);
    expect(analisePss.situacao.id).toBe("aprovada");
  });
});

describe("cookie de sessão", () => {
  const c = { usuario: "aluno", senha: "segredo" };

  it("sem segredo configurado não mantém login", () => {
    delete process.env.SESSAO_SEGREDO;
    expect(podeLembrar()).toBe(false);
    expect(selar(c)).toBeNull();
    process.env.SESSAO_SEGREDO = "curto";
    expect(podeLembrar()).toBe(false);
  });

  it("cifra com HKDF+AAD, expira em 7 dias e rejeita adulteração", () => {
    process.env.SESSAO_SEGREDO = "a".repeat(48);
    const selo = selar(c, 1000)!;
    expect(selo).not.toContain("segredo");
    expect(abrir(selo, 2000)).toEqual(c);
    expect(abrir(selo, 1000 + 6 * 86_400_000)).toEqual(c);
    expect(abrir(selo, 1000 + 8 * 86_400_000)).toBeNull();
    const adulterado = selo.slice(0, -2) + (selo.endsWith("A") ? "B" : "A") + selo.slice(-1);
    expect(abrir(adulterado, 2000)).toBeNull();
    // Dois selos da mesma senha são diferentes (IV aleatório).
    expect(selar(c, 1000)).not.toBe(selo);

    process.env.SESSAO_SEGREDO = "b".repeat(48);
    expect(abrir(selo, 2000)).toBeNull();
  });
});

describe("proteções das rotas", () => {
  beforeEach(() => limparTentativas());

  const req = (headers: Record<string, string>) =>
    new Request("http://site.test/api/entrar", { method: "POST", headers });

  it("só aceita a própria origem e bloqueia Sec-Fetch-Site externo", () => {
    expect(mesmaOrigem(req({ origin: "https://site.test", host: "site.test" }))).toBe(true);
    expect(
      mesmaOrigem(
        req({
          origin: "https://site.test",
          "x-forwarded-host": "site.test, proxy.internal",
          "sec-fetch-site": "same-origin",
        }),
      ),
    ).toBe(true);
    expect(
      mesmaOrigem(
        req({
          origin: "https://site.test",
          host: "site.test",
          "sec-fetch-site": "cross-site",
        }),
      ),
    ).toBe(false);
    expect(mesmaOrigem(req({ origin: "https://outro.test", host: "site.test" }))).toBe(false);
    expect(mesmaOrigem(req({ host: "site.test" }))).toBe(false);
    expect(mesmaOrigem(req({ origin: "http://localhost:3000", host: "localhost:3000" }))).toBe(true);

    vi.stubEnv("NODE_ENV", "production");
    try {
      expect(mesmaOrigem(req({ origin: "http://localhost:3000", host: "localhost:3000" }))).toBe(
        true,
      );
      expect(mesmaOrigem(req({ origin: "http://127.0.0.1:3000", host: "127.0.0.1:3000" }))).toBe(
        true,
      );
      expect(mesmaOrigem(req({ origin: "http://site.test", host: "site.test" }))).toBe(false);
    } finally {
      vi.unstubAllEnvs();
    }
  });

  it("limita tentativas por IP e não reseta bloqueios com 5000 IPs forjados", () => {
    const r = req({ "x-forwarded-for": "203.0.113.9" });
    for (let i = 0; i < 8; i++) expect(dentroDoLimite(r, 1000)).toBe(true);
    expect(dentroDoLimite(r, 1000)).toBe(false);

    for (let i = 0; i < 5005; i++) {
      dentroDoLimite(req({ "x-forwarded-for": `198.51.${Math.floor(i / 256)}.${i % 256}` }), 1001);
    }
    expect(dentroDoLimite(r, 1002)).toBe(false);
    expect(dentroDoLimite(r, 1000 + 6 * 60_000)).toBe(true);
  });

  it("limita força bruta distribuída por conta", () => {
    for (let i = 0; i < 8; i++) expect(dentroDoLimiteConta("Aluno.Teste", 1000)).toBe(true);
    expect(dentroDoLimiteConta("aluno.teste", 1000)).toBe(false);
    expect(dentroDoLimiteConta("aluno.teste", 1000 + 6 * 60_000)).toBe(true);
  });

  it("rejeita payloads maiores que maxBytes no stream sem ler tudo", async () => {
    const grande = new Request("http://site.test/api/entrar", {
      method: "POST",
      body: JSON.stringify({ usuario: "a".repeat(5000) }),
    });
    expect(await lerCorpo(grande, 4096)).toBeNull();

    let chunksLidos = 0;
    const stream = new ReadableStream<Uint8Array>({
      pull(ctrl) {
        chunksLidos++;
        ctrl.enqueue(new Uint8Array(1500).fill(97));
        if (chunksLidos >= 10) ctrl.close();
      },
    });
    const reqStream = new Request("http://site.test/api/entrar", {
      method: "POST",
      body: stream,
      duplex: "half",
    } as RequestInit);
    expect(await lerCorpo(reqStream, 4096)).toBeNull();
    expect(chunksLidos).toBeLessThan(5);

    const valido = new Request("http://site.test/api/entrar", {
      method: "POST",
      body: JSON.stringify({ usuario: "aluno" }),
    });
    expect(await lerCorpo(valido, 4096)).toEqual({ usuario: "aluno" });
  });

  it("extrairPular valida formato, tamanho e limite de 40 períodos", () => {
    expect([...extrairPular(null)]).toEqual([]);
    expect([...extrairPular({ pular: "202511" })]).toEqual([]);
    expect([
      ...extrairPular({
        pular: [
          "202511",
          "2025-2_A",
          "../invalido",
          "muito-longo-demais-12345",
          123,
          null,
        ],
      }),
    ]).toEqual(["202511", "2025-2_A"]);

    const muitos = Array.from({ length: 50 }, (_, i) => `2025${String(i).padStart(2, "0")}`);
    expect(extrairPular({ pular: muitos }).size).toBe(40);
  });
});
