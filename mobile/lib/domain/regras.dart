/// Regras academicas da Catolica SC. Porte fiel da logica do index.html:
/// a situacao e dada pela media que ainda falta tirar, nao pelos pontos.
library;

import 'models.dart';

const double somaAprovacao = 18; // media 6 em 3 notas
const double notaMaxima = 10;
const double notaMinimaAprovacao = 6;
const int limiteFaltas = 20; // acima disso reprova (5 dias de 4 aulas)
const int aulasPorDia = 4;
const int alertaFaltas = 16; // falta 1 dia para o limite

/// Cor do marca-texto.
enum Tom { ok, calmo, atencao, apertado, critico, neutro }

/// `urgencia` maior = aparece primeiro no boletim.
enum Situacao {
  reprovadaPorFalta(9, Tom.critico, 'Reprovada por falta'),
  reprovada(8, Tom.critico, 'Reprovada'),
  foraDeAlcance(7, Tom.critico, 'Fora de alcance'),
  critica(6, Tom.critico, 'Crítica'),
  limiteDeFaltas(5, Tom.apertado, 'Limite de faltas'),
  apertada(4, Tom.apertado, 'Apertada'),
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

/// Uma disciplina ja interpretada pelas regras.
class Analise {
  Analise._(
    this.disciplina, {
    required this.soma,
    required this.lancadas,
    required this.precisa,
    required this.situacao,
  });

  final Disciplina disciplina;
  final double soma;
  final int lancadas;

  /// Media minima nas provas que faltam para fechar 18; `null` se nao falta prova.
  final double? precisa;
  final Situacao situacao;

  int get restantes => disciplina.notas.length - lancadas;
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
  final lancadas = d.notas.whereType<double>().toList();
  final soma = lancadas.fold<double>(0, (a, b) => a + b);
  final restantes = d.notas.length - lancadas.length;
  final faltam = soma >= somaAprovacao ? 0.0 : somaAprovacao - soma;
  // Arredonda para cima em 1 casa. O epsilon evita que um erro de ponto
  // flutuante (41.00000001) suba a exigencia um decimo a toa.
  final precisa = restantes > 0
      ? ((faltam / restantes) * 10 - 1e-9).ceil() / 10
      : null;
  final oficial = d.situacao.toLowerCase();

  Situacao s;
  if (d.faltas > limiteFaltas) {
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
  if (d.faltas >= alertaFaltas &&
      s.urgencia < Situacao.limiteDeFaltas.urgencia) {
    s = Situacao.limiteDeFaltas;
  }

  return Analise._(
    d,
    soma: soma,
    lancadas: lancadas.length,
    precisa: precisa,
    situacao: s,
  );
}

/// Analisa e ordena: o mais urgente primeiro.
List<Analise> analisarSemestre(Semestre s) {
  return s.disciplinas.map(analisar).toList()..sort((a, b) {
    final r = b.situacao.urgencia.compareTo(a.situacao.urgencia);
    return r != 0 ? r : (b.precisa ?? 0).compareTo(a.precisa ?? 0);
  });
}

/// Semestre fechado: nada mais muda no portal, nao precisa buscar de novo.
bool semestreEncerrado(Semestre s) =>
    s.disciplinas.isNotEmpty &&
    s.disciplinas.every((d) => analisar(d).situacao.encerrada);

/// Periodo letivo vigente pela data: ate 01/08 e o primeiro (AAAA11),
/// depois o segundo (AAAA23).
String periodoPadrao(DateTime agora) {
  final primeiro = agora.month < 8 || (agora.month == 8 && agora.day == 1);
  return '${agora.year}${primeiro ? '11' : '23'}';
}

/// Resultado do simulador "E se eu tirar...".
class Simulacao {
  const Simulacao(this.soma);
  final double soma;
  bool get passa => soma >= somaAprovacao;
  double get media => soma / 3;
  double get faltariam => passa ? 0 : somaAprovacao - soma;
}

Simulacao simular(Analise a, Iterable<double> palpites) =>
    Simulacao(palpites.fold<double>(a.soma, (s, v) => s + v));
