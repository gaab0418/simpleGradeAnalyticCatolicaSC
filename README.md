# TOTVS RM Portal - Automatização de Notas & Faltas

Este projeto automatiza o fluxo de autenticação e consulta de notas/faltas do portal acadêmico TOTVS RM e disponibiliza uma interface web bonita (inspirada no tema escuro do Discord) para visualização.

## Estrutura do Projeto

*   `index.html`: A interface gráfica de usuário (frontend) com visualização moderna, Tooltips e ordenação automática por prioridade de risco.
*   `server.py`: O servidor web local em Python que realiza a autenticação síncrona automática, consome os endpoints do TOTVS RM, cruza as notas e faltas e expõe as APIs locais.
*   `.env`: Arquivo local contendo as credenciais de acesso (`USUARIO` e `SENHA`).
*   `.env.example`: Modelo de exemplo para preenchimento de credenciais.
*   `requirements.txt`: Lista de dependências Python do projeto.
*   `run.bat`: Arquivo executável para iniciar o servidor Python no Windows com apenas dois cliques.

## Requisitos

Instale as dependências do projeto através do arquivo `requirements.txt`:

```bash
pip install -r requirements.txt
```

## Como Usar

1.  Renomeie o `.env.example` para `.env` e insira seu usuário e senha do RM Portal.
2.  Dê dois cliques no arquivo `run.bat` para iniciar o servidor local.
3.  Abra o seu navegador em: **[http://localhost:8080](http://localhost:8080)**

---

## Recursos e Funcionalidades

### 1. Seleção Automática de Período
O servidor segue estritamente a regra:
*   Se a data atual estiver entre **01 de Janeiro** e **01 de Agosto** de um determinado ano, ele seleciona por padrão o primeiro semestre letivo daquele ano (ex: `202611`).
*   Caso contrário, ele seleciona o segundo semestre letivo (ex: `202623`).

Você também pode alternar entre outros semestres passados (como `202523`) a qualquer momento usando a caixa de seleção na parte superior direita da tela.

### 2. Medidor de Preocupação (Concern Meter)
O card de cada disciplina exibe um indicador visual rápido sobre a sua situação acadêmica:
*   **Tranquilo (Verde):** Média somada das notas >= 18 (já aprovado por média 6,0).
*   **Atenção (Amarelo):** Precisa de até 3,0 pontos para atingir a média 18.
*   **Preocupante (Laranja):** Precisa de 3,1 a 6,0 pontos para passar.
*   **Crítico (Vermelho):** Precisa de mais de 6,0 pontos para passar.
*   **Limite Faltas (Laranja/Orange):** Caso atinja de 16 a 20 presenças de falta (faltando apenas 1 dia para reprovar).
*   **RF / Reprovado (Vermelho Piscante):** Ultrapassou o limite máximo de 20 presenças de falta (mais de 5 dias completos perdidos).

### 3. Ordenação por Risco
As disciplinas são ordenadas de forma inteligente na tela: as matérias com maior risco de reprovação por falta ou por nota são posicionadas automaticamente no topo para visualização imediata.
