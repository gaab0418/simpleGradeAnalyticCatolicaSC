# Arquitetura

## 1. Requisitos

**Funcionais**
- Entrar com usuário e senha do portal TOTVS RM e ver notas, faltas e a situação de cada matéria.
- Guardar o histórico de todos os semestres para análise de desempenho e uso offline.
- Manter o login no aparelho/navegador, com saída que apaga tudo.

**Não funcionais**
- Custo zero de operação (Vercel gratuita, sem banco de dados).
- Qualquer aluno deve conseguir usar sem instalar nada (site) ou instalando um APK (app).
- A senha do portal é o dado mais sensível do sistema: minimizar onde ela passa e onde fica.

**Restrições**
- O portal não tem API pública nem envia cabeçalhos CORS. Verificado: um `OPTIONS` com
  `Origin` externo não devolve `Access-Control-Allow-Origin`.
- Um mantenedor, tempo livre.

## 2. Visão geral

```
            ┌────────────────────────── site/ (Vercel) ──────────────────────────┐
Navegador ──┤ página estática (React)  ──POST /api/*──▶  função serverless       ├──▶ Portal TOTVS RM
            │ localStorage: notas                        sem estado, sem banco   │
            │ cookie HttpOnly: senha cifrada             chave: SESSAO_SEGREDO   │
            └────────────────────────────────────────────────────────────────────┘

App Flutter (mobile/) ─────────────────── HTTPS direto ───────────────────────────▶ Portal TOTVS RM
  Keystore/Keychain: senha · armazenamento privado: notas
```

### Por que o site precisa de servidor (e o app não)

Um site "100% sem backend" não é possível aqui: sem CORS, o navegador bloqueia qualquer
chamada da página ao portal. O app nativo não tem essa restrição e fala direto com o portal.

O servidor do site é o mínimo necessário: três rotas que recebem a credencial, fazem o
login no portal, devolvem os dados e esquecem tudo. Não há banco, fila, cache nem log de
conteúdo.

| Alternativa | Por que não |
|---|---|
| Página estática chamando o portal | Bloqueada pelo navegador (sem CORS) |
| Proxy CORS público de terceiros | Entrega a senha de todo mundo a um desconhecido |
| Servidor com banco e contas próprias | Passa a existir um lugar onde senhas e notas ficam guardadas |
| Extensão de navegador | Evita o servidor, mas exige instalar e não funciona no celular |

## 3. Site (`site/`)

### Rotas

| Rota | Entrada | Faz |
|---|---|---|
| `POST /api/entrar` | `{usuario, senha, lembrar}` | Login no portal, baixa todos os semestres. Com `lembrar`, devolve o cookie de sessão. |
| `POST /api/sincronizar` | `{pular: [códigos]}` + cookie | Refaz o login com o cookie e baixa só os semestres não listados em `pular`. |
| `POST /api/sair` | cookie | Apaga o cookie. |

Semestres encerrados não mudam mais no portal; o navegador os envia em `pular`, e uma
atualização normal consulta só o semestre em andamento.

### Onde cada dado fica

| Dado | Onde | Por quê |
|---|---|---|
| Senha (com "Manter conectado") | Cookie `HttpOnly; Secure; SameSite=Strict; Path=/api`, cifrado com AES-256-GCM | JavaScript da página não lê (XSS não rouba a senha); o servidor não guarda nada |
| Senha (sem "Manter conectado") | Em lugar nenhum | Só existe durante a requisição de login |
| Notas e faltas | `localStorage` (ou `sessionStorage` sem "Manter conectado") | Abre rápido, funciona offline, o servidor não vê depois de entregar |
| Tema | `localStorage` | Preferência |

A chave do cookie é `SESSAO_SEGREDO` (variável de ambiente, mínimo 32 caracteres). Sem ela
o site funciona, mas não oferece manter o login — melhor recusar do que cifrar com chave fraca.

### Defesas

- **Host fixo do portal** e redirecionamento seguido manualmente: se o portal redirecionar
  para outro domínio a requisição é abortada, então a credencial nunca sai do host configurado.
- **Origem**: as rotas só aceitam `Origin` igual ao próprio host (bloqueia CSRF e o uso do
  site como proxy por outras páginas).
- **Limite de tentativas** por IP (8 a cada 5 minutos). É por instância serverless: reduz
  abuso, não elimina. O bloqueio real contra força bruta é o do próprio portal.
- **Cabeçalhos**: CSP restrita à própria origem, `frame-ancestors 'none'`, `no-referrer`,
  `no-store` em todas as respostas de API.
- **Sem terceiros**: nenhuma fonte, script, analytics ou imagem de fora.

### Limites que continuam existindo

- **Quem hospeda o site pode ver senhas.** Não há como impedir tecnicamente: o servidor
  recebe a senha em claro para repassar ao portal, e quem faz o deploy controla o código.
  O usuário precisa confiar no mantenedor. O site diz isso na tela de entrada.
- **O cookie cifrado é tão seguro quanto `SESSAO_SEGREDO`.** Se a chave vazar junto com um
  cookie, a senha é recuperável. Trocar a chave invalida todas as sessões.
- **O IP que o portal vê é o da Vercel.** O portal pode bloquear ou limitar esse IP; muitos
  alunos usando ao mesmo tempo parecem um único cliente fazendo muitos logins.
- **CSP com `'unsafe-inline'` em scripts**, exigido pela hidratação do Next sem nonce.

## 4. App (`mobile/`)

- Fala direto com o portal; a senha fica no Keystore/Keychain (`flutter_secure_storage`).
- Notas em armazenamento privado do app, fora de backup; trava biométrica opcional.
- Mesma sincronização incremental do site.

Detalhes em [`mobile/README.md`](../mobile/README.md).

## 5. Regras duplicadas

As regras acadêmicas existem duas vezes: `site/src/lib/dominio/` (TypeScript) e
`mobile/lib/domain/` (Dart). Compartilhar exigiria compilar Dart para JS ou embutir um
motor JS no app — mais complexidade do que ~300 linhas de regra justificam. A mitigação é
ter os mesmos casos de teste dos dois lados e os parâmetros (média, limite de faltas)
isolados em `site/src/lib/config.ts` e no topo de `mobile/lib/domain/regras.dart`.

## 6. Escala e operação

Carga esperada: dezenas a poucas centenas de alunos, picos em semana de prova. Cada login
custa 4 requisições ao portal mais 2 por semestre consultado; uma atualização normal são 6.
O plano gratuito da Vercel comporta isso com folga. `maxDuration` das rotas é 60 s, porque
a primeira carga de um aluno com muitos semestres é sequencial (o período é selecionado por
cookie na sessão do portal).

Região da função: `gru1` (São Paulo), para ficar perto do portal.

## 7. O que rever se crescer

- Limite de tentativas compartilhado entre instâncias (Vercel KV/Upstash) se houver abuso.
- CSP com nonce para tirar `'unsafe-inline'`.
- Se a Católica bloquear os IPs da Vercel, o site para; o app continua funcionando.
- Outras instituições com TOTVS RM: hoje basta `PORTAL_URL` e `config.ts`, mas os nomes
  das colunas de nota ("1 - Nota 1"…) variam por instituição e precisariam virar configuração.
