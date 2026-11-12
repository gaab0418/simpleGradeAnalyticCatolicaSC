/// Persistencia local.
///  - Credenciais: cofre do sistema (Android Keystore / iOS Keychain).
///  - Historico e preferencias: armazenamento privado do app (nao e segredo,
///    mas fica fora de backup na nuvem; ver AndroidManifest).
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
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

class ArmazenamentoLocal {
  static const _kHistorico = 'historico.v1';
  static const _kTema = 'pref.tema';
  static const _kBiometria = 'pref.biometria';

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
}
