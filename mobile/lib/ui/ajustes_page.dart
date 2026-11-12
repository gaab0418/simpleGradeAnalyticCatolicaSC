import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/armazenamento.dart';
import '../state/app_controller.dart';
import 'widgets/caderno_widgets.dart';

class AjustesPage extends StatelessWidget {
  const AjustesPage(this.app, {super.key});
  final AppController app;

  Future<void> _confirmarSaida(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair e apagar dados?'),
        content: const Text(
          'A senha salva e todo o histórico de notas serão apagados deste '
          'aparelho. Nada muda no portal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair e apagar'),
          ),
        ],
      ),
    );
    if (ok ?? false) await app.sair();
  }

  @override
  Widget build(BuildContext context) {
    final c = Caderno.of(context);
    final sincronizado = app.sincronizadoEm;
    final legenda = TextStyle(fontSize: 13, color: c.lapis);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'Ajustes',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 16),
        Folha(
          titulo: 'Aparência',
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<TemaApp>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TemaApp.sistema, label: Text('Sistema')),
                ButtonSegment(value: TemaApp.claro, label: Text('Caderno')),
                ButtonSegment(value: TemaApp.escuro, label: Text('Lousa')),
              ],
              selected: {app.prefs.tema},
              onSelectionChanged: (s) => app.definirTema(s.first),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Folha(
          titulo: 'Segurança',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: app.prefs.biometria && app.biometriaDisponivel,
                onChanged: app.biometriaDisponivel && !app.demo
                    ? app.definirBiometria
                    : null,
                title: const Text('Pedir digital ou rosto ao abrir'),
                subtitle: Text(
                  app.biometriaDisponivel
                      ? 'Trava o app sempre que ele sai da tela.'
                      : 'Este aparelho não tem bloqueio de tela configurado.',
                  style: legenda,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Usuário e senha ficam no cofre do sistema (Android Keystore / '
                'Keychain do iOS) e só são enviados para o portal da Católica. '
                'As notas ficam na área privada do app, fora do backup.',
                style: legenda.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Folha(
          titulo: 'Dados',
          legenda: app.demo
              ? 'Modo demonstração: dados fictícios.'
              : sincronizado == null
              ? 'Ainda não sincronizado.'
              : 'Última consulta ao portal: ${quando(sincronizado)}.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: app.sincronizando || app.demo
                    ? null
                    : () => app.sincronizar(completo: true),
                icon: const Icon(Icons.sync),
                label: Text(
                  app.sincronizando
                      ? (app.progresso ?? 'Sincronizando…')
                      : 'Baixar todos os semestres de novo',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No dia a dia só o semestre em andamento é atualizado; os '
                'encerrados não mudam mais.',
                style: legenda,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: app.demo ? app.sair : () => _confirmarSaida(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.canetaVermelha,
                ),
                icon: const Icon(Icons.logout),
                label: Text(
                  app.demo ? 'Sair da demonstração' : 'Sair e apagar dados',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Boletim Católica SC · feito por gaab0418\n'
          'App não oficial, sem vínculo com a Católica SC ou a TOTVS.',
          textAlign: TextAlign.center,
          style: legenda.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
