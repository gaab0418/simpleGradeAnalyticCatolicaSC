/// Analise de desempenho ao longo do curso, calculada so com o historico local.
library;

import '../core/format.dart';
import 'models.dart';
import 'regras.dart';

double? _media(Iterable<double> v) {
  final l = v.toList();
  return l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
}

class ResumoSemestre {
  ResumoSemestre(this.semestre)
    : analises = semestre.disciplinas.map(analisar).toList();

  final Semestre semestre;
  final List<Analise> analises;

  String get codigo => semestre.codigo;
  String get rotulo => rotuloPeriodo(codigo);
  bool get encerrado => semestreEncerrado(semestre);
  int get faltas => analises.fold(0, (a, b) => a + b.faltas);
  int get aprovadas => analises.where((a) => a.situacao.passou).length;

  /// Media das disciplinas; parcial enquanto o semestre esta em andamento.
  double? get media => _media(analises.map((a) => a.media).whereType<double>());
}

class MateriaRanqueada {
  const MateriaRanqueada(this.nome, this.periodo, this.media);
  final String nome;
  final String periodo;
  final double media;
}

class FaixaNotas {
  const FaixaNotas(this.rotulo, this.quantidade, {this.abaixoDaMedia = false});
  final String rotulo;
  final int quantidade;
  final bool abaixoDaMedia;
}

class Desempenho {
  Desempenho(Historico h)
    : semestres = [
        // cronologico, ignorando periodos sem nenhuma materia
        for (final s in h.semestres.reversed)
          if (s.disciplinas.isNotEmpty) ResumoSemestre(s),
      ];

  /// Do mais antigo para o mais recente.
  final List<ResumoSemestre> semestres;

  late final List<Analise> _todas = [for (final s in semestres) ...s.analises];

  /// So disciplinas com resultado definitivo entram nas medias do curso.
  late final List<Analise> concluidas = _todas
      .where((a) => a.mediaDefinitiva && a.media != null)
      .toList();

  bool get vazio => concluidas.isEmpty;

  late final double? mediaGeral = _media(concluidas.map((a) => a.media!));

  int get aprovadas => concluidas.where((a) => a.situacao.passou).length;

  double? get taxaAprovacao =>
      concluidas.isEmpty ? null : aprovadas / concluidas.length;

  int get faltasTotais => semestres.fold(0, (a, s) => a + s.faltas);

  /// Semestres com media, na ordem do grafico de evolucao.
  late final List<ResumoSemestre> evolucao = semestres
      .where((s) => s.media != null)
      .toList();

  ResumoSemestre? get melhorSemestre {
    final fechados = evolucao.where((s) => s.encerrado);
    return fechados.isEmpty
        ? null
        : fechados.reduce((a, b) => b.media! > a.media! ? b : a);
  }

  /// Diferenca de media entre os dois ultimos semestres encerrados.
  double? get tendencia {
    final f = evolucao.where((s) => s.encerrado).toList();
    return f.length < 2 ? null : f.last.media! - f[f.length - 2].media!;
  }

  /// Media geral em cada etapa (N1, N2, N3) ao longo do curso.
  late final List<double?> mediaPorEtapa = [
    for (var i = 0; i < 3; i++)
      _media(_todas.map((a) => a.disciplina.notas[i]).whereType<double>()),
  ];

  late final List<FaixaNotas> distribuicao = () {
    int entre(double de, double ate) =>
        concluidas.where((a) => a.media! >= de && a.media! < ate).length;
    return [
      FaixaNotas(
        'abaixo de 6',
        entre(0, notaMinimaAprovacao),
        abaixoDaMedia: true,
      ),
      FaixaNotas('6 a 6,9', entre(6, 7)),
      FaixaNotas('7 a 7,9', entre(7, 8)),
      FaixaNotas('8 a 8,9', entre(8, 9)),
      FaixaNotas('9 a 10', entre(9, 10.01)),
    ];
  }();

  late final List<MateriaRanqueada> _ranking = () {
    final r = <MateriaRanqueada>[
      for (final s in semestres)
        for (final a in s.analises)
          if (a.mediaDefinitiva && a.media != null)
            MateriaRanqueada(
              nomeMateria(a.disciplina.nomeBruto).nome,
              s.rotulo,
              a.media!,
            ),
    ];
    return r..sort((a, b) => b.media.compareTo(a.media));
  }();

  List<MateriaRanqueada> melhores([int n = 3]) => _ranking.take(n).toList();

  /// As mais dificeis, sem repetir as que ja aparecem em [melhores].
  List<MateriaRanqueada> piores([int n = 3]) {
    final resto = _ranking.skip(n).toList();
    return resto.reversed.take(n).toList();
  }

  /// Quanto a media cai nas materias em que voce mais faltou (metade de cima
  /// contra metade de baixo). `null` sem dados suficientes para comparar.
  late final double? custoDasFaltas = () {
    if (concluidas.length < 6) return null;
    final ord = [...concluidas]..sort((a, b) => a.faltas.compareTo(b.faltas));
    final meio = ord.length ~/ 2;
    final poucas = ord.take(meio);
    final muitas = ord.skip(ord.length - meio);
    if (poucas.last.faltas == muitas.first.faltas) return null;
    return _media(poucas.map((a) => a.media!))! -
        _media(muitas.map((a) => a.media!))!;
  }();

  /// Observacoes em linguagem de gente, da mais relevante para a menos.
  late final List<String> anotacoes = () {
    final out = <String>[];
    final t = tendencia;
    if (t != null && t.abs() >= 0.2) {
      out.add(
        t > 0
            ? 'Sua média subiu ${fmt(t)} no último semestre encerrado.'
            : 'Sua média caiu ${fmt(-t)} no último semestre encerrado.',
      );
    }
    final e = mediaPorEtapa;
    if (e.every((v) => v != null)) {
      final d = e[2]! - e[0]!;
      if (d >= 0.4) {
        out.add(
          'Você costuma melhorar ao longo do semestre: a N3 fica ${fmt(d)} acima da N1.',
        );
      } else if (d <= -0.4) {
        out.add(
          'Você começa bem e cai no fim: a N3 fica ${fmt(-d)} abaixo da N1.',
        );
      }
    }
    final c = custoDasFaltas;
    if (c != null && c >= 0.3) {
      out.add(
        'Nas matérias em que você mais falta, a média é ${fmt(c)} menor.',
      );
    }
    final m = melhorSemestre;
    if (m != null && evolucao.where((s) => s.encerrado).length > 1) {
      out.add('Melhor semestre: ${m.rotulo}, com média ${fmt(m.media!)}.');
    }
    final tx = taxaAprovacao;
    if (tx == 1 && concluidas.length >= 4) {
      out.add('Nenhuma reprovação em ${concluidas.length} matérias.');
    }
    return out;
  }();
}
