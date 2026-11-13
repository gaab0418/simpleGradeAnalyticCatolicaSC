# Boletim Católica SC

Notas, faltas e quanto falta para passar em cada matéria, a partir do portal acadêmico
TOTVS RM da Católica SC — com o histórico de todos os semestres e uma análise de desempenho
ao longo do curso.

Projeto de estudantes, **não oficial**, sem vínculo com a Católica SC ou a TOTVS.

| Pasta | O que é | Como rodar |
|---|---|---|
| [`site/`](site/README.md) | Site em Next.js, pronto para a Vercel. Sem banco de dados. | `cd site && npm install && npm run dev` |
| [`mobile/`](mobile/README.md) | App Flutter para Android e iOS. | `cd mobile && flutter pub get && flutter run` |
| [`docs/`](docs/ARQUITETURA.md) | Desenho do sistema e as decisões tomadas. | — |

Os dois produtos têm as mesmas regras e o mesmo visual, mas não compartilham código
(TypeScript de um lado, Dart do outro). As regras acadêmicas ficam em
`site/src/lib/dominio/` e `mobile/lib/domain/`; ao mudar uma, mude a outra — os testes
dos dois lados cobrem os mesmos casos.

## O que ele mostra

- **Situação de cada matéria** pela média que você ainda precisa nas provas que faltam
  (9,8 na N1 com duas provas pela frente é "Tranquila", não "Crítica").
- **Simulador**: arraste as notas que faltam e veja se a soma fecha 18.
- **Faltas** contra o limite de 20 aulas, com alerta a partir de 16.
- **Desempenho**: média geral, evolução por semestre, nota média em cada prova,
  distribuição das médias, faltas por semestre, maiores e menores médias.
- **Nota nova**: avisa quando uma nota aparece no portal desde a última consulta.

| Situação | Quando |
|---|---|
| Garantida / Aprovada | Soma ≥ 18 (média 6), ou o portal já marcou como aprovada |
| Tranquila | Precisa de média até 5,0 no que falta |
| Atenção | Precisa de 5,1 a 7,0 |
| Apertada | Precisa de 7,1 a 8,5 |
| Crítica | Precisa de 8,6 a 10,0 |
| Fora de alcance | Nem com 10 fecha média 6 |
| Limite de faltas | 16 a 20 faltas |
| Reprovada por falta | Mais de 20 faltas |

## Privacidade, em uma frase

Ninguém guarda a sua senha em servidor: o app fala direto com o portal; o site precisa
repassar o login pelo próprio servidor (o portal não aceita chamadas de navegador), mas não
grava nada. Detalhes e limites em [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

## Licença

[PolyForm Noncommercial 1.0.0](LICENSE.md): pode usar, estudar, modificar e compartilhar
para fins **não comerciais** (estudo, uso pessoal, pesquisa, ensino). Uso comercial não é
permitido.

Required Notice: Copyright (c) 2026 gaab0418 (https://github.com/gaab0418)

A fonte Schibsted Grotesk é distribuída sob a SIL Open Font License (arquivos `OFL-*.txt`
ao lado da fonte).
