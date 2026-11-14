// Controller + telas, com portal, cofre e disco falsos.
import 'package:boletim_catolica/app.dart';
import 'package:boletim_catolica/core/theme.dart';
import 'package:boletim_catolica/data/armazenamento.dart';
import 'package:boletim_catolica/data/biometria.dart';
import 'package:boletim_catolica/data/portal.dart';
import 'package:boletim_catolica/domain/models.dart';
import 'package:boletim_catolica/domain/regras.dart';
import 'package:boletim_catolica/state/app_controller.dart';
import 'package:boletim_catolica/ui/boletim_page.dart';
import 'package:boletim_catolica/ui/desempenho_page.dart';
import 'package:boletim_catolica/ui/widgets/componentes.dart';
import 'package:boletim_catolica/ui/widgets/materia_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
  double? nota4,
  String sit = 'Matriculado',
}) => Disciplina(
  chave: chave,
  codTurma: 'T',
  codDisc: chave,
  nomeBruto: 'MATÉRIA $chave - $chave',
  situacao: sit,
  notas: notas,
  nota4: nota4,
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

  test('atualizar pula semestre encerrado e avisa de nota nova (incluindo N4)', () async {
    final app = novoApp();
    await app.iniciar();
    await app.entrar('aluno', 'ok', lembrar: true);
    portal.consultas.clear();
    portal.dados['202623'] = [
      _d('B', [7, 9.5, null], nota4: 8.5),
    ];

    await app.sincronizar();
    expect(portal.consultas, ['202623']);
    expect(app.novidades, [
      'N2 de Matéria B: 9,5',
      'N4 de Matéria B: 8,5',
    ]);

    portal.consultas.clear();
    await app.sincronizar(completo: true);
    expect(portal.consultas, ['202611', '202623']);
    expect(app.novidades, isEmpty);
  });

  test('cache persistente de semestres passados sobrevive a sair e re-login', () async {
    portal.dados = {
      '202511': [
        // Ainda como Matriculado no portal, mas de ano anterior -> consolidado.
        _d('OLD', [6, 7, null]),
      ],
      '202611': [
        _d('A', [8, 8, 8], sit: 'Aprovado'),
      ],
      '202623': [
        _d('B', [7, null, null]),
      ],
    };

    final app = novoApp();
    await app.iniciar();
    await app.entrar(' Aluno ', 'ok', lembrar: true);
    expect(portal.consultas, ['202511', '202611', '202623']);

    // Sair apaga historico.v1, mas preserva o cache de semestres consolidados.
    await app.sair();
    expect(await ArmazenamentoLocal().lerHistorico(), isNull);
    expect(
      (await ArmazenamentoLocal().lerSemestresPassados('aluno')).map(
        (s) => s.codigo,
      ),
      unorderedEquals(['202511', '202611']),
    );

    // Novo login com o mesmo usuario (normalizado) pula 202511 e 202611.
    portal.consultas.clear();
    final app2 = novoApp();
    await app2.iniciar();
    await app2.entrar('aluno', 'ok', lembrar: true);
    expect(portal.consultas, ['202623']);
    expect(app2.historico!.semestres.length, 3);

    // Usuario diferente nao reutiliza cache do primeiro usuario.
    portal.consultas.clear();
    await app2.sair();
    await app2.entrar('outro', 'ok', lembrar: true);
    expect(portal.consultas, ['202511', '202611', '202623']);
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

  testWidgets('demonstração: entrada, boletim, simulador N4, desempenho e ajustes', (t) async {
    final app = novoApp();
    await t.pumpWidget(BoletimApp(app));
    await t.runAsync(app.iniciar);
    await t.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Compiladores'), findsOneWidget);
    expect(find.text('Limite de faltas'), findsOneWidget);
    expect(find.text('17/20'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);

    final demo = find.text('Ver uma demonstração sem conta');
    await t.ensureVisible(demo);
    await t.tap(demo);
    await t.pumpAndSettle();

    expect(find.text('1 de 6 matérias garantidas'), findsOneWidget);
    expect(find.text('Fora de alcance'), findsOneWidget);
    expect(find.text('Foco'), findsOneWidget);
    expect(find.text('Garantidas'), findsWidgets);
    expect(find.text('Em aberto'), findsOneWidget);
    expect(find.text('Sem nota ainda'), findsOneWidget);
    expect(find.text('Faltas no semestre'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);

    // Abre o simulador da materia mais urgente e exercita presets e N4.
    await t.dragUntilVisible(
      find.text('Empreendedorismo'),
      find.byType(BoletimPage),
      const Offset(0, -150),
    );
    await t.tap(find.text('Empreendedorismo'));
    await t.pumpAndSettle();
    expect(find.text('E se eu tirar…'), findsOneWidget);
    expect(find.text('Mínimo'), findsOneWidget);
    expect(find.text('Média 8'), findsOneWidget);
    expect(find.text('Tudo 10'), findsOneWidget);
    expect(find.textContaining('N4'), findsWidgets);
    expect(find.textContaining('faltariam'), findsOneWidget);

    await t.dragUntilVisible(
      find.text('Tudo 10'),
      find.byType(BoletimPage),
      const Offset(0, -120),
    );
    await t.tap(find.text('Tudo 10'));
    await t.pumpAndSettle();

    // Volta ao topo e verifica BlocoN4 oficial em 2025/1 (Probabilidade e Estatística).
    await t.dragUntilVisible(
      find.text('2025/1'),
      find.byType(BoletimPage),
      const Offset(0, 300),
    );
    await t.ensureVisible(find.text('2025/1'));
    await t.tap(find.text('2025/1'));
    await t.pumpAndSettle();
    await t.dragUntilVisible(
      find.text('Probabilidade e Estatística'),
      find.byType(BoletimPage),
      const Offset(0, -200),
    );
    expect(find.text('Probabilidade e Estatística'), findsOneWidget);
    expect(find.byType(BlocoN4), findsOneWidget);

    await t.tap(find.text('Desempenho'));
    await t.pumpAndSettle();
    expect(find.text('Média geral'), findsOneWidget);
    await t.dragUntilVisible(
      find.text('Média por semestre'),
      find.byType(DesempenhoPage),
      const Offset(0, -250),
    );
    expect(find.text('Média por semestre'), findsOneWidget);
    await t.dragUntilVisible(
      find.text('Maiores médias'),
      find.byType(DesempenhoPage),
      const Offset(0, -300),
    );
    expect(find.text('Maiores médias'), findsOneWidget);
    await t.dragUntilVisible(
      find.text('Menores médias'),
      find.byType(DesempenhoPage),
      const Offset(0, -300),
    );
    expect(find.text('Menores médias'), findsOneWidget);

    await t.tap(find.text('Ajustes'));
    await t.pumpAndSettle();
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Paleta'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('MateriaCard exibe selo Em Risco e simula N4 com BlocoN4', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: temaDoApp(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: MateriaCard(analisar(_d('RIS', [5, 5, null]))),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Em Risco'), findsOneWidget);
    expect(find.byType(BlocoN4), findsNothing);

    await t.tap(find.text('Matéria Ris'));
    await t.pumpAndSettle();

    // Arrasta o slider de N4 para ativar a substituicao simulada com BlocoN4.
    await t.drag(find.byType(Slider).last, const Offset(150, 0));
    await t.pumpAndSettle();
    expect(find.byType(BlocoN4), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
