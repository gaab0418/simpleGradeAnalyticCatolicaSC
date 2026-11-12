import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/portal.dart';
import '../domain/regras.dart';
import '../domain/resumo.dart';
import '../state/app_controller.dart';
import 'widgets/materia_card.dart';

class BoletimPage extends StatelessWidget {
  const BoletimPage(this.app, {super.key});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
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
                      style: TextStyle(fontSize: 14, color: c.lapis),
                    ),
                  ],
                ),
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
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: h.semestres.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = h.semestres[i];
                  return ChoiceChip(
                    label: Text(rotuloPeriodo(s.codigo)),
                    selected: s.codigo == app.periodo,
                    showCheckmark: false,
                    selectedColor: c.tinta,
                    backgroundColor: c.folha,
                    side: BorderSide(color: c.linha),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: s.codigo == app.periodo ? c.papel : c.lapis,
                    ),
                    onSelected: (_) => app.selecionarPeriodo(s.codigo),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          Text(
            app.progresso != null && semestre == null
                ? app.progresso!
                : resumo.manchete,
            style: const TextStyle(
              fontSize: 28,
              height: 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          if (resumo.recado.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Transform.rotate(
                angle: -0.01,
                alignment: Alignment.centerLeft,
                child: Text(
                  resumo.recado,
                  style: c.mao.copyWith(
                    fontSize: 21,
                    height: 1.3,
                    color: c.canetaVermelha,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
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
            style: TextStyle(fontSize: 13, color: c.lapis, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (app.demo)
            const _Aviso(
              icone: Icons.science_outlined,
              texto: 'Modo demonstração: estes dados são fictícios e nada é salvo.',
            ),
          if (app.erro case final erro?)
            _Aviso(
              icone: Icons.cloud_off_outlined,
              destaque: true,
              texto:
                  '${erro.mensagem}'
                  '${atualizado != null ? ' Mostrando os dados salvos ${quando(atualizado)}.' : ''}',
              acao: erro.tipo == FalhaPortal.credenciais
                  ? 'Entrar de novo'
                  : 'Tentar de novo',
              aoAgir: erro.tipo == FalhaPortal.credenciais
                  ? app.sair
                  : app.sincronizar,
            ),
          if (app.novidades.isNotEmpty)
            _Aviso(
              icone: Icons.auto_awesome_outlined,
              texto: 'Nota nova no portal!\n${app.novidades.join('\n')}',
              acao: 'Ok',
              aoAgir: app.dispensarNovidades,
            ),
          if (materias.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Nenhuma matéria neste semestre. Escolha outro semestre lá em cima.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.lapis),
              ),
            ),
          for (final (i, m) in materias.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MateriaCard(
                m,
                ordem: i,
                key: ValueKey('${semestre!.codigo}/${m.disciplina.chave}'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Faltou uma nota? Ela aparece a lápis com o mínimo que você precisa tirar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.lapis),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icone,
    required this.texto,
    this.acao,
    this.aoAgir,
    this.destaque = false,
  });
  final IconData icone;
  final String texto;
  final String? acao;
  final VoidCallback? aoAgir;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: c.folha,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: destaque ? c.canetaVermelha : c.linha),
      ),
      child: Row(
        children: [
          Icon(icone, size: 20, color: destaque ? c.canetaVermelha : c.lapis),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(texto, style: const TextStyle(fontSize: 14)),
            ),
          ),
          if (acao != null)
            TextButton(onPressed: aoAgir, child: Text(acao!))
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
