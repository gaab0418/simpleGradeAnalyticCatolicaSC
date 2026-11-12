import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../data/armazenamento.dart';
import '../data/biometria.dart';
import '../data/demo.dart';
import '../data/portal.dart';
import '../domain/models.dart';
import '../domain/regras.dart';

enum Fase { iniciando, deslogado, bloqueado, pronto }

/// Estado unico do app: sessao, historico local, sincronizacao e preferencias.
class AppController extends ChangeNotifier {
  AppController({
    required PortalGateway portal,
    required CofreCredenciais cofre,
    ArmazenamentoLocal? local,
    Biometria? biometria,
    DateTime Function() agora = DateTime.now,
  }) : this._(
         portal,
         cofre,
         local ?? ArmazenamentoLocal(),
         biometria ?? Biometria(),
         agora,
       );

  AppController._(
    this._portal,
    this._cofre,
    this._local,
    this._biometria,
    this._agora,
  );

  final PortalGateway _portal;
  final CofreCredenciais _cofre;
  final ArmazenamentoLocal _local;
  final Biometria _biometria;
  final DateTime Function() _agora;

  /// Abaixo disso, reabrir o app nao dispara nova consulta ao portal.
  static const _validadeCache = Duration(minutes: 15);

  Credenciais? _credenciais;

  /// Falso quando a pessoa pediu para nao manter a conta neste aparelho:
  /// nada (nem senha nem notas) vai para o disco.
  bool _persistir = true;
  bool _autenticando = false;

  Fase fase = Fase.iniciando;
  Historico? historico;
  String? periodo;
  Preferencias prefs = const Preferencias();
  bool biometriaDisponivel = false;
  bool demo = false;

  bool sincronizando = false;
  String? progresso;
  PortalException? erro;

  /// Notas que apareceram na ultima sincronizacao (ex.: "N2 de Compiladores: 8,5").
  List<String> novidades = const [];

  Semestre? get semestreAtual => historico?.semestre(periodo);

