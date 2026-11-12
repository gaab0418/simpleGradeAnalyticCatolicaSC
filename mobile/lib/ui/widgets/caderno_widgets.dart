/// Pecas visuais do "caderno": papel quadriculado, marca-texto, tracinhos de
/// falta e a nota escrita a lapis.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/regras.dart';

/// Fundo de papel quadriculado (24px), como no boletim web.
class PapelQuadriculado extends StatelessWidget {
  const PapelQuadriculado({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    return CustomPaint(painter: _GradePainter(c.grade), child: child);
  }
}

class _GradePainter extends CustomPainter {
  _GradePainter(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = cor
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GradePainter old) => old.cor != cor;
}

/// Texto grifado com marca-texto. O texto sempre usa a cor da tinta: a cor de
/// fundo reforca o significado, nunca e o unico sinal.
class MarcaTexto extends StatelessWidget {
  const MarcaTexto(this.texto, {super.key, required this.tom});
  final String texto;
  final Tom tom;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.marcaTexto[tom],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(4),
          bottomLeft: Radius.circular(9),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            fontWeight: tom == Tom.neutro ? FontWeight.w500 : FontWeight.w600,
            color: c.tinta,
          ),
        ),
      ),
    );
  }
}

/// Faltas em 5 grupos de 4 tracinhos (um grupo por dia de aula); cada dia
/// inteiro perdido e riscado.
class TracinhosDeFalta extends StatelessWidget {
  const TracinhosDeFalta(this.faltas, {super.key});
  final int faltas;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    final sobra = faltas >= limiteFaltas ? 0 : limiteFaltas - faltas;
    return Semantics(
      label:
          '$faltas de $limiteFaltas faltas. Pode faltar mais ${dias(sobra)}.',
      child: CustomPaint(
        size: const Size(96, 18),
        painter: _TracinhosPainter(
          faltas: faltas,
          ligado: faltas >= alertaFaltas ? c.canetaVermelha : c.tinta,
          vazio: c.tracoVazio,
          risco: c.canetaVermelha,
        ),
      ),
    );
  }
}

class _TracinhosPainter extends CustomPainter {
  _TracinhosPainter({
    required this.faltas,
    required this.ligado,
    required this.vazio,
    required this.risco,
  });
  final int faltas;
  final Color ligado;
  final Color vazio;
  final Color risco;

  @override
  void paint(Canvas canvas, Size size) {
    const passo = 4.5, vao = 6.0;
    final larguraDia = passo * (aulasPorDia - 1);
    final traco = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    var x = 2.0;
    for (var d = 0; d < limiteFaltas ~/ aulasPorDia; d++) {
      final usadas = (faltas - d * aulasPorDia).clamp(0, aulasPorDia);
      for (var t = 0; t < aulasPorDia; t++) {
        traco.color = t < usadas ? ligado : vazio;
        canvas.drawLine(
          Offset(x + t * passo, 2),
          Offset(x + t * passo, size.height - 2),
          traco,
        );
      }
      if (usadas == aulasPorDia) {
        canvas.drawLine(
          Offset(x - 3, size.height - 4),
          Offset(x + larguraDia + 3, 4),
          Paint()
            ..color = risco
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      x += larguraDia + passo + vao;
    }
  }

  @override
  bool shouldRepaint(_TracinhosPainter old) =>
      old.faltas != faltas || old.ligado != ligado || old.vazio != vazio;
}

/// Revela o filho da esquerda para a direita, como se fosse escrito na hora.
class EscritoALapis extends StatelessWidget {
  const EscritoALapis({super.key, required this.child, this.ordem = 0});
  final Widget child;
  final int ordem;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final espera = 250 + ordem * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: espera + 700),
      builder: (context, t, filho) {
        final total = espera + 700;
        final p = ((t * total - espera) / 700).clamp(0.0, 1.0);
        return ClipRect(
          clipper: _Revelar(Curves.easeInOutCubic.transform(p)),
          child: filho,
        );
      },
      child: child,
    );
  }
}

class _Revelar extends CustomClipper<Rect> {
  _Revelar(this.fracao);
  final double fracao;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fracao, size.height);

  @override
  bool shouldReclip(_Revelar old) => old.fracao != fracao;
}

/// Cartao "folha" com titulo de secao, usado no boletim e no desempenho.
class Folha extends StatelessWidget {
  const Folha({super.key, this.titulo, this.legenda, required this.child});
  final String? titulo;
  final String? legenda;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (legenda != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  legenda!,
                  style: TextStyle(fontSize: 13, color: c.lapis),
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
