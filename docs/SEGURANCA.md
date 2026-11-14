# Análise de Segurança do Site (`site/`)

Este documento registra a análise de segurança realizada na aplicação web em Next.js (`site/`), as vulnerabilidades e pontos de endurecimento identificados, as correções aplicadas e os riscos residuais da arquitetura.

## 1. Superfície de Ataque e Arquitetura

O site atua como um BFF (*Backend for Frontend*) sem banco de dados:

1. **Cliente (Browser)**: armazena notas, histórico e preferências em `localStorage` (com "Manter conectado") ou `sessionStorage` (sessão temporária) e envia chamadas `POST` para `/api/entrar`, `/api/sincronizar` e `/api/sair`.
2. **Rotas Serverless (`/api/*`)**: recebem credenciais no login ou via cookie cifrado (`__Secure-boletim_sessao`), validam origem, tamanho do payload e taxa de requisições, e consultam o portal TOTVS RM.
3. **Cliente TOTVS (`totvs.ts` / `boletim.ts`)**: simula a navegação HTTP no portal da instituição sem repassar credenciais a outros domínios.

---

## 2. Vulnerabilidades e Fragilidades Identificadas (e Correções Aplicadas)

### 2.1. Bypass Global de Rate Limiting por Forjamento de IP (`protecao.ts`)
- **Problema**: `dentroDoLimite` executava `if (tentativas.size > 5000) tentativas.clear()`. Um atacante enviando 5.001 requisições com cabeçalhos `X-Forwarded-For` distintos forçava a limpeza total do mapa em memória, zerando contadores de IPs já bloqueados e viabilizando força bruta contínua. Além disso, a ausência de limite por usuário permitia ataques distribuídos contra uma mesma matrícula/RA usando múltiplos IPs.
- **Correção**:
  - Removido o `.clear()` global; adicionada remoção de entradas expiradas seguida de evicção seletiva (removendo primeiro entradas não bloqueadas).
  - Priorização do cabeçalho `x-real-ip` antes de `x-forwarded-for`, com truncamento em 64 caracteres.
  - Adicionado limite de tentativas também por conta (`dentroDoLimiteConta`, chave `usr:<usuario>`, máximo de 8 tentativas em 5 minutos).

### 2.2. Leitura de Corpo sem Limite Real de Stream (`protecao.ts`)
- **Problema**: `lerCorpo` invocava `await req.text()` antes de checar `texto.length > maxBytes`. Um atacante podia enviar um payload gigante (ou omitir/falsificar `Content-Length`) e forçar alocação integral em memória antes da rejeição, criando vetor de DoS em funções serverless.
- **Correção**:
  - Verificação antecipada de `Content-Length`.
  - Leitura incremental via `req.body.getReader()` contabilizando `byteLength` por chunk, cancelando imediatamente o stream (`reader.cancel()`) assim que `totalBytes > maxBytes`.
  - Decodificação estrita via `TextDecoder("utf-8", { fatal: true })`.

### 2.3. Endurecimento da Checagem de Origem / CSRF (`protecao.ts`)
- **Problema**: `mesmaOrigem` comparava apenas `new URL(origem).host === host` sem inspecionar `Sec-Fetch-Site`, sem validar protocolo HTTPS em produção e sem tratar múltiplos hosts em `x-forwarded-host` separados por vírgula.
- **Correção**:
  - Rejeição explícita quando `Sec-Fetch-Site` está presente e é diferente de `"same-origin"`.
  - Uso apenas do primeiro valor de `x-forwarded-host` (`split(",")[0].trim()`).
  - Exigência de `https:` na origem quando `NODE_ENV === "production"`.

