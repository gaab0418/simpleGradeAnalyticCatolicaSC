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
                    selectedColor: c.texto,
                    backgroundColor: c.superficie,
                    side: BorderSide(color: c.borda),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: s.codigo == app.periodo ? c.fundo : c.texto2,
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
          if (resumo.recado.isNotEmpty) Aviso(resumo.recado, cor: c.acento),
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
            'Em cada nota que falta aparece o mínimo que você precisa tirar. Toque na matéria para simular.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.texto2),
          ),
        ],
      ),
    );
  }
}
