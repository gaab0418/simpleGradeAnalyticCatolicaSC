import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../domain/desempenho.dart';
import '../domain/regras.dart';
import '../state/app_controller.dart';
import 'widgets/caderno_widgets.dart';

/// Dashboard: como o aluno vem se saindo ao longo do curso.
class DesempenhoPage extends StatelessWidget {
  const DesempenhoPage(this.app, {super.key});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    final h = app.historico;
    final d = h == null ? null : Desempenho(h);

    if (d == null || d.vazio) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'A análise aparece quando houver pelo menos uma matéria com as três notas lançadas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.lapis),
          ),
        ),
      );
    }

    final media = d.mediaGeral!;
    final t = d.tendencia;
    final melhores = d.melhores();
    final piores = d.piores();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Desempenho no curso',
          style: TextStyle(fontSize: 14, color: c.lapis),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fmt(media),
              style: const TextStyle(
                fontSize: 64,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'média geral',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (t != null)
                      Row(
                        children: [
                          Icon(
                            t >= 0 ? Icons.north_east : Icons.south_east,
                            size: 15,
                            color: c.lapis,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${t >= 0 ? '+' : '−'}${fmt(t.abs())} no último semestre',
                              style: TextStyle(fontSize: 13, color: c.lapis),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Numero(
                  '${(d.taxaAprovacao! * 100).round()}%',
                  'de aprovação',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Numero('${d.concluidas.length}', 'matérias concluídas'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Numero(
                  dias(d.faltasTotais).split(' ').first,
                  'dias de falta',
                ),
              ),
            ],
          ),
        ),
        if (d.anotacoes.isNotEmpty) ...[
          const SizedBox(height: 18),
          for (final (i, nota) in d.anotacoes.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Transform.rotate(
                angle: i.isEven ? -0.008 : 0.006,
                alignment: Alignment.centerLeft,
                child: Text(
                  nota,
                  style: c.mao.copyWith(
                    fontSize: 19,
                    height: 1.3,
                    color: c.canetaVermelha,
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 14),
        if (d.evolucao.length >= 2) ...[
          Folha(
            titulo: 'Evolução da média',
            legenda: 'Média das matérias em cada semestre. Tracejado: mínimo para aprovar (6).',
            child: _GraficoEvolucao(d.evolucao),
          ),
          const SizedBox(height: 12),
        ],
        if (d.mediaPorEtapa.every((v) => v != null)) ...[
          Folha(
            titulo: 'Ritmo dentro do semestre',
            legenda: 'Sua nota média em cada prova, somando todo o curso.',
            child: _GraficoBarras(
              valores: [for (final v in d.mediaPorEtapa) v!],
              rotulos: const ['N1', 'N2', 'N3'],
              maximo: notaMaxima,
              descricao: (i, v) => 'Média ${fmt(v)} na N${i + 1}',
            ),
          ),
          const SizedBox(height: 12),
        ],
        Folha(
          titulo: 'Como suas médias se distribuem',
          legenda: 'Quantidade de matérias concluídas em cada faixa de média.',
          child: _Distribuicao(d.distribuicao),
        ),
        const SizedBox(height: 12),
        if (d.semestres.length >= 2 && d.faltasTotais > 0) ...[
          Folha(
            titulo: 'Faltas por semestre',
            legenda: 'Total de aulas perdidas, somando todas as matérias.',
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
        Folha(titulo: 'Onde você brilha', child: _Ranking(melhores)),
        if (piores.isNotEmpty) ...[
          const SizedBox(height: 12),
          Folha(titulo: 'Onde foi mais difícil', child: _Ranking(piores)),
        ],
      ],
    );
  }
}

/// 2026/2 -> 26/2 (cabe no eixo).
String _curto(String rotulo) =>
    rotulo.length > 2 ? rotulo.substring(2) : rotulo;

TextStyle _eixo(Caderno c) => TextStyle(fontSize: 11, color: c.lapis);

class _Numero extends StatelessWidget {
  const _Numero(this.valor, this.rotulo);
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              rotulo,
              style: TextStyle(fontSize: 12, color: c.lapis, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraficoEvolucao extends StatelessWidget {
  const _GraficoEvolucao(this.semestres);
  final List<ResumoSemestre> semestres;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
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
                      FlLine(color: c.linha, strokeWidth: 1),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: notaMinimaAprovacao,
                      color: c.canetaVermelha,
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
                        FlLine(color: c.lapis, strokeWidth: 1),
                        const FlDotData(),
                      ),
                  ],
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => c.tinta,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${semestres[s.spotIndex].rotulo}\n',
                          TextStyle(fontSize: 12, color: c.papel),
                          children: [
                            TextSpan(
                              text:
                                  'média ${fmt(s.y)}${semestres[s.spotIndex].encerrado ? '' : ' (parcial)'}',
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
                      for (final (i, m) in medias.indexed)
                        FlSpot(i.toDouble(), m),
                    ],
                    color: c.tinta,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    // O trecho ate um semestre em andamento e so estimativa.
                    dashArray: null,
                    dotData: FlDotData(
                      getDotPainter: (spot, _, _, i) {
                        final parcial = !semestres[i].encerrado;
                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: parcial ? c.folha : c.tinta,
                          strokeWidth: 2,
                          strokeColor: parcial ? c.tinta : c.folha,
                        );
                      },
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
                    color: c.folha,
                    border: Border.all(color: c.tinta, width: 2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Semestre em andamento: média parcial das notas já lançadas.',
                    style: TextStyle(fontSize: 12, color: c.lapis),
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
    this.inteiro = false,
  });
  final List<double> valores;
  final List<String> rotulos;
  final String Function(int i, double v) descricao;
  final double? maximo;
  final bool inteiro;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
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
              border: Border(bottom: BorderSide(color: c.linha)),
            ),
            gridData: const FlGridData(show: false),
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
                        color: c.tinta,
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
                getTooltipColor: (_) => c.tinta,
                getTooltipItem: (group, i, rod, _) => BarTooltipItem(
                  descricao(i, rod.toY),
                  TextStyle(fontSize: 13, color: c.papel),
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
                      color: c.tinta,
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
    final c = Caderno.of(context);
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
                    style: TextStyle(fontSize: 13, color: c.lapis),
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
                          color: f.abaixoDaMedia ? c.canetaVermelha : c.tinta,
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
    final c = Caderno.of(context);
    return Column(
      children: [
        for (final m in materias)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
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
                        style: TextStyle(fontSize: 12, color: c.lapis),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  fmt(m.media),
                  style: c.mao.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: m.media < notaMinimaAprovacao
                        ? c.canetaVermelha
                        : c.tinta,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