  DateTime? get sincronizadoEm {
    final datas = historico?.semestres.map((s) => s.atualizadoEm) ?? const [];
    return datas.isEmpty ? null : datas.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Future<void> iniciar() async {
    prefs = await _local.lerPreferencias();
    biometriaDisponivel = await _biometria.disponivel();
    _credenciais = await _lerCofre();
    if (_credenciais == null) {
      // Sem credencial nao ha como atualizar: nao deixa dado orfao no aparelho.
      await _local.apagarHistorico();
      _mudar(() => fase = Fase.deslogado);
      return;
    }
    historico = await _local.lerHistorico();
    periodo = _periodoInicial();
    if (prefs.biometria && biometriaDisponivel) {
      _mudar(() => fase = Fase.bloqueado);
    } else {
      _mudar(() => fase = Fase.pronto);
      _sincronizarSeVelho();
    }
  }

  Future<Credenciais?> _lerCofre() async {
    try {
      return await _cofre.ler();
    } catch (_) {
      // Cofre ilegivel (ex.: restauracao em outro aparelho): pede login de novo.
      return null;
    }
  }

  /// Faz login e a primeira carga. Devolve a mensagem de erro, ou `null`.
  Future<String?> entrar(
    String usuario,
    String senha, {
    required bool lembrar,
  }) async {
    final c = Credenciais(usuario.trim(), senha);
    _mudar(() {
      sincronizando = true;
      progresso = 'Entrando no portal…';
      erro = null;
    });
    try {
      final h = await _baixar(c, anterior: null, completo: true);
      _persistir = lembrar;
      if (lembrar) {
        await _cofre.salvar(c);
        await _local.salvarHistorico(h);
      }
      _credenciais = c;
      _mudar(() {
        demo = false;
        historico = h;
        periodo = _periodoInicial();
        novidades = const [];
        fase = Fase.pronto;
      });
      return null;
    } on PortalException catch (e) {
      return e.mensagem;
    } catch (_) {
      return 'Algo deu errado ao ler os dados do portal.';
    } finally {
      _mudar(() {
        sincronizando = false;
        progresso = null;
      });
    }
  }

  void entrarDemo() {
    _mudar(() {
      demo = true;
      historico = historicoDemo(_agora());
      periodo = _periodoInicial();
      erro = null;
      novidades = const [];
      fase = Fase.pronto;
    });
  }

  /// Atualiza o historico. Semestres ja encerrados so sao buscados de novo
  /// com [completo], porque nao mudam mais no portal.
  Future<void> sincronizar({bool completo = false}) async {
    if (sincronizando) return;
    final c = _credenciais;
    if (demo || c == null) {
      // Demonstracao: so simula o gesto de atualizar.
      if (demo) _mudar(() => historico = historicoDemo(_agora()));
      return;
    }
    _mudar(() {
      sincronizando = true;
      progresso = 'Entrando no portal…';
      erro = null;
    });
    try {
      final anterior = historico;
      final h = await _baixar(c, anterior: anterior, completo: completo);
      if (_persistir) await _local.salvarHistorico(h);
      _mudar(() {
        novidades = anterior == null ? const [] : _notasNovas(anterior, h);
        historico = h;
        if (h.semestre(periodo) == null) periodo = _periodoInicial();
      });
    } on PortalException catch (e) {
      _mudar(() => erro = e);
    } catch (_) {
      _mudar(
        () => erro = const PortalException(
          FalhaPortal.portal,
          'Algo deu errado ao ler os dados do portal.',
        ),
      );
    } finally {
      _mudar(() {
        sincronizando = false;
        progresso = null;
      });
    }
  }

  void _sincronizarSeVelho() {
    final ultima = sincronizadoEm;
    if (ultima == null || _agora().difference(ultima) > _validadeCache) {
      sincronizar();
    }
  }

  Future<Historico> _baixar(
    Credenciais c, {
    required Historico? anterior,
    required bool completo,
  }) async {
    final sessao = await _portal.entrar(c);
    try {
      if (sessao.contextos.isEmpty) {
        throw const PortalException(
          FalhaPortal.portal,
          'O portal não retornou nenhuma matrícula para este usuário.',
        );
      }
      // Um aluno pode ter mais de um contexto no mesmo periodo.
      final porPeriodo = <String, List<ContextoPeriodo>>{};
      for (final ctx in sessao.contextos) {
        porPeriodo.putIfAbsent(ctx.codigo, () => []).add(ctx);
      }
      final semestres = <Semestre>[];
      for (final MapEntry(key: codigo, value: ctxs) in porPeriodo.entries) {
        final guardado = anterior?.semestre(codigo);
        if (!completo && guardado != null && semestreEncerrado(guardado)) {
          semestres.add(guardado);
          continue;
        }
        _mudar(() => progresso = 'Buscando ${rotuloPeriodo(codigo)}…');
        final disciplinas = <String, Disciplina>{};
        for (final ctx in ctxs) {
          for (final d in await sessao.disciplinas(ctx)) {
            disciplinas.putIfAbsent(d.chave, () => d);
          }
        }
        semestres.add(
          Semestre(
            codigo: codigo,
            curso: ctxs.first.curso,
            situacaoMatricula: ctxs.first.situacaoMatricula,
            disciplinas: disciplinas.values.toList(),
            atualizadoEm: _agora(),
          ),
        );
      }
      return Historico(aluno: sessao.aluno, semestres: semestres);
    } finally {
      sessao.fechar();
    }
  }

  List<String> _notasNovas(Historico antes, Historico depois) {
    final out = <String>[];
    for (final s in depois.semestres) {
      final antigas = {
        for (final d in antes.semestre(s.codigo)?.disciplinas ?? <Disciplina>[])
          d.chave: d,
      };
      for (final d in s.disciplinas) {
        final a = antigas[d.chave];
        if (a == null) continue;
        for (var i = 0; i < 3; i++) {
          final nota = d.notas[i];
          if (a.notas[i] == null && nota != null) {
            out.add(
              'N${i + 1} de ${nomeMateria(d.nomeBruto).nome}: ${fmt(nota)}',
            );
          }
        }
      }
    }
    return out;
  }

  String? _periodoInicial() {
    final h = historico;
    if (h == null || h.semestres.isEmpty) return null;
    final padrao = periodoPadrao(_agora());
    return h.semestre(padrao)?.codigo ?? h.semestres.first.codigo;
  }

  void selecionarPeriodo(String codigo) => _mudar(() => periodo = codigo);

  void dispensarNovidades() => _mudar(() => novidades = const []);

  Future<void> definirTema(TemaApp tema) async {
    _mudar(() => prefs = prefs.copyWith(tema: tema));
    await _local.salvarPreferencias(prefs);
  }

  /// Liga/desliga a trava; exige autenticar para confirmar a mudanca.
  Future<bool> definirBiometria(bool ligar) async {
    if (!await _autenticar('Confirme para alterar a trava do app')) {
      return false;
    }
    _mudar(() => prefs = prefs.copyWith(biometria: ligar));
    await _local.salvarPreferencias(prefs);
    return true;
  }

  Future<void> desbloquear() async {
    if (fase != Fase.bloqueado) return;
    if (await _autenticar('Desbloqueie para ver seu boletim')) {
      _mudar(() => fase = Fase.pronto);
      _sincronizarSeVelho();
    }
  }

  /// Chamado quando o app vai para segundo plano.
  void aoSairDeCena() {
    if (_autenticando || demo) return;
    if (fase == Fase.pronto && prefs.biometria && biometriaDisponivel) {
      _mudar(() => fase = Fase.bloqueado);
    }
  }

  Future<bool> _autenticar(String motivo) async {
    if (_autenticando) return false;
    _autenticando = true;
    try {
      return await _biometria.autenticar(motivo);
    } finally {
      _autenticando = false;
    }
  }

  /// Apaga credenciais e todos os dados do aluno deste aparelho.
  Future<void> sair() async {
    _credenciais = null;
    if (!demo) {
      await _cofre.apagar();
      await _local.apagarHistorico();
      prefs = prefs.copyWith(biometria: false);
      await _local.salvarPreferencias(prefs);
    }
    _mudar(() {
      demo = false;
      historico = null;
      periodo = null;
      erro = null;
      novidades = const [];
      fase = Fase.deslogado;
    });
  }

  void _mudar(VoidCallback f) {
    f();
    notifyListeners();
  }
}
