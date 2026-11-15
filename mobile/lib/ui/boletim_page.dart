import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/portal.dart';
import '../domain/regras.dart';
import '../domain/resumo.dart';
import '../state/app_controller.dart';
import 'widgets/componentes.dart';
import 'widgets/materia_card.dart';

class BoletimPage extends StatelessWidget {
  const BoletimPage(this.app, {super.key});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final h = app.historico;
    final semestre = app.semestreAtual;
    final materias = semestre == null
        ? const <Analise>[]
        : analisarSemestre(semestre);
    final resumo = resumir(materias);
    final atualizado = semestre?.atualizadoEm;

    return RefreshIndicator(
      onRefresh: app.sincronizar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo(h?.aluno.nome).isEmpty
                          ? 'Aluno'
                          : titulo(h?.aluno.nome),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        titulo(h?.aluno.curso),
                        if (h?.aluno.ra.isNotEmpty ?? false)
                          'RA ${h!.aluno.ra}',
                      ].where((s) => s.isNotEmpty).join(', '),
                      style: TextStyle(fontSize: 14, color: c.texto2),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sincronizar todos os semestres',
                onPressed: app.sincronizando
                    ? null
                    : () => app.sincronizar(completo: true),
                icon: const Icon(Icons.history_rounded),
              ),
              IconButton(
                tooltip: 'Buscar notas de novo no portal',
                onPressed: app.sincronizando ? null : app.sincronizar,
                icon: app.sincronizando
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (h != null && h.semestres.isNotEmpty)
            _SeletorSemestres(
              codigos: [for (final s in h.semestres) s.codigo],
              ativo: app.periodo,
              aoSelecionar: app.selecionarPeriodo,
            ),
          const SizedBox(height: 20),
          Text(
            app.progresso != null && semestre == null
                ? app.progresso!
                : resumo.manchete,
            style: const TextStyle(
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${resumo.materias} matérias',
              if (resumo.semNota > 0) '${resumo.semNota} sem nota ainda',
              '${resumo.faltas} ${resumo.faltas == 1 ? 'falta' : 'faltas'} no semestre',
              if (app.progresso != null)
                app.progresso!
              else if (atualizado != null)
                'Atualizado ${quando(atualizado)}',
            ].join('  ·  '),
            style: TextStyle(fontSize: 13, color: c.texto2, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (app.demo)
            const Aviso('Demonstração com dados fictícios. Nada é salvo.'),
          if (app.erro case final erro?)
            Aviso(
              '${erro.mensagem}'
              '${atualizado != null ? ' Mostrando os dados salvos ${quando(atualizado)}.' : ''}',
              cor: c.critico,
              acao: erro.tipo == FalhaPortal.credenciais
                  ? 'Entrar de novo'
                  : 'Tentar de novo',
              aoAgir: erro.tipo == FalhaPortal.credenciais
                  ? app.sair
                  : app.sincronizar,
            ),
          if (app.novidades.isNotEmpty)
            Aviso(
              'Nota nova no portal:\n${app.novidades.join('\n')}',
              cor: c.tons[Tom.ok]!.cor,
              acao: 'Ok',
              aoAgir: app.dispensarNovidades,
            ),
          if (resumo.recado.isNotEmpty)
            Aviso(resumo.recado, cor: c.acento, etiqueta: 'Foco'),
          _IndicadoresBoletim(
            garantidas: resumo.garantidas,
            materias: resumo.materias,
            emAberto: materias
                .where((m) => !m.situacao.passou && !m.situacao.encerrada)
                .length,
            semNota: resumo.semNota,
            faltas: resumo.faltas,
          ),
          const SizedBox(height: 16),
          if (materias.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Nenhuma matéria neste semestre. Escolha outro semestre lá em cima.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.texto2),
              ),
            ),
          for (final m in materias)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MateriaCard(
                m,
                key: ValueKey('${semestre!.codigo}/${m.disciplina.chave}'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Notas precedidas por ≥ mostram o mínimo necessário em cada prova para fechar média ${fmt(notaMinimaAprovacao)}. Toque na matéria para simular.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.texto2),
          ),
        ],
      ),
    );
  }
}

class _IndicadoresBoletim extends StatelessWidget {
  const _IndicadoresBoletim({
    required this.garantidas,
    required this.materias,
    required this.emAberto,
    required this.semNota,
    required this.faltas,
  });

  final int garantidas;
  final int materias;
  final int emAberto;
  final int semNota;
  final int faltas;

  @override
  Widget build(BuildContext context) {
    final itens = [
      _IndicadorCard(
        rotulo: 'Garantidas',
        valor: '$garantidas',
        sufixo: ' de $materias',
      ),
      _IndicadorCard(rotulo: 'Em aberto', valor: '$emAberto'),
      _IndicadorCard(rotulo: 'Sem nota ainda', valor: '$semNota'),
      _IndicadorCard(
        rotulo: 'Faltas no semestre',
        valor: '$faltas',
        sufixo: ' ${faltas == 1 ? 'aula' : 'aulas'} · ${dias(faltas)}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return Row(
            children: [
              for (var i = 0; i < itens.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: itens[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: itens[0]),
                const SizedBox(width: 8),
                Expanded(child: itens[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: itens[2]),
                const SizedBox(width: 8),
                Expanded(child: itens[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _IndicadorCard extends StatelessWidget {
  const _IndicadorCard({
    required this.rotulo,
    required this.valor,
    this.sufixo,
  });

  final String rotulo;
  final String valor;
  final String? sufixo;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: c.texto2),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: valor,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: c.texto,
                  letterSpacing: -0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                children: [
                  if (sufixo != null)
                    TextSpan(
                      text: sufixo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: c.texto2,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeletorSemestres extends StatelessWidget {
  const _SeletorSemestres({
    required this.codigos,
    required this.ativo,
    required this.aoSelecionar,
  });

  final List<String> codigos;
  final String? ativo;
  final ValueChanged<String> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final grupos = agruparPorAno(codigos, (cod) => cod);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: grupos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final grupo = grupos[i];
          final anoAtivo = grupo.semestres.contains(ativo);
          return Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: anoAtivo
                  ? c.acento.withValues(alpha: 0.10)
                  : (i.isEven ? c.superficie : c.superficie2),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: anoAtivo
                    ? c.acento.withValues(alpha: 0.45)
                    : (i.isEven ? c.borda : c.bordaForte),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var j = 0; j < grupo.semestres.length; j++) ...[
                  if (j > 0) const SizedBox(width: 2),
                  _BotaoSemestre(
                    codigo: grupo.semestres[j],
                    selecionado: grupo.semestres[j] == ativo,
                    anoAtivo: anoAtivo,
                    aoTocar: () => aoSelecionar(grupo.semestres[j]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BotaoSemestre extends StatelessWidget {
  const _BotaoSemestre({
    required this.codigo,
    required this.selecionado,
    required this.anoAtivo,
    required this.aoTocar,
  });

  final String codigo;
  final bool selecionado;
  final bool anoAtivo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    final p = partesPeriodo(codigo);
    return Semantics(
      button: true,
      selected: selecionado,
      child: Material(
        color: selecionado ? c.texto : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Center(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(
                      text: p.ano,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: selecionado
                            ? c.fundo
                            : (anoAtivo ? c.texto : c.texto2),
                      ),
                    ),
                    if (p.semestre != null)
                      TextSpan(
                        text: '/${p.semestre}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: selecionado
                              ? c.fundo.withValues(alpha: 0.78)
                              : c.texto3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
