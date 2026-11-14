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

  static const _bordaRaio = BorderRadius.only(
    topLeft: Radius.circular(6),
    topRight: Radius.circular(11),
    bottomRight: Radius.circular(6),
    bottomLeft: Radius.circular(11),
  );

  @override
  Widget build(BuildContext context) {
    final (:cor, :fundo) = Paleta.of(context).tons[tom]!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: _bordaRaio,
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
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

/// Faltas em cinco grupos de 4 tracinhos (tally marks 5×4), com corte
/// diagonal vermelho nos dias completos de 4 aulas, seguido de `faltas/20`.
class BarraDeFaltas extends StatelessWidget {
  const BarraDeFaltas(this.faltas, {super.key});
  final int faltas;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final alerta = faltas >= alertaFaltas;
    final corTexto = alerta ? c.critico : c.texto2;
    final corTracoAtivo = alerta ? c.critico : c.texto;
    final corTracoInativo = c.bordaForte.withValues(alpha: 0.45);
    final sobra = faltas >= limiteFaltas ? 0 : limiteFaltas - faltas;

    return Semantics(
      label:
          '$faltas de $limiteFaltas faltas. Pode faltar mais ${dias(sobra)}.',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(_TallyFaltasPainter.larguraTotal, 14),
              painter: _TallyFaltasPainter(
                faltas: faltas,
                corAtivo: corTracoAtivo,
                corInativo: corTracoInativo,
                corCorte: c.critico,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$faltas/$limiteFaltas',
              style: TextStyle(
                fontSize: 13,
                color: corTexto,
                fontWeight: alerta ? FontWeight.w600 : FontWeight.w400,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TallyFaltasPainter extends CustomPainter {
  const _TallyFaltasPainter({
    required this.faltas,
    required this.corAtivo,
    required this.corInativo,
    required this.corCorte,
  });

  final int faltas;
  final Color corAtivo;
  final Color corInativo;
  final Color corCorte;

  static const int _diasTotais = limiteFaltas ~/ aulasPorDia; // 5
  static const double _tracoW = 2.5;
  static const double _tracoH = 14;
  static const double _tracoGap = 2.0;
  static const double _diaPad = 1.0;
  static const double _diaW =
      _diaPad * 2 + aulasPorDia * _tracoW + (aulasPorDia - 1) * _tracoGap;
  static const double _diaGap = 4.5;
  static const double larguraTotal =
      _diasTotais * _diaW + (_diasTotais - 1) * _diaGap;

  @override
  void paint(Canvas canvas, Size size) {
    final ativo = Paint()..color = corAtivo;
    final inativo = Paint()..color = corInativo;
    final corte = Paint()
      ..color = corCorte
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (var d = 0; d < _diasTotais; d++) {
      final dx = d * (_diaW + _diaGap);
      final usadas = (faltas - d * aulasPorDia).clamp(0, aulasPorDia);
      for (var t = 0; t < aulasPorDia; t++) {
        final tx = dx + _diaPad + t * (_tracoW + _tracoGap);
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tx, 0, _tracoW, _tracoH),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(rrect, t < usadas ? ativo : inativo);
      }
      if (usadas == aulasPorDia) {
        canvas.drawLine(
          Offset(dx - 1, _tracoH - 2.5),
          Offset(dx + _diaW + 1, 2.5),
          corte,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TallyFaltasPainter oldDelegate) =>
      oldDelegate.faltas != faltas ||
      oldDelegate.corAtivo != corAtivo ||
      oldDelegate.corInativo != corInativo ||
      oldDelegate.corCorte != corCorte;
}

/// Exibe uma nota substituída pela N4: nota antiga riscada num canto ao fundo
/// e bloco elevado sobreposto com a nota da N4 em destaque + selo `N4`.
class BlocoN4 extends StatelessWidget {
  const BlocoN4({
    super.key,
    required this.notaAntiga,
    required this.notaN4,
    this.simulada = false,
  });

  final double notaAntiga;
  final double notaN4;
  final bool simulada;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final corN4 = notaN4 < notaMinimaAprovacao
        ? c.critico
        : (simulada ? c.acento : c.texto);
    final corSelo = simulada ? c.acento : c.tons[Tom.calmo]!.cor;
    final fundoSelo = simulada
        ? c.acento.withValues(alpha: 0.14)
        : c.tons[Tom.calmo]!.fundo;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 68,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: c.superficie2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fmt(notaAntiga),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: c.texto3,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: c.texto3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 9,
              right: 2,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.superficie,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: simulada
                        ? c.acento.withValues(alpha: 0.65)
                        : c.bordaForte,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      fmt(notaN4),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: corN4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fundoSelo,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: corSelo.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.autorenew_rounded, size: 9, color: corSelo),
                      const SizedBox(width: 2),
                      Text(
                        'N4',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: corSelo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge discreto `≥X,X` para notas ainda pendentes (e no cartão de prévia).
class NotaPendenteBadge extends StatelessWidget {
  const NotaPendenteBadge(this.notaMinima, {super.key});
  final double notaMinima;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final fora = notaMinima > notaMaxima;
    final corTexto = fora ? c.critico : c.texto2;
    final fundo = fora ? c.tons[Tom.critico]!.fundo : c.superficie2;
    final corBorda = fora
        ? c.critico.withValues(alpha: 0.35)
        : c.bordaForte;

    return CustomPaint(
      painter: _BordaTracejadaPainter(cor: corBorda, raio: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '≥${fmt(notaMinima)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: corTexto,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _BordaTracejadaPainter extends CustomPainter {
  const _BordaTracejadaPainter({required this.cor, required this.raio});
  final Color cor;
  final double raio;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(raio),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 3.0;
    const gap = 2.5;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_BordaTracejadaPainter oldDelegate) =>
      oldDelegate.cor != cor || oldDelegate.raio != raio;
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
  const Aviso(
    this.texto, {
    super.key,
    this.cor,
    this.etiqueta,
    this.acao,
    this.aoAgir,
  });
  final String texto;
  final Color? cor;
  final String? etiqueta;
  final String? acao;
  final VoidCallback? aoAgir;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final corBarra = cor ?? c.borda;
    final fundo = etiqueta != null
        ? Color.alphaBlend((cor ?? c.acento).withValues(alpha: 0.05), c.superficie)
        : c.superficie;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.borda),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: corBarra),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (etiqueta != null)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (cor ?? c.acento).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          etiqueta!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: cor ?? c.acento,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(texto, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
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
