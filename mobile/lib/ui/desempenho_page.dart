import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../domain/desempenho.dart';
import '../domain/regras.dart';
import '../state/app_controller.dart';
import 'widgets/componentes.dart';

/// Dashboard: como o aluno vem se saindo ao longo do curso.
class DesempenhoPage extends StatelessWidget {
  const DesempenhoPage(this.app, {super.key});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final h = app.historico;
    final d = h == null ? null : Desempenho(h);

    if (d == null || d.vazio) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sem notas suficientes ainda',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.texto,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A análise aparece quando houver pelo menos uma matéria com as três notas lançadas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.texto2),
              ),
            ],
          ),
        ),
      );
    }

    final media = d.mediaGeral!;
    final t = d.tendencia;
    final melhores = d.melhores();
    final piores = d.piores();
    final tomTendencia = t == null
        ? null
        : c.tons[t >= 0 ? Tom.ok : Tom.critico]!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'Desempenho no curso',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Calculado com as ${d.concluidas.length} matérias que já têm resultado definitivo.',
          style: TextStyle(fontSize: 13.5, color: c.texto2),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.superficie,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borda),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Média geral',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.texto2,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    fmt(media),
                    style: const TextStyle(
                      fontSize: 44,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (t != null && tomTendencia != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: tomTendencia.fundo,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(11),
                          bottomRight: Radius.circular(6),
                          bottomLeft: Radius.circular(11),
                        ),
                        border: Border.all(
                          color: tomTendencia.cor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            t >= 0 ? Icons.north_east : Icons.south_east,
                            size: 14,
                            color: tomTendencia.cor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${t >= 0 ? '+' : '−'}${fmt(t.abs())} no último semestre',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: tomTendencia.cor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Numero(
                        '${(d.taxaAprovacao! * 100).round()}%',
                        'Aprovação',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Numero(
                        '${d.concluidas.length}',
                        'Matérias concluídas',
                        subtitulo: '${d.aprovadas} aprovadas',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Numero(
                        '${d.faltasTotais}',
                        'Faltas no curso',
                        subtitulo:
                            '${d.faltasTotais == 1 ? 'aula' : 'aulas'} · ${dias(d.faltasTotais)}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (d.anotacoes.isNotEmpty) ...[
          Painel(
            titulo: 'O que os números mostram',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final nota in d.anotacoes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 10),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: c.acento,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            nota,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (d.evolucao.length >= 2) ...[
          Painel(
            titulo: 'Média por semestre',
            legenda: 'Média das matérias em cada semestre. Tracejado: mínimo para aprovar (6).',
            child: _GraficoEvolucao(d.evolucao),
          ),
          const SizedBox(height: 12),
        ],
        if (d.mediaPorEtapa.every((v) => v != null)) ...[
          Painel(
            titulo: 'Nota média em cada prova',
            legenda: 'Ritmo dentro do semestre: sua média em N1, N2 e N3 ao longo do curso.',
            child: _GraficoBarras(
              valores: [for (final v in d.mediaPorEtapa) v!],
              rotulos: const ['N1', 'N2', 'N3'],
              maximo: notaMaxima,
              referencia: notaMinimaAprovacao,
              descricao: (i, v) => 'Média ${fmt(v)} na N${i + 1}',
            ),
          ),
          const SizedBox(height: 12),
        ],
        Painel(
          titulo: 'Matérias por faixa de média',
          legenda: 'Quantidade de matérias concluídas em cada faixa de nota.',
          child: _Distribuicao(d.distribuicao),
        ),
        const SizedBox(height: 12),
        if (d.semestres.length >= 2 && d.faltasTotais > 0) ...[
          Painel(
            titulo: 'Faltas por semestre (aulas)',
            legenda: 'Total de aulas perdidas, somando todas as matérias do período.',
            child: _GraficoBarras(
              valores: [for (final s in d.semestres) s.faltas.toDouble()],
              rotulos: [for (final s in d.semestres) _curto(s.rotulo)],
              descricao: (i, v) =>
                  '${v.toInt()} aulas (${dias(v.toInt())}) em ${d.semestres[i].rotulo}',
              inteiro: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Painel(titulo: 'Maiores médias', child: _Ranking(melhores)),
        if (piores.isNotEmpty) ...[
          const SizedBox(height: 12),
          Painel(titulo: 'Menores médias', child: _Ranking(piores)),
        ],
      ],
    );
  }
}

/// 2026/2 -> 26/2 (cabe no eixo).
String _curto(String rotulo) =>
    rotulo.length > 2 ? rotulo.substring(2) : rotulo;

TextStyle _eixo(Paleta c) => TextStyle(fontSize: 11, color: c.texto2);

class _Numero extends StatelessWidget {
  const _Numero(this.valor, this.rotulo, {this.subtitulo});
  final String valor;
  final String rotulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: c.superficie2.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: c.texto2, height: 1.25),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: c.texto,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.texto2),
            ),
          ],
        ],
      ),
    );
  }
}

