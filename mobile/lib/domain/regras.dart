/// Regras academicas (as mesmas de site/src/lib/dominio/regras.ts):
/// a situacao e dada pela media que ainda falta tirar, nao pelos pontos.
library;

import 'models.dart';

const double somaAprovacao = 18; // media 6 em 3 notas
const double notaMaxima = 10;
const double notaMinimaAprovacao = 6;
const int limiteFaltas = 20; // acima disso reprova (5 dias de 4 aulas)
const int limiteFaltasPac = 8; // acima disso reprova no PAC (2 dias de 4 aulas)
const int aulasPorDia = 4;
const int alertaFaltas = 16; // falta 1 dia para o limite
const int alertaFaltasPac = 4; // falta 1 dia para o limite no PAC

final _regexPac = RegExp(
  r'\bPAC\b|PROJETO DE APRENDIZAGEM COLABORATIVA',
  caseSensitive: false,
);
final _regexCodPac = RegExp(r'^PAC\b', caseSensitive: false);

/// Identifica disciplinas de PAC, que possuem metade da carga horária e limite de 2 dias de falta.
bool ehPac(Disciplina d) =>
    _regexPac.hasMatch(d.nomeBruto) || _regexCodPac.hasMatch(d.codDisc);

/// Cor do marca-texto.
enum Tom { ok, calmo, atencao, apertado, critico, neutro }

/// `urgencia` maior = aparece primeiro no boletim.
enum Situacao {
  reprovadaPorFalta(9, Tom.critico, 'Reprovada por falta'),
  reprovada(8, Tom.critico, 'Reprovada'),
  foraDeAlcance(7, Tom.critico, 'Fora de alcance'),
  critica(6, Tom.critico, 'Crítica'),
  limiteDeFaltas(5, Tom.apertado, 'Limite de faltas'),
  apertada(4, Tom.apertado, 'Em Risco'),
  atencao(3, Tom.atencao, 'Atenção'),
  tranquila(2, Tom.calmo, 'Tranquila'),
  semNotas(1, Tom.neutro, 'Sem notas ainda'),
  garantida(0, Tom.ok, 'Garantida'),
  aprovada(0, Tom.ok, 'Aprovada');

  const Situacao(this.urgencia, this.tom, this.rotulo);

  final int urgencia;
  final Tom tom;
  final String rotulo;

  bool get passou => this == garantida || this == aprovada;

  /// Resultado definitivo: nao ha mais o que simular.
  bool get encerrada =>
      this == aprovada || this == reprovada || this == reprovadaPorFalta;
}

Situacao _porNecessidade(double media) {
  if (media > notaMaxima) return Situacao.foraDeAlcance;
  if (media > 8.5) return Situacao.critica;
  if (media > 7) return Situacao.apertada;
  if (media > 5) return Situacao.atencao;
  return Situacao.tranquila;
}

/// Identifica a menor nota entre N1..N3 (tratando `null` como `0` quando houver N4)
/// e a substitui se `nota4 >= menor`.
({List<double?> notasEfetivas, int? indiceSubstituido, double? notaSubstituida})
aplicarNota4(List<double?> notas, double? nota4) {
  assert(notas.length == 3);
  if (nota4 == null) {
    return (
      notasEfetivas: List<double?>.unmodifiable(notas),
      indiceSubstituido: null,
      notaSubstituida: null,
    );
  }
  var idxMenor = 0;
  var menor = notas[0] ?? 0.0;
  for (var i = 1; i < notas.length; i++) {
    final v = notas[i] ?? 0.0;
    if (v < menor) {
      menor = v;
      idxMenor = i;
    }
  }
  if (nota4 < menor) {
    return (
      notasEfetivas: List<double?>.unmodifiable(notas),
      indiceSubstituido: null,
      notaSubstituida: null,
    );
  }
  final efetivas = List<double?>.of(notas);
  efetivas[idxMenor] = nota4;
  return (
    notasEfetivas: List<double?>.unmodifiable(efetivas),
    indiceSubstituido: idxMenor,
    notaSubstituida: menor,
  );
}

/// Uma disciplina ja interpretada pelas regras.
class Analise {
  Analise._(
    this.disciplina, {
    required this.notasEfetivas,
    required this.nota4,
    required this.indiceSubstituido,
    required this.notaSubstituida,
    required this.soma,
    required this.lancadas,
    required this.restantes,
    required this.precisa,
    required this.precisaN4,
    required this.situacao,
    required this.limiteFaltas,
    required this.alertaFaltas,
  });

  final Disciplina disciplina;
  final List<double?> notasEfetivas;
  final double? nota4;
  final int? indiceSubstituido;
  final double? notaSubstituida;
  final double soma;
  final int lancadas;
  final int restantes;

