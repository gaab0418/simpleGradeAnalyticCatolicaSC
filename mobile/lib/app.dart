import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'data/armazenamento.dart';
import 'state/app_controller.dart';
import 'ui/ajustes_page.dart';
import 'ui/boletim_page.dart';
import 'ui/desempenho_page.dart';
import 'ui/login_page.dart';

class BoletimApp extends StatefulWidget {
  const BoletimApp(this.app, {super.key});
  final AppController app;

  @override
  State<BoletimApp> createState() => _BoletimAppState();
}

class _BoletimAppState extends State<BoletimApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) widget.app.aoSairDeCena();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'Boletim Católica SC',
        debugShowCheckedModeBanner: false,
        theme: temaDoApp(Brightness.light),
        darkTheme: temaDoApp(Brightness.dark),
        themeMode: switch (app.prefs.tema) {
          TemaApp.sistema => ThemeMode.system,
          TemaApp.claro => ThemeMode.light,
          TemaApp.escuro => ThemeMode.dark,
        },
        home: switch (app.fase) {
          Fase.iniciando => const _Tela(
            child: Center(child: CircularProgressIndicator()),
          ),
          Fase.deslogado => _Tela(child: LoginPage(app)),
          Fase.bloqueado => _Tela(child: _Bloqueio(app)),
          Fase.pronto => _Inicio(app),
        },
      ),
    );
  }
}

class _Tela extends StatelessWidget {
  const _Tela({required this.child, this.barra});
  final Widget child;
  final Widget? barra;

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: barra,
    body: SafeArea(
      child: Center(
        // Em tablet o conteudo nao estica alem de uma coluna confortavel.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: child,
        ),
      ),
    ),
  );
}

class _Inicio extends StatefulWidget {
  const _Inicio(this.app);
  final AppController app;

  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return _Tela(
      barra: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Boletim',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Desempenho',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Ajustes',
          ),
        ],
      ),
      child: switch (_aba) {
        0 => BoletimPage(app),
        1 => DesempenhoPage(app),
        _ => AjustesPage(app),
      },
    );
  }
}

class _Bloqueio extends StatefulWidget {
  const _Bloqueio(this.app);
  final AppController app;

  @override
  State<_Bloqueio> createState() => _BloqueioState();
}

class _BloqueioState extends State<_Bloqueio> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pedir();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _pedir();
  }

  void _pedir() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      widget.app.desbloquear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Paleta.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 44, color: c.texto2),
            const SizedBox(height: 16),
            const Text(
              'Boletim trancado',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.app.desbloquear,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Desbloquear'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.app.sair,
              child: const Text('Sair e apagar dados'),
            ),
          ],
        ),
      ),
    );
  }
}