### 2.4. Derivação de Chave, AAD, Prefixo e Janela do Cookie de Sessão (`sessao.ts`)
- **Problema**:
  - A chave AES-256-GCM era derivada com um único `SHA-256(SESSAO_SEGREDO)` sem KDF nem separação de contexto/domínio.
  - O cookie usava o nome simples `boletim_sessao` sem o prefixo `__Secure-`, ficando mais exposto a sobrescrita por subdomínios (*cookie tossing*).
  - O ciphertext não vinculava metadados com AAD (*Additional Authenticated Data*).
  - A validade de **30 dias** aumentava desnecessariamente a janela de exposição da credencial cifrada em caso de vazamento do cookie ou uso em dispositivo alheio.
- **Correção**:
  - Derivação da chave com **HKDF-SHA256** (`hkdfSync`) com salt e info dedicados.
  - Prefixo `__Secure-boletim_sessao` em produção.
  - Inclusão do nome do cookie como `AAD` na cifra e decifra AES-256-GCM.
  - Redução da validade do cookie para **7 dias** (`60 * 60 * 24 * 7`).

### 2.5. Sanitização, Limite de Resposta e Amplificação no Cliente TOTVS (`totvs.ts`, `boletim.ts`, `/api/sincronizar`)
- **Problema**:
  - `guardarCookies` e a montagem do cabeçalho `Cookie` não validavam nomes RFC nem caracteres de controle (`\r`, `\n`, `\0`, `;`) vindos do portal ou do token em base64, permitindo risco teórico de *Header/Cookie Injection*.
  - `resp.text()` lia respostas arbitrárias do portal sem limite de bytes.
  - Não havia verificação de protocolo `https:` no `PORTAL_URL` em produção nem teto para quantidade de períodos/contextos iterados em sequência (`baixarBoletim`).
  - `/api/sincronizar` aceitava strings arbitrárias no array `pular`.
- **Correção**:
  - Validação estrita de nomes de cookies e rejeição de caracteres proibidos (`[\r\n\x00-\x1f\x7f;]`) nos cookies recebidos, decodificados e enviados.
  - Leitura limitada a **2 MB** (`lerTextoLimitado`) nas respostas do portal.
  - Exigência de `https:` para o portal em produção.
  - Teto de `24` períodos e `4` contextos por período em `baixarBoletim`, e validação de `pular` com `/^[A-Za-z0-9_-]+$/` (máx. 20 caracteres).

### 2.6. Expiração dos Dados Locais e Logout (`loja.ts`)
- **Problema**: Mesmo após expirar o cookie de sessão, notas, nome completo e RA continuavam indefinidamente no `localStorage` de computadores compartilhados. Além disso, uma falha transitória em `POST /api/sair` podia deixar o cookie ativo após o usuário clicar em "Sair".
- **Correção**:
  - Adicionado timestamp `salvoEm` ao payload salvo localmente; registros sem data ou com mais de **7 dias** são apagados automaticamente na inicialização (`ler()`).
  - Tentativa de reenvio em `/api/sair` caso a primeira requisição falhe.

### 2.7. Cabeçalhos de Segurança HTTP (`next.config.ts`)
- **Problema**: Faltavam diretivas modernas de isolamento e transporte (`Strict-Transport-Security`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, `X-DNS-Prefetch-Control` e `upgrade-insecure-requests` na CSP).
- **Correção**: Todos os cabeçalhos acima adicionados em `next.config.ts`.

---

## 3. Riscos Residuais (Inerentes ao Modelo)

1. **Confiança no operador do servidor**: Como o portal TOTVS RM não envia cabeçalhos CORS para o navegador, o backend serverless do site precisa receber usuário e senha em texto claro durante o login/sincronização. Embora o servidor não grave nem registre nada, quem controla o deploy pode, em tese, alterar o código em execução.
2. **Estado por instância serverless**: O rate limit em memória (`protecao.ts`) mitiga abuso por instância na Vercel, mas não compartilha estado entre múltiplas instâncias simultâneas; para bloqueio global distribuído seria necessário um store externo (ex.: Redis/KV).
3. **CSP com `'unsafe-inline'` em `script-src`**: Necessário para a hidratação padrão do Next.js sem middleware dinâmico de *nonce* por requisição.
