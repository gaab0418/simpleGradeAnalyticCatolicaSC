# Site (Next.js)

Boletim no navegador. Página estática + três rotas serverless sem estado que repassam o
login ao portal. Não tem banco de dados.

```bash
npm install
cp .env.example .env.local   # e preencha SESSAO_SEGREDO
npm run dev                  # http://localhost:3000
npm test                     # regras, cliente do portal, cookie de sessão
npm run lint && npm run typecheck && npm run build
```

Na tela de entrada, "Ver uma demonstração sem conta" abre o site com dados fictícios.

## Publicar na Vercel

1. Importe o repositório e defina **Root Directory** como `site`.
2. Em *Environment Variables*, crie `SESSAO_SEGREDO` com o resultado de
   `openssl rand -base64 48`. Sem ela o site funciona, mas "Manter conectado" fica desligado.
3. Deploy. A região da função já está fixada em São Paulo (`vercel.json`).

| Variável | Obrigatória | Para quê |
|---|---|---|
| `SESSAO_SEGREDO` | para manter login | Chave que cifra o cookie de sessão (mínimo 32 caracteres) |
| `PORTAL_URL` | não | Outro portal TOTVS RM (padrão: Católica SC) |
| `NEXT_PUBLIC_INSTITUICAO` | não | Nome exibido no site |

Quem publica o site tem acesso técnico às senhas que passam por ele. Leia
[docs/ARQUITETURA.md](../docs/ARQUITETURA.md) antes de divulgar o link.

## Estrutura

```
src/
  app/            páginas, layout, estilos e as rotas /api
  componentes/    telas (Entrada, Boletim, Desempenho) e gráficos em SVG
  lib/
    config.ts     instituição e regras (média, limite de faltas)
    dominio/      regras puras: situação, resumo, desempenho, formatação
    servidor/     cliente do portal, cookie cifrado, proteções das rotas
    cliente/      estado e armazenamento no navegador
testes/
```

`lib/servidor/` importa `server-only`: se algum componente de navegador importar dali, o
build falha.