class _GraficoEvolucao extends StatelessWidget {
  const _GraficoEvolucao(this.semestres);
  final List<ResumoSemestre> semestres;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final medias = [for (final s in semestres) s.media!];
    final minimo = medias.reduce((a, b) => a < b ? a : b);
    // Eixo comeca abaixo do menor valor (e sempre mostra a linha do 6).
    final base = (minimo < 5 ? minimo.floorToDouble() - 1 : 4.0).clamp(
      0.0,
      4.0,
    );
    final emAndamento = !semestres.last.encerrado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              'Gráfico de linha. ${[for (final s in semestres) '${s.rotulo}: ${fmt(s.media!)}'].join(', ')}.',
          child: SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minY: base,
                maxY: notaMaxima,
                minX: -0.25,
                maxX: semestres.length - 0.75,
                clipData: const FlClipData.none(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: c.borda, strokeWidth: 1),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: notaMinimaAprovacao,
                      color: c.critico,
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) => v % 2 != 0
                          ? const SizedBox.shrink()
                          : SideTitleWidget(
                              meta: meta,
                              child: Text('${v.toInt()}', style: _eixo(c)),
                            ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (v != i || i < 0 || i >= semestres.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _curto(semestres[i].rotulo),
                            style: _eixo(c),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 28,
                  getTouchedSpotIndicator: (bar, idx) => [
                    for (final _ in idx)
                      TouchedSpotIndicatorData(
                        FlLine(color: c.texto2, strokeWidth: 1),
                        const FlDotData(),
                      ),
                  ],
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => c.texto,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        if (emAndamento &&
                            s.barIndex == 1 &&
                            s.x.round() < medias.length - 1)
                          null
                        else
                          LineTooltipItem(
                            '${semestres[s.x.round()].rotulo}\n',
                            TextStyle(fontSize: 12, color: c.fundo),
                            children: [
                              TextSpan(
                                text:
                                    'média ${fmt(s.y)}${semestres[s.x.round()].encerrado ? '' : ' (parcial)'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0;
                          i < (emAndamento ? medias.length - 1 : medias.length);
                          i++)
                        FlSpot(i.toDouble(), medias[i]),
                    ],
                    color: c.acento,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: (emAndamento ? medias.length - 1 : medias.length) >=
                          2,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.acento.withValues(alpha: 0.16),
                          c.acento.withValues(alpha: 0.01),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 4.5,
                        color: c.acento,
                        strokeWidth: 2,
                        strokeColor: c.superficie,
                      ),
                    ),
                  ),
                  if (emAndamento)
                    // O trecho ate o semestre em andamento e uma estimativa tracejada.
                    LineChartBarData(
                      spots: [
                        FlSpot(
                          (medias.length - 2).toDouble(),
                          medias[medias.length - 2],
                        ),
                        FlSpot((medias.length - 1).toDouble(), medias.last),
                      ],
                      color: c.acento,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dashArray: [5, 4],
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            c.acento.withValues(alpha: 0.08),
                            c.acento.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      dotData: FlDotData(
                        checkToShowDot: (spot, _) =>
                            spot.x.round() == medias.length - 1,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 4.5,
                          color: c.superficie,
                          strokeWidth: 2,
                          strokeColor: c.acento,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (emAndamento)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.superficie,
                    border: Border.all(color: c.acento, width: 2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ponto vazado e trecho tracejado: semestre em andamento (média parcial das notas já lançadas).',
                    style: TextStyle(fontSize: 12, color: c.texto2),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Barras de uma serie so (uma cor), com o valor em cima de cada barra.
class _GraficoBarras extends StatelessWidget {
  const _GraficoBarras({
    required this.valores,
    required this.rotulos,
    required this.descricao,
    this.maximo,
    this.referencia,
    this.inteiro = false,
  });
  final List<double> valores;
  final List<String> rotulos;
  final String Function(int i, double v) descricao;
  final double? maximo;
  final double? referencia;
  final bool inteiro;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final maior = valores.reduce((a, b) => a > b ? a : b);
    final teto = maximo ?? (maior <= 0 ? 1 : maior * 1.2);
    String txt(double v) => inteiro ? '${v.toInt()}' : fmt(v);

    return Semantics(
      label:
          'Gráfico de barras. ${[for (final (i, v) in valores.indexed) '${rotulos[i]}: ${txt(v)}'].join(', ')}.',
      child: SizedBox(
        height: 170,
        child: BarChart(
          BarChartData(
            maxY: teto,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: c.borda)),
            ),
            gridData: const FlGridData(show: false),
            extraLinesData: referencia == null
                ? null
                : ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: referencia!,
                        color: c.critico,
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 4, bottom: 2),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: c.critico,
                          ),
                          labelResolver: (_) => fmt(referencia!),
                        ),
                      ),
                    ],
                  ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              // O valor de cada barra fica como titulo de cima.
              topTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      txt(valores[v.toInt()]),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.texto,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(rotulos[v.toInt()], style: _eixo(c)),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => c.texto,
                getTooltipItem: (group, i, rod, _) => BarTooltipItem(
                  descricao(i, rod.toY),
                  TextStyle(fontSize: 13, color: c.fundo),
                ),
              ),
            ),
            barGroups: [
              for (final (i, v) in valores.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: v,
                      width: valores.length > 5 ? 20 : 32,
                      color: c.acento,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faixas de media em barras horizontais; a faixa abaixo de 6 leva rotulo e
/// cor de alerta (nunca so a cor).
class _Distribuicao extends StatelessWidget {
  const _Distribuicao(this.faixas);
  final List<FaixaNotas> faixas;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final maior = faixas
        .map((f) => f.quantidade)
        .reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final f in faixas.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    f.rotulo,
                    style: TextStyle(fontSize: 13, color: c.texto2),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 16,
                        width: maior == 0
                            ? 0
                            : box.maxWidth * f.quantidade / maior,
                        decoration: BoxDecoration(
                          color: f.abaixoDaMedia ? c.critico : c.acento,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${f.quantidade}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Ranking extends StatelessWidget {
  const _Ranking(this.materias);
  final List<MateriaRanqueada> materias;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Column(
      children: [
        for (final m in materias)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.nome,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            m.periodo,
                            style: TextStyle(fontSize: 12, color: c.texto2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      fmt(m.media),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: m.media < notaMinimaAprovacao
                            ? c.critico
                            : c.texto,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (m.media / notaMaxima).clamp(0.0, 1.0),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: c.superficie2,
                  color: m.media < notaMinimaAprovacao ? c.critico : c.acento,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
