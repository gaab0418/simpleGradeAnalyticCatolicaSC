import 'package:boletim_catolica/core/format.dart';
import 'package:boletim_catolica/data/demo.dart';
import 'package:boletim_catolica/data/portal.dart';
import 'package:boletim_catolica/domain/desempenho.dart';
import 'package:boletim_catolica/domain/models.dart';
import 'package:boletim_catolica/domain/regras.dart';
import 'package:boletim_catolica/domain/resumo.dart';
import 'package:flutter_test/flutter_test.dart';

Disciplina disc(
  List<double?> notas, {
  double? nota4,
  int faltas = 0,
  String situacao = 'Matriculado',
  double? mediaFinal,
  String nome = 'CÁLCULO II - CAL2',
}) => Disciplina(
  chave: nome,
  codTurma: 'T1',
  codDisc: 'D1',
  nomeBruto: nome,
  situacao: situacao,
  notas: notas,
  nota4: nota4,
  mediaFinal: mediaFinal,
  faltas: faltas,
);

void main() {
  group('situação da matéria', () {
    test('9,8 na N1 precisa de 4,1 nas outras duas: tranquila', () {
      final a = analisar(disc([9.8, null, null]));
      expect(a.precisa, 4.1);
      expect(a.situacao, Situacao.tranquila);
    });

    test('faixas pela média que falta', () {
      expect(analisar(disc([6, 6, null])).situacao, Situacao.atencao); // 6,0
      expect(analisar(disc([5, 5, null])).situacao, Situacao.apertada); // 8,0
      expect(analisar(disc([4.5, 4.5, null])).situacao, Situacao.critica);
      expect(analisar(disc([2, 4.5, null])).situacao, Situacao.foraDeAlcance);
      expect(analisar(disc([null, null, null])).situacao, Situacao.semNotas);
    });

    test('soma 18 garante; três notas abaixo reprovam', () {
      expect(analisar(disc([9, 9, null])).situacao, Situacao.garantida);
      expect(analisar(disc([5, 5, 5])).situacao, Situacao.reprovada);
    });

    test('situação oficial do portal prevalece', () {
      final a = analisar(disc([5, 5, 5], situacao: 'Aprovado', mediaFinal: 6));
      expect(a.situacao, Situacao.aprovada);
      expect(a.media, 6);
    });

    test('faltas: alerta a partir de 16, reprova acima de 20', () {
      expect(
        analisar(disc([9.8, null, null], faltas: 16)).situacao,
        Situacao.limiteDeFaltas,
      );
      expect(
        analisar(disc([10, 10, 10], faltas: 21)).situacao,
        Situacao.reprovadaPorFalta,
      );
      // Nota critica continua mais urgente que o alerta de faltas.
      expect(
        analisar(disc([4.5, 4.5, null], faltas: 16)).situacao,
        Situacao.critica,
      );
    });

    test('ordena do mais urgente para o mais tranquilo', () {
      final s = Semestre(
        codigo: '202623',
        curso: '',
        situacaoMatricula: '',
        atualizadoEm: DateTime(2026),
        disciplinas: [
          disc([9, 9, null], nome: 'A'),
          disc([4.5, 4.5, null], nome: 'B'),
          disc([6, 6, null], nome: 'C'),
        ],
      );
      expect(analisarSemestre(s).map((a) => a.disciplina.nomeBruto), [
        'B',
        'C',
        'A',
      ]);
      expect(semestreEncerrado(s), isFalse);
    });

    test('simulador', () {
      final a = analisar(disc([6, null, null]));
      expect(simular(a, [6, 6]).passa, isTrue);
      expect(simular(a, [5, 6]).faltariam, 1);
    });

    test('aplicarNota4 substitui a menor nota inclusive nula quando N4 >= menor', () {
      final r1 = aplicarNota4([3.5, 6.8, 7.0], 5.5);
      expect(r1.notasEfetivas, [5.5, 6.8, 7.0]);
      expect(r1.indiceSubstituido, 0);
      expect(r1.notaSubstituida, 3.5);

      final r2 = aplicarNota4([6.0, null, 7.0], 5.0);
      expect(r2.notasEfetivas, [6.0, 5.0, 7.0]);
      expect(r2.indiceSubstituido, 1);
      expect(r2.notaSubstituida, 0);

      final r3 = aplicarNota4([5.0, 6.0, 7.0], 4.0);
      expect(r3.notasEfetivas, [5.0, 6.0, 7.0]);
      expect(r3.indiceSubstituido, isNull);
    });

    test('análise e simulação com N4', () {
      final semN4 = analisar(disc([3.5, 6.8, 7.0]));
      expect(semN4.situacao, Situacao.reprovada);
      expect(semN4.precisaN4, 4.2);

      final comN4 = analisar(disc([3.5, 6.8, 7.0], nota4: 5.5));
      expect(comN4.notasEfetivas, [5.5, 6.8, 7.0]);
      expect(comN4.indiceSubstituido, 0);
      expect(comN4.notaSubstituida, 3.5);
      expect(comN4.soma, closeTo(19.3, 1e-9));
      expect(comN4.situacao, Situacao.garantida);

      final simN4 = simular(semN4, const [], nota4: 5.5);
      expect(simN4.notasEfetivas, [5.5, 6.8, 7.0]);
      expect(simN4.indiceSubstituido, 0);
      expect(simN4.passa, isTrue);
    });

    test('semestreConsolidado considera encerrado e anos anteriores', () {
      final encerradoAtual = Semestre(
        codigo: '202623',
        curso: '',
        situacaoMatricula: '',
        atualizadoEm: DateTime(2026),
        disciplinas: [disc([8, 8, 8], situacao: 'Aprovado', mediaFinal: 8)],
      );
      final abertoAtual = Semestre(
        codigo: '202623',
        curso: '',
        situacaoMatricula: '',
        atualizadoEm: DateTime(2026),
        disciplinas: [disc([8, null, null])],
      );
      final abertoAnoAnterior = Semestre(
        codigo: '202523',
        curso: '',
        situacaoMatricula: '',
        atualizadoEm: DateTime(2025),
        disciplinas: [disc([8, null, null])],
      );
      final vazio = Semestre(
        codigo: '202511',
        curso: '',
        situacaoMatricula: '',
        atualizadoEm: DateTime(2025),
        disciplinas: const [],
      );

      final ref = DateTime(2026, 11, 12);
      expect(semestreConsolidado(encerradoAtual, ref), isTrue);
      expect(semestreConsolidado(abertoAtual, ref), isFalse);
      expect(semestreConsolidado(abertoAnoAnterior, ref), isTrue);
      expect(semestreConsolidado(vazio, ref), isFalse);
    });

    test('situação apertada usa rótulo Em Risco', () {
      expect(Situacao.apertada.rotulo, 'Em Risco');
    });
  });

  test('período padrão vira em 2 de agosto', () {
    expect(periodoPadrao(DateTime(2026, 8, 1)), '202611');
    expect(periodoPadrao(DateTime(2026, 8, 2)), '202623');
    expect(periodoPadrao(DateTime(2026, 1, 1)), '202611');
  });

  test('formatação', () {
    expect(fmt(7.25), '7,3');
    expect(
      titulo('CÁLCULO DIFERENCIAL E INTEGRAL II'),
      'Cálculo Diferencial e Integral II',
    );
    expect(nomeMateria('BANCO DE DADOS - BD1'), (
      nome: 'Banco de Dados',
      sufixo: 'BD1',
    ));
    expect(rotuloPeriodo('202623'), '2026/2');
    expect(dias(4), '1 dia');
    expect(dias(6), '1,5 dias');
  });

  group('JSON do TOTVS', () {
    test('nota embrulhada em HTML e com vírgula', () {
      expect(parseNota('<font color=red>3,3</font>'), 3.3);
      expect(parseNota('8,5'), 8.5);
      expect(parseNota(''), isNull);
      expect(parseNota(null), isNull);
    });

    test('cruza notas com faltas por IDTURMADISC e extrai Nota 4', () {
      final ds = disciplinasDoJson(
        [
          {
            'IDTURMADISC': 77,
            'CODTURMA': 'T',
            'CODDISC': 'X1',
            'DISCIPLINA': 'REDES - RED',
            'SITUACAO': 'Matriculado',
            '1 - Nota 1': '<font color=red>4,0</font>',
            '2 - Nota 2': '7,5',
            '3 - Nota 3': null,
            '4 - Nota 4': '6,5',
            '4 - Média Parcial': '5,8',
          },
          {
            'IDTURMADISC': 78,
            'CODTURMA': 'T',
            'CODDISC': 'X2',
            'DISCIPLINA': 'BANCO - BD',
            'SITUACAO': 'Matriculado',
            '1 - Nota 1': '3,0',
            '2 - Nota 2': '6,0',
            '3 - Nota 3': '6,0',
            '4 - Recuperação': '7,0',
            '4 - Média': '5,0',
          },
        ],
        [
          {'IDTURMADISC': 77, '1 - Faltas Sala de Aula': '8'},
          {'IDTURMADISC': 99, '1 - Faltas Sala de Aula': '20'},
        ],
      );
      expect(ds.first.notas, [4.0, 7.5, null]);
      expect(ds.first.nota4, 6.5);
      expect(ds.first.faltas, 8);
      expect(ds.first.chave, '77');
      expect(ds[1].nota4, 7.0);
    });
  });

  test('histórico sobrevive a ida e volta em JSON incluindo nota4', () {
    final h = historicoDemo(DateTime(2026, 11, 12));
    final volta = Historico.fromJson(h.toJson());
    expect(volta.semestres.length, h.semestres.length);
    expect(volta.semestres.first.codigo, '202623');
    expect(
      volta.semestre('202623')!.disciplinas.first.notas,
      h.semestre('202623')!.disciplinas.first.notas,
    );
    final pesVolta = volta
        .semestre('202511')!
        .disciplinas
        .firstWhere((d) => d.codDisc == 'PES');
    expect(pesVolta.nota4, 5.5);
  });

  group('com o histórico de demonstração', () {
    final h = historicoDemo(DateTime(2026, 11, 12));

    test('resumo do semestre em andamento aponta o foco', () {
      final r = resumir(analisarSemestre(h.semestre('202623')!));
      expect(r.manchete, '1 de 6 matérias garantidas');
      expect(r.garantidas, 1);
      expect(r.recado, contains('Empreendedorismo'));
      expect(r.recado, contains('nem com 10'));
      expect(r.semNota, 1);
    });

    test('resumo de semestre encerrado', () {
      final r = resumir(analisarSemestre(h.semestre('202411')!));
      expect(r.manchete, 'Semestre encerrado: 4 de 5 aprovadas');
      expect(r.recado, startsWith('Média geral'));
    });

    test('202511 PES usa N4 para aprovação', () {
      final pes = h
          .semestre('202511')!
          .disciplinas
          .firstWhere((d) => d.codDisc == 'PES');
      expect(pes.notas, [3.5, 6.8, 7.0]);
      expect(pes.nota4, 5.5);
      final a = analisar(pes);
      expect(a.notasEfetivas, [5.5, 6.8, 7.0]);
      expect(a.situacao, Situacao.aprovada);
      expect(a.media, 6.4);
    });

    test('desempenho no curso', () {
      final d = Desempenho(h);
      expect(d.concluidas.length, 25);
      expect(d.aprovadas, 24);
      expect(d.mediaGeral, closeTo(7.8, 0.2));
      expect(d.evolucao.length, 6);
      expect(d.evolucao.last.encerrado, isFalse);
      expect(d.tendencia, greaterThan(0));
      expect(d.melhorSemestre!.codigo, '202611');
      expect(
        d.distribuicao.map((f) => f.quantidade).reduce((a, b) => a + b),
        25,
      );
      expect(d.melhores().first.nome, 'Desenvolvimento Mobile');
      expect(d.piores().first.nome, 'Cálculo I');
      expect(d.anotacoes, isNotEmpty);
    });
  });
}
