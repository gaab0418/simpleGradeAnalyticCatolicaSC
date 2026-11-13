/// Peças visuais compartilhadas pelas telas.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/regras.dart';

/// Selo de situação: ponto + rótulo. A cor reforça; quem informa é o texto.
class Selo extends StatelessWidget {
  const Selo(this.texto, {super.key, required this.tom});
  final String texto;
  final Tom tom;

  @override
  Widget build(BuildContext context) {
    final (:cor, :fundo) = Paleta.of(context).tons[tom]!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faltas em cinco blocos (um por dia de aula que pode ser perdido) e o
/// número ao lado.
class BarraDeFaltas extends StatelessWidget {
  const BarraDeFaltas(this.faltas, {super.key});
  final int faltas;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final alerta = faltas >= alertaFaltas;
    final cor = alerta ? c.critico : c.texto2;
    final sobra = faltas >= limiteFaltas ? 0 : limiteFaltas - faltas;
    return Semantics(
      label:
          '$faltas de $limiteFaltas faltas. Pode faltar mais ${dias(sobra)}.',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var d = 0; d < limiteFaltas ~/ aulasPorDia; d++)
            Container(
              width: 14,
              height: 6,
              margin: const EdgeInsets.only(right: 2),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.superficie2,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: c.borda),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor:
                    (faltas - d * aulasPorDia).clamp(0, aulasPorDia) /
                    aulasPorDia,
                child: ColoredBox(color: cor),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            '$faltas/$limiteFaltas',
            style: TextStyle(
              fontSize: 13,
              color: cor,
              fontWeight: alerta ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloco com título de seção, usado no desempenho e nos ajustes.
class Painel extends StatelessWidget {
  const Painel({super.key, this.titulo, this.legenda, required this.child});
  final String? titulo;
  final String? legenda;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titulo != null)
              Text(
                titulo!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (legenda != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  legenda!,
                  style: TextStyle(fontSize: 13, color: c.texto2),
                ),
              ),
            if (titulo != null || legenda != null) const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Faixa de aviso com borda lateral colorida (erro, novidade, prioridade).
class Aviso extends StatelessWidget {
  const Aviso(this.texto, {super.key, this.cor, this.acao, this.aoAgir});
  final String texto;
  final Color? cor;
  final String? acao;
  final VoidCallback? aoAgir;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.borda),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: cor ?? c.borda),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(texto, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
            if (acao != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(onPressed: aoAgir, child: Text(acao!)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
