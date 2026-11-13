/// Modelos de dominio. Tudo imutavel e serializavel em JSON para o cache local.
library;

double? _num(Object? v) => v is num ? v.toDouble() : null;

class Aluno {
  const Aluno({required this.nome, required this.ra, required this.curso});

  final String nome;
  final String ra;
  final String curso;

  factory Aluno.fromJson(Map<String, dynamic> j) => Aluno(
    nome: j['nome'] as String? ?? '',
    ra: j['ra'] as String? ?? '',
    curso: j['curso'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'nome': nome, 'ra': ra, 'curso': curso};
}

class Disciplina {
  const Disciplina({
    required this.chave,
    required this.codTurma,
    required this.codDisc,
    required this.nomeBruto,
    required this.situacao,
    required this.notas,
    this.mediaParcial,
    this.mediaFinal,
    this.faltas = 0,
  }) : assert(notas.length == 3);

  /// IDTURMADISC do portal (ou CODDISC quando ele nao vem).
  final String chave;
  final String codTurma;
  final String codDisc;

  /// Nome como vem do portal: "MATERIA - SIGLA".
  final String nomeBruto;

  /// Situacao oficial do portal ("Aprovado", "Reprovado", "Matriculado"...).
  final String situacao;

  /// N1, N2 e N3; `null` = ainda nao lancada.
  final List<double?> notas;
  final double? mediaParcial;
  final double? mediaFinal;
  final int faltas;

  factory Disciplina.fromJson(Map<String, dynamic> j) => Disciplina(
    chave: j['chave'] as String? ?? '',
    codTurma: j['codTurma'] as String? ?? '',
    codDisc: j['codDisc'] as String? ?? '',
    nomeBruto: j['nome'] as String? ?? '',
    situacao: j['situacao'] as String? ?? '',
    notas: [
      for (var i = 0; i < 3; i++)
        _num((j['notas'] as List?)?.elementAtOrNull(i)),
    ],
    mediaParcial: _num(j['mediaParcial']),
    mediaFinal: _num(j['mediaFinal']),
    faltas: (j['faltas'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'chave': chave,
    'codTurma': codTurma,
    'codDisc': codDisc,
    'nome': nomeBruto,
    'situacao': situacao,
    'notas': notas,
    'mediaParcial': mediaParcial,
    'mediaFinal': mediaFinal,
    'faltas': faltas,
  };
}

class Semestre {
  const Semestre({
    required this.codigo,
    required this.curso,
    required this.situacaoMatricula,
    required this.disciplinas,
    required this.atualizadoEm,
  });

  /// CODPERLET do portal, ex.: "202623".
  final String codigo;
  final String curso;
  final String situacaoMatricula;
  final List<Disciplina> disciplinas;
  final DateTime atualizadoEm;

  factory Semestre.fromJson(Map<String, dynamic> j) => Semestre(
    codigo: j['codigo'] as String? ?? '',
    curso: j['curso'] as String? ?? '',
    situacaoMatricula: j['situacaoMatricula'] as String? ?? '',
    disciplinas: [
      for (final d in (j['disciplinas'] as List? ?? const []))
        Disciplina.fromJson(Map<String, dynamic>.from(d as Map)),
    ],
    atualizadoEm:
        DateTime.tryParse(j['atualizadoEm'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'curso': curso,
    'situacaoMatricula': situacaoMatricula,
    'disciplinas': [for (final d in disciplinas) d.toJson()],
    'atualizadoEm': atualizadoEm.toIso8601String(),
  };
}

/// Tudo o que o app guarda do aluno: um semestre por periodo letivo.
class Historico {
  Historico({required this.aluno, required Iterable<Semestre> semestres})
    : semestres = List.unmodifiable(
        semestres.toList()..sort((a, b) => b.codigo.compareTo(a.codigo)),
      );

  final Aluno aluno;

  /// Do mais recente para o mais antigo.
  final List<Semestre> semestres;

  Semestre? semestre(String? codigo) {
    for (final s in semestres) {
      if (s.codigo == codigo) return s;
    }
    return null;
  }

  factory Historico.fromJson(Map<String, dynamic> j) => Historico(
    aluno: Aluno.fromJson(Map<String, dynamic>.from(j['aluno'] as Map)),
    semestres: [
      for (final s in (j['semestres'] as List? ?? const []))
        Semestre.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );

  Map<String, dynamic> toJson() => {
    'aluno': aluno.toJson(),
    'semestres': [for (final s in semestres) s.toJson()],
  };
}
