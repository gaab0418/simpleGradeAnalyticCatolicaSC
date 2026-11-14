/// Formatacao pt-BR sem dependencia de `intl`.
library;

import '../domain/regras.dart';

/// 7.25 -> "7,3"
String fmt(double n) => n.toStringAsFixed(1).replaceAll('.', ',');

const _pequenas = {'de', 'da', 'do', 'das', 'dos', 'e', 'em', 'para', 'a', 'o'};
final _romano = RegExp(r'^[IVX]+$');
final _separador = RegExp(r'\s+|-');

/// "CALCULO DIFERENCIAL E INTEGRAL II" -> "Calculo Diferencial e Integral II"
String titulo(String? texto) {
  if (texto == null || texto.isEmpty) return '';
  final sb = StringBuffer();
  var primeira = true;
  texto.toLowerCase().splitMapJoin(
    _separador,
    onMatch: (m) {
      sb.write(m[0]);
      return '';
    },
    onNonMatch: (p) {
      if (p.isEmpty) return '';
      final up = p.toUpperCase();
      if (_romano.hasMatch(up)) {
        sb.write(up);
      } else if (!primeira && _pequenas.contains(p)) {
        sb.write(p);
      } else {
        sb.write(p[0].toUpperCase() + p.substring(1));
      }
      primeira = false;
      return '';
    },
  );
  return sb.toString();
}

/// "MATERIA - SIGLA" -> (nome legivel, sigla original)
({String nome, String sufixo}) nomeMateria(String bruto) {
  final partes = bruto.split(' - ');
  return (nome: titulo(partes.first), sufixo: partes.skip(1).join(' - '));
}

/// 202623 -> 2026/2
String rotuloPeriodo(String cod) =>
    cod.length >= 5 ? '${cod.substring(0, 4)}/${cod[4]}' : cod;

/// 6 aulas -> "1,5 dias"
String dias(int aulas) {
  final d = aulas / aulasPorDia;
  final txt = d == d.roundToDouble() ? d.toInt().toString() : fmt(d);
  return '$txt ${d == 1 ? 'dia' : 'dias'}';
}

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

/// "hoje às 14:05", "ontem às 09:10" ou "03/11 às 18:00"
String quando(DateTime t, {DateTime? agora}) {
  final a = agora ?? DateTime.now();
  final hora = '${_doisDigitos(t.hour)}:${_doisDigitos(t.minute)}';
  final diff = DateTime(
    a.year,
    a.month,
    a.day,
  ).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (diff == 0) return 'hoje às $hora';
  if (diff == 1) return 'ontem às $hora';
  return '${_doisDigitos(t.day)}/${_doisDigitos(t.month)} às $hora';
}