  /// Media minima nas provas que faltam para fechar 18; `null` se nao falta prova.
  final double? precisa;

  /// Nota minima na N4 (recuperacao) quando as 3 provas estao lancadas e soma < 18.
  final double? precisaN4;
  final Situacao situacao;

  /// Limite maximo de faltas (em aulas) para esta disciplina.
  final int limiteFaltas;

  /// Quantidade de faltas (em aulas) a partir da qual dispara alerta.
  final int alertaFaltas;

  int get faltas => disciplina.faltas;
  int get faltasRestantes => faltas >= limiteFaltas ? 0 : limiteFaltas - faltas;

  /// Media da disciplina: a oficial quando existe; senao a das notas lancadas.
  double? get media {
    if (disciplina.mediaFinal != null) return disciplina.mediaFinal;
    return lancadas == 0 ? null : soma / lancadas;
  }

  /// A media acima ja e definitiva (todas as notas ou resultado oficial).
  bool get mediaDefinitiva => disciplina.mediaFinal != null || restantes == 0;
}

Analise analisar(Disciplina d) {
  final pac = ehPac(d);
  final limFaltas = pac ? limiteFaltasPac : limiteFaltas;
  final alFaltas = pac ? alertaFaltasPac : alertaFaltas;
  final n4Res = aplicarNota4(d.notas, d.nota4);
  final notasEfetivas = n4Res.notasEfetivas;
  final lancadas = notasEfetivas.whereType<double>().toList();
  final soma = lancadas.fold<double>(0, (a, b) => a + b);
  final restantes = notasEfetivas.length - lancadas.length;
  final faltam = soma >= somaAprovacao ? 0.0 : somaAprovacao - soma;
  // Arredonda para cima em 1 casa. O epsilon evita que um erro de ponto
  // flutuante (41.00000001) suba a exigencia um decimo a toa.
  final precisa = restantes > 0
      ? ((faltam / restantes) * 10 - 1e-9).ceil() / 10
      : null;
  final oficial = d.situacao.toLowerCase();

  double? precisaN4;
  if (d.nota4 == null &&
      restantes == 0 &&
      soma < somaAprovacao &&
      d.faltas <= limFaltas &&
      !oficial.startsWith('aprov') &&
      !oficial.startsWith('reprov')) {
    final menor = lancadas.reduce((a, b) => a < b ? a : b);
    final faltamN4 = somaAprovacao - (soma - menor);
    precisaN4 = (faltamN4 * 10 - 1e-9).ceil() / 10;
  }

  Situacao s;
  if (d.faltas > limFaltas) {
    s = Situacao.reprovadaPorFalta;
  } else if (oficial.startsWith('aprov')) {
    s = Situacao.aprovada;
  } else if (oficial.startsWith('reprov')) {
    s = Situacao.reprovada;
  } else if (lancadas.isEmpty) {
    s = Situacao.semNotas;
  } else if (soma >= somaAprovacao) {
    s = Situacao.garantida;
  } else if (restantes == 0) {
    s = Situacao.reprovada;
  } else {
    s = _porNecessidade(precisa!);
  }

  // Faltas perto do limite pesam mais que nota tranquila.
  if (d.faltas >= alFaltas &&
      s.urgencia < Situacao.limiteDeFaltas.urgencia) {
    s = Situacao.limiteDeFaltas;
  }

  return Analise._(
    d,
    notasEfetivas: notasEfetivas,
    nota4: d.nota4,
    indiceSubstituido: n4Res.indiceSubstituido,
    notaSubstituida: n4Res.notaSubstituida,
    soma: soma,
    lancadas: lancadas.length,
    restantes: restantes,
    precisa: precisa,
    precisaN4: precisaN4,
    situacao: s,
    limiteFaltas: limFaltas,
    alertaFaltas: alFaltas,
  );
}

enum ModoOrdem { urgencia, nome, faltas, soma, personalizada }

