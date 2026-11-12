import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/regras.dart';
import 'caderno_widgets.dart';

/// Uma materia no boletim. Tocar abre o simulador "E se eu tirar...".
class MateriaCard extends StatefulWidget {
  const MateriaCard(this.analise, {super.key, this.ordem = 0});
  final Analise analise;

  /// Posicao na lista, para escalonar a animacao das notas a lapis.
  final int ordem;

  @override
  State<MateriaCard> createState() => _MateriaCardState();
}

class _MateriaCardState extends State<MateriaCard> {
  bool _aberta = false;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    final a = widget.analise;
    final d = a.disciplina;
    final (:nome, :sufixo) = nomeMateria(d.nomeBruto);

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
                              style: TextStyle(fontSize: 13, color: c.lapis),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: _aberta ? 'Fechar simulador' : 'Abrir simulador',
                        child: AnimatedRotation(
                          turns: _aberta ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more, color: c.lapis),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(child: _nota(c, a, i)),
                      Expanded(
                        child: _Celula(
                          rotulo: 'Soma',
                          child: Text(
                            a.lancadas > 0 ? fmt(a.soma) : '–',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TracinhosDeFalta(a.faltas),
                      const Spacer(),
                      MarcaTexto(a.situacao.rotulo, tom: a.situacao.tom),
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
                ? _Detalhes(a)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _nota(Caderno c, Analise a, int i) {
    final rotulo = 'N${i + 1}';
    final nota = a.disciplina.notas[i];
    if (nota != null) {
      return _Celula(
        rotulo: rotulo,
        child: Text(
          fmt(nota),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: nota < notaMinimaAprovacao ? c.canetaVermelha : c.tinta,
          ),
        ),
      );
    }
    final precisa = a.precisa;
    if (a.situacao.encerrada || a.situacao.passou || precisa == null) {
      return _Celula(
        rotulo: rotulo,
        semantica: '$rotulo sem nota',
        child: Text('–', style: TextStyle(fontSize: 17, color: c.lapis)),
      );
    }
    return _Celula(
      rotulo: rotulo,
      semantica:
          '$rotulo ainda sem nota; precisa de pelo menos ${fmt(precisa)}',
      child: EscritoALapis(
        ordem: widget.ordem * 2 + i,
        child: Text(
          '≥${fmt(precisa)}',
          style: c.mao.copyWith(
            fontSize: 19,
            height: 1.1,
            color: precisa > notaMaxima ? c.canetaVermelha : c.lapis,
          ),
        ),
      ),
    );
  }
}

class _Celula extends StatelessWidget {
  const _Celula({required this.rotulo, required this.child, this.semantica});
  final String rotulo;
  final Widget child;
  final String? semantica;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    final coluna = Column(
      children: [
        SizedBox(height: 26, child: Center(child: child)),
        Text(rotulo, style: TextStyle(fontSize: 11, color: c.lapis)),
      ],
    );
    return semantica == null
        ? MergeSemantics(child: coluna)
        : Semantics(label: semantica, excludeSemantics: true, child: coluna);
  }
}

class _Detalhes extends StatefulWidget {
  const _Detalhes(this.analise);
  final Analise analise;

  @override
  State<_Detalhes> createState() => _DetalhesState();
}

class _DetalhesState extends State<_Detalhes> {
  /// Palpite por indice de nota ainda nao lancada.
  late final Map<int, double> _palpites = () {
    final a = widget.analise;
    final inicial = (a.precisa ?? notaMinimaAprovacao).clamp(0, notaMaxima);
    return {
      for (var i = 0; i < 3; i++)
        if (a.disciplina.notas[i] == null) i: (inicial * 2).ceil() / 2,
    };
  }();

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    final a = widget.analise;
    final d = a.disciplina;
    const h = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    const p = TextStyle(fontSize: 15, height: 1.45);

    final faltasTxt = a.faltas > limiteFaltas
        ? 'Você passou do limite: ${a.faltas} faltas de $limiteFaltas permitidas.'
        : a.faltas == 0
        ? 'Nenhuma falta até agora. Dá para faltar até ${dias(a.faltasRestantes)} antes de reprovar.'
        : 'Você faltou ${dias(a.faltas)} (${a.faltas} aulas). Ainda pode faltar ${dias(a.faltasRestantes)} antes de reprovar.';

    final List<Widget> notas;
    if (a.restantes == 0 || a.situacao.encerrada) {
      notas = [
        const Text('Notas', style: h),
        const SizedBox(height: 6),
        Text(
          d.mediaFinal != null
              ? 'Média final ${fmt(d.mediaFinal!)}, situação no portal: ${d.situacao}.'
              : 'Todas as notas lançadas. Soma ${fmt(a.soma)} de ${somaAprovacao.toInt()}.',
          style: p,
        ),
      ];
    } else {
      final sim = simular(a, _palpites.values);
      notas = [
        const Text('E se eu tirar…', style: h),
        for (final MapEntry(key: i, value: v) in _palpites.entries)
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  'N${i + 1}',
                  style: TextStyle(fontSize: 14, color: c.lapis),
                ),
              ),
              Expanded(
                child: Slider(
                  value: v,
                  max: notaMaxima,
                  divisions: 20,
                  semanticFormatterCallback: (v) => 'N${i + 1}: ${fmt(v)}',
                  onChanged: (novo) => setState(() => _palpites[i] = novo),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  fmt(v),
                  textAlign: TextAlign.right,
                  style: c.mao.copyWith(fontSize: 20, color: c.tinta),
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text('Soma ${fmt(sim.soma)}:', style: p),
            MarcaTexto(
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
        border: Border(top: BorderSide(color: c.linha)),
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
            style: TextStyle(fontSize: 13, color: c.lapis),
          ),
        ],
      ),
    );
  }
}
