/// A frase-resumo do semestre: onde esta o foco agora.
library;

import '../core/format.dart';
import 'regras.dart';

class ResumoBoletim {
  const ResumoBoletim({
    required this.manchete,
    required this.recado,
    required this.materias,
    required this.semNota,
    required this.faltas,
  });

  final String manchete;

  /// Anotacao "a caneta vermelha"; vazia quando nao ha o que destacar.
  final String recado;
  final int materias;
  final int semNota;
  final int faltas;
}

/// [materias] ja ordenadas por urgencia (ver `analisarSemestre`).
ResumoBoletim resumir(List<Analise> materias) {
  final n = materias.length;
  final ok = materias.where((m) => m.situacao.passou).length;
  final encerrado = n > 0 && materias.every((m) => m.situacao.encerrada);
  final rf = materias
      .where((m) => m.situacao == Situacao.reprovadaPorFalta)
      .firstOrNull;
  final foco = materias
      .where(
        (m) =>
            m.restantes > 0 &&
            (m.precisa ?? 0) > 0 &&
            m.situacao.urgencia >= Situacao.atencao.urgencia,
      )
      .firstOrNull;
  String nome(Analise a) => nomeMateria(a.disciplina.nomeBruto).nome;

  var manchete = '';
  var recado = '';
  if (n == 0) {
    manchete = 'Nada lançado neste semestre.';
  } else if (encerrado) {
    final medias = materias
        .map((m) => m.disciplina.mediaFinal)
        .whereType<double>()
        .toList();
    manchete = 'Semestre encerrado: $ok de $n aprovadas.';
    if (medias.isNotEmpty) {
      recado =
          'média geral ${fmt(medias.reduce((a, b) => a + b) / medias.length)}';
    }
  } else {
    manchete = ok == 0
        ? 'Nenhuma das $n matérias está garantida ainda.'
        : ok == n
        ? 'Todas as $n matérias garantidas.'
        : '$ok de $n matérias já garantidas.';
    if (rf != null) {
      recado = '${nome(rf)} passou do limite de faltas.';
    } else if (foco != null) {
      final precisa = foco.precisa!;
      recado = precisa > notaMaxima
          ? '${nome(foco)}: nem com 10 fecha média 6. Vale conversar com o professor.'
          : foco.restantes == 1
          ? 'Foco em ${nome(foco)}: precisa de ${fmt(precisa)} na última prova.'
          : 'Foco em ${nome(foco)}: precisa de média ${fmt(precisa)} nas ${foco.restantes} provas que faltam.';
    } else if (ok < n) {
      recado =
          'Tudo no ritmo: nenhuma matéria pede mais que média 5 no que falta.';
    }
  }

  return ResumoBoletim(
    manchete: manchete,
    recado: recado,
    materias: n,
    semNota: materias.where((m) => m.situacao == Situacao.semNotas).length,
    faltas: materias.fold(0, (a, m) => a + m.faltas),
  );
}