/// Ordena analises conforme o modo escolhido ou a lista personalizada de chaves.
List<Analise> ordenarAnalises(
  List<Analise> analises,
  ModoOrdem modo, [
  List<String> ordemPersonalizada = const [],
]) {
  final copia = List<Analise>.of(analises);
  switch (modo) {
    case ModoOrdem.personalizada when ordemPersonalizada.isNotEmpty:
      final pos = <String, int>{
        for (var i = 0; i < ordemPersonalizada.length; i++)
          ordemPersonalizada[i]: i,
      };
      copia.sort((a, b) {
        final ia = pos[a.disciplina.chave] ?? 1 << 30;
        final ib = pos[b.disciplina.chave] ?? 1 << 30;
        final cmp = ia.compareTo(ib);
        return cmp != 0
            ? cmp
            : b.situacao.urgencia.compareTo(a.situacao.urgencia);
      });
    case ModoOrdem.nome:
      copia.sort(
        (a, b) => a.disciplina.nomeBruto.toLowerCase().compareTo(
          b.disciplina.nomeBruto.toLowerCase(),
        ),
      );
    case ModoOrdem.faltas:
      copia.sort((a, b) {
        final prop = (b.faltas / b.limiteFaltas).compareTo(
          a.faltas / a.limiteFaltas,
        );
        if (prop != 0) return prop;
        final abs = b.faltas.compareTo(a.faltas);
        return abs != 0
            ? abs
            : b.situacao.urgencia.compareTo(a.situacao.urgencia);
      });
    case ModoOrdem.soma:
      copia.sort((a, b) {
        final s = b.soma.compareTo(a.soma);
        return s != 0 ? s : b.situacao.urgencia.compareTo(a.situacao.urgencia);
      });
    case ModoOrdem.urgencia:
    case ModoOrdem.personalizada:
      copia.sort((a, b) {
        final r = b.situacao.urgencia.compareTo(a.situacao.urgencia);
        return r != 0 ? r : (b.precisa ?? 0).compareTo(a.precisa ?? 0);
      });
  }
  return copia;
}

/// Move uma chave na lista por deslocamento (-1/+1) ou para a posicao de [alvo].
List<String> moverChave(
  List<String> chaves,
  String chave, {
  int? deslocamento,
  String? alvo,
}) {
  final lista = List<String>.of(chaves);
  final idx = lista.indexOf(chave);
  if (idx == -1) return lista;
  final novoIdx = alvo != null
      ? lista.indexOf(alvo)
      : idx + (deslocamento ?? 0);
  if (novoIdx < 0 || novoIdx >= lista.length || novoIdx == idx) return lista;
  final item = lista.removeAt(idx);
  lista.insert(novoIdx, item);
  return lista;
}

/// Analisa e ordena: o mais urgente primeiro.
List<Analise> analisarSemestre(Semestre s) =>
    ordenarAnalises(s.disciplinas.map(analisar).toList(), ModoOrdem.urgencia);

/// Semestre fechado: nada mais muda no portal, nao precisa buscar de novo.
bool semestreEncerrado(Semestre s) =>
    s.disciplinas.isNotEmpty &&
    s.disciplinas.every((d) => analisar(d).situacao.encerrada);

/// Semestre consolidado: encerrado ou de um ano anterior ao corrente.
bool semestreConsolidado(Semestre s, [DateTime? agora]) {
  if (s.disciplinas.isEmpty) return false;
  if (semestreEncerrado(s)) return true;
  final ano = s.codigo.length >= 4
      ? int.tryParse(s.codigo.substring(0, 4))
      : null;
  return ano != null && ano < (agora ?? DateTime.now()).year;
}

/// Periodo letivo vigente pela data: ate 01/08 e o primeiro (AAAA11),
/// depois o segundo (AAAA23).
String periodoPadrao(DateTime agora) {
  final primeiro = agora.month < 8 || (agora.month == 8 && agora.day == 1);
  return '${agora.year}${primeiro ? '11' : '23'}';
}

/// Resultado do simulador "E se eu tirar...".
class Simulacao {
  const Simulacao(
    this.soma, {
    required this.notasEfetivas,
    this.indiceSubstituido,
    this.notaSubstituida,
    this.nota4,
  });

  final double soma;
  final List<double?> notasEfetivas;
  final int? indiceSubstituido;
  final double? notaSubstituida;
  final double? nota4;

  bool get passa => soma >= somaAprovacao;
  double get media => soma / 3;
  double get faltariam => passa ? 0 : somaAprovacao - soma;
}

Simulacao simular(Analise a, Iterable<double> palpites, {double? nota4}) {
  final it = palpites.iterator;
  if (nota4 == null) {
    final base = [
      for (final n in a.notasEfetivas)
        n ?? (it.moveNext() ? it.current : null),
    ];
    final soma = base.whereType<double>().fold<double>(0, (s, v) => s + v);
    return Simulacao(
      soma,
      notasEfetivas: List<double?>.unmodifiable(base),
      indiceSubstituido: a.indiceSubstituido,
      notaSubstituida: a.notaSubstituida,
      nota4: a.nota4,
    );
  }
  final originais = [
    for (final n in a.disciplina.notas)
      n ?? (it.moveNext() ? it.current : null),
  ];
  final res = aplicarNota4(originais, nota4);
  final soma = res.notasEfetivas.whereType<double>().fold<double>(
    0,
    (s, v) => s + v,
  );
  return Simulacao(
    soma,
    notasEfetivas: res.notasEfetivas,
    indiceSubstituido: res.indiceSubstituido,
    notaSubstituida: res.notaSubstituida,
    nota4: nota4,
  );
}
