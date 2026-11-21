/// Persistencia local.
///  - Credenciais: cofre do sistema (Android Keystore / iOS Keychain).
///  - Historico e preferencias: armazenamento privado do app (nao e segredo,
///    mas fica fora de backup na nuvem; ver AndroidManifest).
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/regras.dart';
import 'portal.dart';

abstract interface class CofreCredenciais {
  Future<Credenciais?> ler();
  Future<void> salvar(Credenciais c);
  Future<void> apagar();
}

class CofreSeguro implements CofreCredenciais {
  const CofreSeguro();

  static const _kUsuario = 'portal.usuario';
  static const _kSenha = 'portal.senha';
  static const _cofre = FlutterSecureStorage(
    // Chave presa a este aparelho: nao vai para backup nem para outro iPhone.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  @override
  Future<Credenciais?> ler() async {
    final usuario = await _cofre.read(key: _kUsuario);
    final senha = await _cofre.read(key: _kSenha);
    if (usuario == null || senha == null) return null;
    return Credenciais(usuario, senha);
  }

  @override
  Future<void> salvar(Credenciais c) async {
    await _cofre.write(key: _kUsuario, value: c.usuario);
    await _cofre.write(key: _kSenha, value: c.senha);
  }

  @override
  Future<void> apagar() async {
    await _cofre.delete(key: _kUsuario);
    await _cofre.delete(key: _kSenha);
  }
}

enum TemaApp { sistema, claro, escuro }

class Preferencias {
  const Preferencias({this.tema = TemaApp.sistema, this.biometria = false});
  final TemaApp tema;
  final bool biometria;

  Preferencias copyWith({TemaApp? tema, bool? biometria}) => Preferencias(
    tema: tema ?? this.tema,
    biometria: biometria ?? this.biometria,
  );
}

class LayoutSemestre {
  const LayoutSemestre({
    this.modo = ModoOrdem.urgencia,
    this.ordem = const [],
    this.ocultas = const [],
  });

  final ModoOrdem modo;
  final List<String> ordem;
  final List<String> ocultas;

  LayoutSemestre copyWith({
    ModoOrdem? modo,
    List<String>? ordem,
    List<String>? ocultas,
  }) => LayoutSemestre(
    modo: modo ?? this.modo,
    ordem: ordem ?? this.ordem,
    ocultas: ocultas ?? this.ocultas,
  );

  factory LayoutSemestre.fromJson(Map<String, dynamic> j) => LayoutSemestre(
    modo:
        ModoOrdem.values.asNameMap()[j['modo'] as String?] ??
        ModoOrdem.urgencia,
    ordem: [
      for (final v in (j['ordem'] as List? ?? const []))
        if (v is String) v,
    ],
    ocultas: [
      for (final v in (j['ocultas'] as List? ?? const []))
        if (v is String) v,
    ],
  );

  Map<String, dynamic> toJson() => {
    'modo': modo.name,
    'ordem': ordem,
    'ocultas': ocultas,
  };
}

class ArmazenamentoLocal {
  static const _kHistorico = 'historico.v1';
  static const _kPassado = 'historico.passado.v2';
  static const _kTema = 'pref.tema';
  static const _kBiometria = 'pref.biometria';
  static const _kLayouts = 'pref.layout_semestres.v1';

  final _prefs = SharedPreferencesAsync();

  Future<Historico?> lerHistorico() async {
    final bruto = await _prefs.getString(_kHistorico);
    if (bruto == null) return null;
    try {
      return Historico.fromJson(jsonDecode(bruto) as Map<String, dynamic>);
    } catch (_) {
      // Cache corrompido ou de versao antiga: descarta e sincroniza de novo.
      await _prefs.remove(_kHistorico);
      return null;
    }
  }

  Future<void> salvarHistorico(Historico h) =>
      _prefs.setString(_kHistorico, jsonEncode(h.toJson()));

  Future<void> apagarHistorico() => _prefs.remove(_kHistorico);

  static String _chaveUsuario(String usuario) => usuario.trim().toLowerCase();

  Future<Map<String, dynamic>> _lerMapaPassados() async {
    final bruto = await _prefs.getString(_kPassado);
    if (bruto == null) return <String, dynamic>{};
    try {
      final dec = jsonDecode(bruto);
      if (dec is Map) return Map<String, dynamic>.from(dec);
    } catch (_) {
      await _prefs.remove(_kPassado);
    }
    return <String, dynamic>{};
  }

  Future<List<Semestre>> lerSemestresPassados(String usuario) async {
    final chave = _chaveUsuario(usuario);
    if (chave.isEmpty) return const [];
    final mapa = await _lerMapaPassados();
    final lista = mapa[chave];
    if (lista is! List) return const [];
    try {
      return [
        for (final item in lista)
          if (item is Map)
            Semestre.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> salvarSemestresPassados(
    String usuario,
    Iterable<Semestre> semestres,
  ) async {
    final chave = _chaveUsuario(usuario);
    if (chave.isEmpty) return;
    final mapa = await _lerMapaPassados();
    mapa[chave] = [for (final s in semestres) s.toJson()];
    await _prefs.setString(_kPassado, jsonEncode(mapa));
  }

  Future<Preferencias> lerPreferencias() async {
    final tema = await _prefs.getString(_kTema);
    return Preferencias(
      tema: TemaApp.values.asNameMap()[tema] ?? TemaApp.sistema,
      biometria: await _prefs.getBool(_kBiometria) ?? false,
    );
  }

  Future<void> salvarPreferencias(Preferencias p) async {
    await _prefs.setString(_kTema, p.tema.name);
    await _prefs.setBool(_kBiometria, p.biometria);
  }

  Future<Map<String, LayoutSemestre>> lerLayoutsSemestres() async {
    final bruto = await _prefs.getString(_kLayouts);
    if (bruto == null) return const {};
    try {
      final dec = jsonDecode(bruto);
      if (dec is! Map) return const {};
      return {
        for (final entry in dec.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: LayoutSemestre.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ),
      };
    } catch (_) {
      await _prefs.remove(_kLayouts);
      return const {};
    }
  }

  Future<void> salvarLayoutsSemestres(Map<String, LayoutSemestre> layouts) =>
      _prefs.setString(
        _kLayouts,
        jsonEncode({
          for (final entry in layouts.entries) entry.key: entry.value.toJson(),
        }),
      );

  Future<void> apagarLayoutsSemestres() => _prefs.remove(_kLayouts);
}
