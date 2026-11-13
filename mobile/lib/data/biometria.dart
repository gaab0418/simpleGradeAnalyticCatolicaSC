/// Trava do app por digital/rosto (ou PIN do aparelho como alternativa).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class Biometria {
  final _auth = LocalAuthentication();

  /// O aparelho tem algum bloqueio configurado que o app pode usar?
  Future<bool> disponivel() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> autenticar(String motivo) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      // Cancelado, sem biometria cadastrada, bloqueio temporario...
      return false;
    }
  }
}
