# TOTVS RM Portal - Automatização de Notas & Faltas

Este projeto automatiza o fluxo de autenticação e consulta de notas/faltas do portal acadêmico TOTVS RM e disponibiliza uma interface web bonita (inspirada no tema escuro do Discord) para visualização.

## Estrutura do Projeto

*   `index.html`: A interface gráfica de usuário (frontend) que consome os dados do servidor local.
*   `server.py`: O servidor web local em Python que faz o login automático (usando suas credenciais), faz o cruzamento dos dados de notas/faltas, e entrega uma API limpa para o frontend.
*   `.env`: Arquivo local contendo as credenciais de acesso (`USUARIO` e `SENHA`).
*   `run.bat`: Arquivo executável para iniciar o servidor Python no Windows com apenas dois cliques.
*   `login.py`: Script original em modo texto (CLI) para depuração.

## Requisitos

Instale a biblioteca `requests` necessária para fazer as requisições HTTP:

```bash
pip install requests
```

## Como Usar

1.  Abra o arquivo `.env` e insira seu usuário e senha do RM Portal.
2.  Dê dois cliques no arquivo `run.bat` para iniciar o servidor.
3.  Abra o navegador em: **[http://localhost:8080](http://localhost:8080)**

---

## Recursos e Funcionalidades

### 1. Seleção Automática de Período
O servidor segue estritamente a regra:
*   Se a data atual estiver entre **01 de Janeiro** e **01 de Agosto** de um determinado ano, ele seleciona por padrão o primeiro semestre letivo daquele ano (ex: `202611`).
*   Caso contrário, ele seleciona o segundo semestre letivo (ex: `202623`).

Você também pode alternar entre outros semestres passados (como `202523`) a qualquer momento usando a caixa de seleção na parte superior direita da tela.

### 2. Medidor de Preocupação (Concern Meter)
O card de cada disciplina exibe um indicador visual rápido sobre a sua situação acadêmica:
*   **Tranquilo:** Média somada das notas >= 18 (já aprovado por média 6,0).
*   **Atenção:** Precisa de até 3,0 pontos para atingir a média 18.
*   **Preocupante:** Precisa de 3,1 a 6,0 pontos para passar.
*   **Crítico:** Precisa de mais de 6,0 pontos para passar.
*   **Risco Faltas:** Caso seu percentual de faltas atinja 18% ou mais (o limite para reprovação é 25%).

### 3. Falta para Passar
O card calcula exatamente quantos pontos faltam para você atingir a média de 18 pontos (média global de 6,0 nas três notas principais).
