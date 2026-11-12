/// Fora de Android/iOS (ex.: web) o navegador bloqueia o portal por CORS.
library;

import 'portal.dart';

PortalGateway criarPortal() => const _PortalIndisponivel();

class _PortalIndisponivel implements PortalGateway {
  const _PortalIndisponivel();

  @override
  Future<PortalSessao> entrar(Credenciais c) async =>
      throw const PortalException(
        FalhaPortal.portal,
        'O acesso ao portal só funciona no app instalado no celular. '
        'Aqui dá para explorar a demonstração.',
      );
}
