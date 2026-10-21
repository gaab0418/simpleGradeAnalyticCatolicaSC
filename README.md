# TOTVS RM Portal - Automatização de Notas & Faltas

Este projeto automatiza o fluxo de autenticação e consulta de notas/faltas do portal acadêmico TOTVS RM e disponibiliza uma interface web em forma de boletim (caderno quadriculado no tema claro, lousa no tema escuro) para visualização.

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

### 2. Situação de cada matéria (marca-texto)
A situação é calculada pela **média que você ainda precisa nas provas que faltam**, e não pelo total de pontos que faltam. Assim, 9,8 na N1 com duas provas pela frente (precisa de média 4,1) aparece como tranquila, e não como crítica.

| Situação | Quando |
|---|---|
| Garantida / Aprovada | Soma >= 18 (média 6), ou o portal já marcou como aprovada |
| Tranquila | Precisa de média até 5,0 no que falta |
| Atenção | Precisa de 5,1 a 7,0 |
| Apertada | Precisa de 7,1 a 8,5 |
| Crítica | Precisa de 8,6 a 10,0 |
| Fora de alcance | Nem com 10 fecha média 6 |
| Limite de faltas | 16 a 20 faltas (resta 1 dia) |
| Reprovada por falta | Mais de 20 faltas (5 dias de 4 aulas) |
| Sem notas ainda | Nenhuma nota lançada |

### 3. Notas a lápis
Cada nota ainda não lançada aparece escrita "a lápis" com o mínimo que você precisa tirar nela.

### 4. Simulador "E se eu tirar…"
Clique numa matéria para abrir o simulador: arraste as notas que faltam e veja na hora se a soma fecha 18.

### 5. Faltas em tracinhos
As faltas aparecem como 5 grupos de 4 tracinhos (um grupo por dia de aula). Cada dia inteiro perdido é riscado.

### 6. Ordenação por risco
As matérias mais urgentes ficam no topo, e o resumo diz em uma frase onde está o foco do semestre.

### 7. Cache e tema
O servidor guarda cada semestre em cache por 5 minutos, então trocar de semestre e voltar é instantâneo. O botão **Atualizar** ignora o cache. O tema segue o sistema (caderno no claro, lousa no escuro) e pode ser trocado no botão da lua.
