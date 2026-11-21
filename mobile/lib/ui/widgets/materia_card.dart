import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/regras.dart';
import 'componentes.dart';

/// Uma materia no boletim. Tocar abre o simulador "E se eu tirar...".
class MateriaCard extends StatefulWidget {
  const MateriaCard(this.analise, {super.key});
  final Analise analise;

  @override
  State<MateriaCard> createState() => _MateriaCardState();
}

class _MateriaCardState extends State<MateriaCard> {
  bool _aberta = false;
  late Map<int, double> _palpites;
  double? _simN4;

  @override
  void initState() {
    super.initState();
    _palpites = _palpitesIniciais(widget.analise);
  }

  @override
  void didUpdateWidget(covariant MateriaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dAntes = oldWidget.analise.disciplina;
    final dAgora = widget.analise.disciplina;
    if (dAntes.nota4 != dAgora.nota4 || !_mesmasNotas(dAntes.notas, dAgora.notas)) {
      _palpites = _palpitesIniciais(widget.analise);
      _simN4 = null;
    }
  }

  static bool _mesmasNotas(List<double?> a, List<double?> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static double _passoMeio(double v) =>
      ((v * 2).ceil() / 2).clamp(0.0, notaMaxima);

  static Map<int, double> _palpitesIniciais(Analise a) {
    final inicial = _passoMeio(a.precisa ?? notaMinimaAprovacao);
    return {
      for (var i = 0; i < 3; i++)
        if (a.notasEfetivas[i] == null) i: inicial,
    };
  }

  bool _podeSimular(Analise a) {
    final d = a.disciplina;
    final oficial = d.situacao.toLowerCase();
    if (d.faltas > a.limiteFaltas ||
        oficial.startsWith('aprov') ||
        oficial.startsWith('reprov')) {
      return false;
    }
    return a.restantes > 0 || a.precisaN4 != null;
  }

  bool _podeSimularN4(Analise a) =>
      _podeSimular(a) && a.disciplina.nota4 == null && !a.situacao.passou;

  void _aplicarAlvo(double alvo) {
    setState(() {
      if (_palpites.isNotEmpty) {
        final v = _passoMeio(alvo);
        for (final i in _palpites.keys) {
          _palpites[i] = v;
        }
        _simN4 = null;
      } else if (_podeSimularN4(widget.analise)) {
        _simN4 = _passoMeio(alvo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final a = widget.analise;
    final d = a.disciplina;
    final (:nome, :sufixo) = nomeMateria(d.nomeBruto);
    final podeSimular = _podeSimular(a);
    final sim = (_aberta && podeSimular)
        ? simular(a, _palpites.values, nota4: _simN4)
        : null;
    final temBlocoN4 =
        a.indiceSubstituido != null || (sim?.indiceSubstituido != null);
    final alturaCelula = temBlocoN4 ? 40.0 : 28.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _aberta = !_aberta),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            Text(
                              sufixo.isEmpty ? d.codDisc : sufixo,
                              style: TextStyle(fontSize: 13, color: c.texto2),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: _aberta ? 'Fechar simulador' : 'Abrir simulador',
                        child: AnimatedRotation(
                          turns: _aberta ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more, color: c.texto2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: _nota(c, a, i, sim, alturaCelula),
                        ),
                      Expanded(
                        child: _Celula(
                          rotulo: 'Soma',
                          altura: alturaCelula,
                          child: a.lancadas > 0
                              ? Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: fmt(a.soma),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      TextSpan(
                                        text: '/${somaAprovacao.toInt()}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400,
                                          color: c.texto3,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Text(
                                  '–',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: c.texto2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BarraDeFaltas(
                        a.faltas,
                        limite: a.limiteFaltas,
                        alerta: a.alertaFaltas,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Selo(a.situacao.rotulo, tom: a.situacao.tom),
                              if (a.precisaN4 != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 3,
                                    right: 2,
                                  ),
                                  child: Text(
                                    '≥${fmt(a.precisaN4!)} na N4',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: a.precisaN4! > notaMaxima
                                          ? c.critico
                                          : c.texto2,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                )
                              else if (a.situacao.encerrada &&
                                  d.mediaFinal != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 3,
                                    right: 2,
                                  ),
                                  child: Text(
                                    'média ${fmt(d.mediaFinal!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.texto3,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _aberta
                ? _Detalhes(
                    analise: a,
                    podeSimular: podeSimular,
                    podeSimularN4: _podeSimularN4(a),
                    palpites: _palpites,
                    simN4: _simN4,
                    simulacao: sim,
                    aoMudarPalpite: (i, v) => setState(() => _palpites[i] = v),
                    aoMudarN4: (v) => setState(() => _simN4 = v),
                    aoAplicarAlvo: _aplicarAlvo,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _nota(
    Paleta c,
    Analise a,
    int i,
    Simulacao? sim,
    double alturaCelula,
  ) {
    final rotulo = 'N${i + 1}';

    if (a.indiceSubstituido == i &&
        a.notaSubstituida != null &&
        a.nota4 != null) {
      return _Celula(
        rotulo: rotulo,
        altura: alturaCelula,
        semantica:
            '$rotulo substituída pela N4: de ${fmt(a.notaSubstituida!)} para ${fmt(a.nota4!)}',
        child: BlocoN4(
          notaAntiga: a.notaSubstituida,
          notaN4: a.nota4!,
          etapa: rotulo,
        ),
      );
    }

    if (sim != null &&
        sim.indiceSubstituido == i &&
        sim.notaSubstituida != null &&
        sim.nota4 != null) {
      return _Celula(
        rotulo: rotulo,
        altura: alturaCelula,
        semantica:
            '$rotulo simulada pela N4: de ${fmt(sim.notaSubstituida!)} para ${fmt(sim.nota4!)}',
        child: BlocoN4(
          notaAntiga: sim.notaSubstituida,
          notaN4: sim.nota4!,
          etapa: rotulo,
          simulada: true,
        ),
      );
    }

    final nota = a.notasEfetivas[i];
    if (nota != null) {
      return _Celula(
        rotulo: rotulo,
        altura: alturaCelula,
        child: Text(
          fmt(nota),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: nota < notaMinimaAprovacao ? c.critico : c.texto,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
    final precisa = a.precisa;
    if (a.situacao.encerrada || a.situacao.passou || precisa == null) {
      return _Celula(
        rotulo: rotulo,
        altura: alturaCelula,
        semantica: '$rotulo sem nota',
        child: Text('–', style: TextStyle(fontSize: 17, color: c.texto2)),
      );
    }
    return _Celula(
      rotulo: rotulo,
      altura: alturaCelula,
      semantica:
          '$rotulo ainda sem nota; precisa de pelo menos ${fmt(precisa)}',
      child: NotaPendenteBadge(precisa),
    );
  }
}

class _Celula extends StatelessWidget {
  const _Celula({
    required this.rotulo,
    required this.child,
    this.altura = 28,
    this.semantica,
  });
  final String rotulo;
  final Widget child;
  final double altura;
  final String? semantica;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final coluna = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: altura, child: Center(child: child)),
        const SizedBox(height: 2),
        Text(rotulo, style: TextStyle(fontSize: 11, color: c.texto2)),
      ],
    );
    return semantica == null
        ? MergeSemantics(child: coluna)
        : Semantics(label: semantica, excludeSemantics: true, child: coluna);
  }
}

class _Detalhes extends StatelessWidget {
  const _Detalhes({
    required this.analise,
    required this.podeSimular,
    required this.podeSimularN4,
    required this.palpites,
    required this.simN4,
    required this.simulacao,
    required this.aoMudarPalpite,
    required this.aoMudarN4,
    required this.aoAplicarAlvo,
  });

  final Analise analise;
  final bool podeSimular;
  final bool podeSimularN4;
  final Map<int, double> palpites;
  final double? simN4;
  final Simulacao? simulacao;
  final void Function(int indice, double valor) aoMudarPalpite;
  final ValueChanged<double?> aoMudarN4;
  final ValueChanged<double> aoAplicarAlvo;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final a = analise;
    final d = a.disciplina;
    const h = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    const p = TextStyle(fontSize: 15, height: 1.45);

    final faltasTxt = a.faltas > a.limiteFaltas
        ? 'Você passou do limite: ${a.faltas} faltas de ${a.limiteFaltas} permitidas.'
        : a.faltas == 0
        ? 'Nenhuma falta até agora. Dá para faltar até ${dias(a.faltasRestantes)} antes de reprovar.'
        : 'Você faltou ${dias(a.faltas)} (${a.faltas} aulas). Ainda pode faltar ${dias(a.faltasRestantes)} antes de reprovar.';

    final n4Explicacao = a.indiceSubstituido != null && a.nota4 != null
        ? 'N4 substitutiva: tirou ${fmt(a.nota4!)}, substituindo a N${a.indiceSubstituido! + 1} (${a.notaSubstituida != null ? fmt(a.notaSubstituida!) : '–'}).'
        : null;

    final List<Widget> notas;
    if (!podeSimular || simulacao == null) {
      notas = [
        const Text('Notas', style: h),
        const SizedBox(height: 6),
        Text(
          d.mediaFinal != null
              ? 'Média final ${fmt(d.mediaFinal!)}, situação no portal: ${d.situacao}.'
              : 'Todas as notas lançadas. Soma ${fmt(a.soma)} de ${somaAprovacao.toInt()}.',
          style: p,
        ),
        if (n4Explicacao != null) ...[
          const SizedBox(height: 6),
          Text(
            n4Explicacao,
            style: TextStyle(fontSize: 13.5, color: c.texto2, height: 1.4),
          ),
        ],
      ];
    } else {
      final sim = simulacao!;
      final somaMaxima = notaMaxima * d.notas.length;
      final pctSoma = (sim.soma / somaMaxima).clamp(0.0, 1.0);
      final pctMeta = somaAprovacao / somaMaxima;

      final double alvoMinimo;
      final double alvoMedia8;
      if (palpites.isNotEmpty) {
        alvoMinimo = a.precisa ?? notaMinimaAprovacao;
        alvoMedia8 = (24 - a.soma) / math.max(1, a.restantes);
      } else {
        final menor = a.notasEfetivas.whereType<double>().reduce(math.min);
        alvoMinimo = a.precisaN4 ?? notaMinimaAprovacao;
        alvoMedia8 = 24 - (a.soma - menor);
      }

      notas = [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: Text('E se eu tirar…', style: h)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _AtalhoSim('Mínimo', () => aoAplicarAlvo(alvoMinimo)),
                _AtalhoSim('Média 8', () => aoAplicarAlvo(alvoMedia8)),
                _AtalhoSim('Tudo 10', () => aoAplicarAlvo(notaMaxima)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (n4Explicacao != null) ...[
          Text(
            n4Explicacao,
            style: TextStyle(fontSize: 13.5, color: c.texto2, height: 1.4),
          ),
          const SizedBox(height: 8),
        ],
        for (final MapEntry(key: i, value: v) in palpites.entries)
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  'N${i + 1}',
                  style: TextStyle(fontSize: 14, color: c.texto2),
                ),
              ),
              Expanded(
                child: Slider(
                  value: v,
                  max: notaMaxima,
                  divisions: 20,
                  semanticFormatterCallback: (val) => 'N${i + 1}: ${fmt(val)}',
                  onChanged: (novo) => aoMudarPalpite(i, novo),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  fmt(v),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        if (podeSimularN4) ...[
          const SizedBox(height: 4),
          Divider(height: 16, color: c.borda),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'N4 (Recuperação — substitui a menor nota)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.texto2,
                      ),
                    ),
                    if (sim.indiceSubstituido != null &&
                        sim.notaSubstituida != null)
                      Text(
                        'Substituindo N${sim.indiceSubstituido! + 1} (${fmt(sim.notaSubstituida!)})',
                        style: TextStyle(fontSize: 12, color: c.acento),
                      ),
                  ],
                ),
              ),
              if (simN4 != null)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => aoMudarN4(null),
                  child: const Text('Limpar', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  'N4',
                  style: TextStyle(fontSize: 14, color: c.texto2),
                ),
              ),
              Expanded(
                child: Slider(
                  value: simN4 ?? 0.0,
                  max: notaMaxima,
                  divisions: 20,
                  semanticFormatterCallback: (val) => 'N4: ${fmt(val)}',
                  onChanged: (novo) => aoMudarN4(novo > 0 ? novo : null),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  simN4 == null ? '–' : fmt(simN4!),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        _BarraProgressoSim(
          pctSoma: pctSoma,
          pctMeta: pctMeta,
          passa: sim.passa,
        ),
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text.rich(
              TextSpan(
                style: p,
                children: [
                  const TextSpan(text: 'Soma '),
                  TextSpan(
                    text: fmt(sim.soma),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' de ${somaMaxima.toInt()}:'),
                ],
              ),
            ),
            Selo(
              sim.passa
                  ? 'passa com média ${fmt(sim.media)}'
                  : 'faltariam ${fmt(sim.faltariam)} pontos',
              tom: sim.passa ? Tom.ok : Tom.critico,
            ),
          ],
        ),
      ];
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borda)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...notas,
          const SizedBox(height: 16),
          const Text('Faltas', style: h),
          const SizedBox(height: 6),
          Text(faltasTxt, style: p),
          const SizedBox(height: 10),
          Text(
            'Disciplina ${d.codDisc}, turma ${d.codTurma}',
            style: TextStyle(fontSize: 13, color: c.texto2),
          ),
        ],
      ),
    );
  }
}

class _AtalhoSim extends StatelessWidget {
  const _AtalhoSim(this.rotulo, this.aoTocar);
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.superficie2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.bordaForte),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: c.texto2,
          ),
        ),
      ),
    );
  }
}

class _BarraProgressoSim extends StatelessWidget {
  const _BarraProgressoSim({
    required this.pctSoma,
    required this.pctMeta,
    required this.passa,
  });

  final double pctSoma;
  final double pctMeta;
  final bool passa;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final corBarra = passa ? c.tons[Tom.ok]!.cor : c.critico;
    return Semantics(
      label: 'Progresso da simulação em direção aos ${somaAprovacao.toInt()} pontos',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final metaX = (w * pctMeta - 1)
              .clamp(0.0, math.max(0.0, w - 2))
              .toDouble();
          return SizedBox(
            height: 13,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 7,
                  width: w,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: c.superficie2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.borda),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: w * pctSoma,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: corBarra,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: metaX,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: c.texto,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
