// Controller + telas, com portal, cofre e disco falsos.
import 'package:boletim_catolica/app.dart';
import 'package:boletim_catolica/data/armazenamento.dart';
import 'package:boletim_catolica/data/biometria.dart';
import 'package:boletim_catolica/data/portal.dart';
import 'package:boletim_catolica/domain/models.dart';
import 'package:boletim_catolica/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class CofreFalso implements CofreCredenciais {
  Credenciais? guardada;
  @override
  Future<Credenciais?> ler() async => guardada;
  @override
  Future<void> salvar(Credenciais c) async => guardada = c;
  @override
  Future<void> apagar() async => guardada = null;
}

class SemBiometria extends Biometria {
  @override
  Future<bool> disponivel() async => false;
}

Disciplina _d(
  String chave,
  List<double?> notas, {
  String sit = 'Matriculado',
}) => Disciplina(
  chave: chave,
  codTurma: 'T',
  codDisc: chave,
  nomeBruto: 'MATÉRIA $chave - $chave',
  situacao: sit,
  notas: notas,
  mediaFinal: sit == 'Aprovado' ? 8 : null,
);

class PortalFalso implements PortalGateway, PortalSessao {
  String senhaCerta = 'ok';
  bool offline = false;
  final consultas = <String>[];
  Map<String, List<Disciplina>> dados = {
    '202611': [
      _d('A', [8, 8, 8], sit: 'Aprovado'),
    ],
    '202623': [
      _d('B', [7, null, null]),
    ],
  };

  @override
  Future<PortalSessao> entrar(Credenciais c) async {
    if (offline) {
      throw const PortalException(
        FalhaPortal.rede,
        'Sem conexão com o portal.',
      );
    }
    if (c.senha != senhaCerta) {
      throw const PortalException(FalhaPortal.credenciais, 'Senha errada.');
    }
    return this;
  }

  @override
  Aluno get aluno => const Aluno(nome: 'FULANO', ra: '1', curso: 'CURSO');

  @override
  List<ContextoPeriodo> get contextos => [
    for (final cod in dados.keys)
      ContextoPeriodo(
        id: cod,
        codigo: cod,
        curso: 'CURSO',
        situacaoMatricula: '',
      ),
  ];

  @override
  Future<List<Disciplina>> disciplinas(ContextoPeriodo c) async {
    consultas.add(c.codigo);
    return dados[c.codigo]!;
  }

  @override
  void fechar() {}
}

void main() {
  late PortalFalso portal;
  late CofreFalso cofre;
  var agora = DateTime(2026, 11, 12, 10);

  AppController novoApp() => AppController(
    portal: portal,
    cofre: cofre,
    biometria: SemBiometria(),
    agora: () => agora,
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    portal = PortalFalso();
    cofre = CofreFalso();
    agora = DateTime(2026, 11, 12, 10);
  });

  test('login salva credenciais e histórico; reabrir usa o cache', () async {
    final app = novoApp();
    await app.iniciar();
    expect(app.fase, Fase.deslogado);

    expect(await app.entrar(' aluno ', 'ok', lembrar: true), isNull);
    expect(app.fase, Fase.pronto);
    expect(app.periodo, '202623');
    expect(cofre.guardada!.usuario, 'aluno');
    expect(portal.consultas, ['202611', '202623']);

    // Reabre 5 min depois: mostra o que esta salvo sem consultar o portal.
    portal.consultas.clear();
    agora = agora.add(const Duration(minutes: 5));
    final reaberto = novoApp();
    await reaberto.iniciar();
    expect(reaberto.fase, Fase.pronto);
    expect(reaberto.historico!.semestres.length, 2);
    expect(portal.consultas, isEmpty);
  });

  test('senha errada não salva nada', () async {
    final app = novoApp();
    await app.iniciar();
    expect(await app.entrar('aluno', 'errada', lembrar: true), 'Senha errada.');
    expect(app.fase, Fase.deslogado);
    expect(cofre.guardada, isNull);
  });

  test('sem "manter conectado" nada vai para o disco', () async {
    final app = novoApp();
    await app.iniciar();
    await app.entrar('aluno', 'ok', lembrar: false);
    expect(app.fase, Fase.pronto);
    expect(cofre.guardada, isNull);
    expect(await ArmazenamentoLocal().lerHistorico(), isNull);
  });

  test('atualizar pula semestre encerrado e avisa de nota nova', () async {
    final app = novoApp();
    await app.iniciar();
    await app.entrar('aluno', 'ok', lembrar: true);
    portal.consultas.clear();
    portal.dados['202623'] = [
      _d('B', [7, 9.5, null]),
    ];

    await app.sincronizar();
    expect(portal.consultas, ['202623']);
    expect(app.novidades, ['N2 de Matéria B: 9,5']);

    portal.consultas.clear();
    await app.sincronizar(completo: true);
    expect(portal.consultas, ['202611', '202623']);
    expect(app.novidades, isEmpty);
  });

  test('offline mantém os dados salvos e mostra o erro', () async {
    final app = novoApp();
    await app.iniciar();
    await app.entrar('aluno', 'ok', lembrar: true);
    portal.offline = true;
    await app.sincronizar();
    expect(app.erro!.tipo, FalhaPortal.rede);
    expect(app.historico!.semestres.length, 2);
  });

  test('sair apaga credenciais e histórico', () async {
    final app = novoApp();
    await app.iniciar();
    await app.entrar('aluno', 'ok', lembrar: true);
    await app.sair();
    expect(app.fase, Fase.deslogado);
    expect(cofre.guardada, isNull);
    expect(await ArmazenamentoLocal().lerHistorico(), isNull);
  });

  testWidgets('demonstração: boletim, simulador e desempenho', (t) async {
    final app = novoApp();
    await t.pumpWidget(BoletimApp(app));
    await t.runAsync(app.iniciar);
    await t.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);

    final demo = find.text('Ver uma demonstração sem conta');
    await t.ensureVisible(demo);
    await t.tap(demo);
    await t.pumpAndSettle();
    expect(find.text('1 de 6 matérias já garantidas.'), findsOneWidget);
    expect(find.text('Fora de alcance'), findsOneWidget);

    // Abre o simulador da materia mais urgente.
    await t.ensureVisible(find.text('Empreendedorismo'));
    await t.tap(find.text('Empreendedorismo'));
    await t.pumpAndSettle();
    expect(find.text('E se eu tirar…'), findsOneWidget);
    expect(find.textContaining('faltariam'), findsOneWidget);

    await t.tap(find.text('Desempenho'));
    await t.pumpAndSettle();
    expect(find.text('média geral'), findsOneWidget);
    expect(find.text('Evolução da média'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
