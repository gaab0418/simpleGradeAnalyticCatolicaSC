import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/armazenamento.dart';
import 'data/totvs_client_stub.dart'
    if (dart.library.io) 'data/totvs_client_io.dart';
import 'state/app_controller.dart';

/// `--dart-define=DEMO=true` abre direto na demonstracao (prints, apresentacao).
const _abrirNaDemo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppController(portal: criarPortal(), cofre: const CofreSeguro());
  runApp(BoletimApp(app));
  await app.iniciar();
  if (_abrirNaDemo && app.fase == Fase.deslogado) app.entrarDemo();
}
