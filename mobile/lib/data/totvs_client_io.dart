/// Cliente do portal TOTVS RM (mesmo fluxo de site/src/lib/servidor/totvs.ts).
/// O celular fala direto com o portal: a senha nao passa por servidor nenhum.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/models.dart';
import 'portal.dart';

PortalGateway criarPortal() => TotvsClient();

const _cookieContexto = 'EduContextoAlunoResponsavelAPI';
const _maxBytesResposta = 2 * 1024 * 1024;
final _nomeCookieValido = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");
final _valorCookieProibido = RegExp(r'[\r\n\x00-\x1f\x7f;]');
const _userAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/149.0.0.0 Mobile Safari/537.36';

class TotvsClient implements PortalGateway {
  TotvsClient({Uri? base, this.timeout = const Duration(seconds: 25)})
    : base = base ?? Uri.parse('https://portal.catolicasc.org.br');

  /// So e trocada nos testes (servidor falso local).
  final Uri base;
  final Duration timeout;

  @override
  Future<PortalSessao> entrar(Credenciais c) async {
    final sessao = _Sessao(base, timeout);
    try {
      await sessao.autenticar(c);
      return sessao;
    } catch (_) {
      sessao.fechar();
      rethrow;
    }
  }
}

class _Sessao implements PortalSessao {
  _Sessao(this._base, this._timeout)
    : _http = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..userAgent = _userAgent;

  final Uri _base;
  final Duration _timeout;
  final HttpClient _http;
  final _cookies = <String, String>{};

  @override
  late final Aluno aluno;
  @override
  late final List<ContextoPeriodo> contextos;

  static const _app = '/FrameHTML/web/app/edu/PortalEducacional/';
  static const _api = '/FrameHTML/RM/API/';

  Uri _url(String caminho, [Map<String, String>? query]) =>
      _base.replace(path: caminho, queryParameters: query);

  Future<void> autenticar(Credenciais c) async {
    // 1. Pagina inicial: recebe os cookies de sessao.
    await _requisitar('GET', _url(_app));
    _cookies.putIfAbsent('DefaultAlias', () => 'CorporeRM');
    _cookies.putIfAbsent(
      'EduMascaras',
      () => '{"mascaraTelefone": "(99) 9?9999-9999", "mascaraCEP": ""}',
    );

    // 2. Login.
    final login = await _requisitar(
      'POST',
      _url('${_api}TOTVSEducacional/Login'),
      corpo: {'user': c.usuario, 'password': c.senha, 'alias': 'CorporeRM'},
      referer: '${_app}login/',
    );
    final token = switch (login.status == 200 ? login.json : null) {
      {'data': {'value': final String v}} when v.isNotEmpty => v,
      _ => null,
    };
    if (token == null) {
      // Erros 5xx sao do portal; o resto e credencial recusada.
      throw login.status >= 500
          ? const PortalException(
              FalhaPortal.portal,
              'O portal da Católica está fora do ar. Tente de novo em instantes.',
            )
          : const PortalException(
              FalhaPortal.credenciais,
              'Usuário ou senha não conferem com o portal.',
            );
    }

    // 3. O token e um contexto em base64; vira cookie e chave de auto-login.
    final String chave;
    try {
      chave = Uri.decodeComponent(token);
      final valorContexto = utf8.decode(
        base64.decode(base64.normalize(chave)),
      );
      if (_valorCookieProibido.hasMatch(valorContexto)) {
        throw const FormatException('Cookie invalido');
      }
      _cookies[_cookieContexto] = valorContexto;
    } on FormatException {
      throw const PortalException(
        FalhaPortal.portal,
        'O portal respondeu de um jeito inesperado no login.',
      );
    } on ArgumentError {
      throw const PortalException(
        FalhaPortal.portal,
        'O portal respondeu de um jeito inesperado no login.',
      );
    }
    await _requisitar(
      'GET',
      _url('${_api}user/AutoLoginPortal', {'key': chave}),
    );

    // 4. Periodos letivos do aluno.
    final ctx = await _requisitar(
      'GET',
      _url('${_api}TOTVSEducacional/Contexto'),
    );
    final data = _dados(ctx);
    contextos = contextosDoJson(data);
    aluno = alunoDoJson(data);
  }

  @override
  Future<List<Disciplina>> disciplinas(ContextoPeriodo contexto) async {
    if (_valorCookieProibido.hasMatch(contexto.id)) {
      throw const PortalException(
        FalhaPortal.portal,
        'O portal respondeu um contexto inválido.',
      );
    }
    _cookies[_cookieContexto] = contexto.id;
    final notas = _dados(
      await _requisitar('GET', _url('${_api}TOTVSEducacional/NotaEtapa')),
    );
    final faltas = _dados(
      await _requisitar('GET', _url('${_api}TOTVSEducacional/FaltaEtapa')),
    );
    return disciplinasDoJson(
      (notas is Map ? notas['Notas'] : null) as List? ?? const [],
      (faltas is Map ? faltas['FaltasEtapa'] : null) as List? ?? const [],
    );
  }

  @override
  void fechar() => _http.close(force: true);

  Object? _dados(_Resposta r) {
    final j = r.json;
    if (r.status == 401 || r.status == 403) {
      throw const PortalException(
        FalhaPortal.credenciais,
        'O portal encerrou a sessão. Entre de novo.',
      );
    }
    if (r.status != 200 || j is! Map) {
      throw PortalException(
        FalhaPortal.portal,
        'O portal respondeu com erro (${r.status}). Tente de novo em instantes.',
      );
    }
    return j['data'];
  }

  /// Uma requisicao com cookies proprios e redirecionamento manual: assim os
  /// cookies de cada salto sao guardados e nada (senha, sessao) sai do host
  /// do portal.
  Future<_Resposta> _requisitar(
    String metodo,
    Uri url, {
    Map<String, Object?>? corpo,
    String? referer,
  }) async {
    try {
      return await _executar(
        metodo,
        url,
        corpo: corpo,
        referer: referer,
      ).timeout(_timeout);
    } on PortalException {
      rethrow;
    } on TimeoutException {
      throw const PortalException(
        FalhaPortal.rede,
        'O portal demorou demais para responder.',
      );
    } on HandshakeException {
      throw const PortalException(
        FalhaPortal.rede,
        'Não foi possível confirmar a identidade do portal (conexão insegura).',
      );
    } on IOException {
      throw const PortalException(
        FalhaPortal.rede,
        'Sem conexão com o portal. Confira sua internet.',
      );
    }
  }

  Future<_Resposta> _executar(
    String metodo,
    Uri url, {
    Map<String, Object?>? corpo,
    String? referer,
  }) async {
    for (var salto = 0; salto < 6; salto++) {
      if (url.host != _base.host || url.scheme != _base.scheme) {
        throw const PortalException(
          FalhaPortal.portal,
          'O portal tentou redirecionar para outro endereço. Acesso bloqueado.',
        );
      }
      final req = await _http.openUrl(metodo, url);
      req.followRedirects = false;
      req.headers
        ..set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*')
        ..set(HttpHeaders.acceptLanguageHeader, 'pt-BR,pt;q=0.9')
        ..set(HttpHeaders.refererHeader, _url(referer ?? _app).toString());
      final cookiesSeguros = _cookies.entries.where(
        (e) =>
            _nomeCookieValido.hasMatch(e.key) &&
            !_valorCookieProibido.hasMatch(e.value),
      );
      if (cookiesSeguros.isNotEmpty) {
        req.headers.set(
          HttpHeaders.cookieHeader,
          cookiesSeguros.map((e) => '${e.key}=${e.value}').join('; '),
        );
      }
      if (corpo != null) {
        req.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/json;charset=UTF-8')
          ..set('origin', _base.origin);
        req.add(utf8.encode(jsonEncode(corpo)));
      }
      final resp = await req.close();
      _guardarCookies(resp);

      final destino = resp.headers.value(HttpHeaders.locationHeader);
      if (resp.isRedirect && destino != null) {
        if (resp.contentLength > _maxBytesResposta) {
          await resp.listen((_) {}).cancel();
        } else {
          await resp.drain<void>();
        }
        url = url.resolve(destino);
        if (resp.statusCode != 307 && resp.statusCode != 308) {
          metodo = 'GET';
          corpo = null;
        }
        continue;
      }
      final texto = await _lerTextoLimitado(resp, _maxBytesResposta);
      return _Resposta(resp.statusCode, texto);
    }
    throw const PortalException(
      FalhaPortal.portal,
      'O portal entrou em um ciclo de redirecionamentos.',
    );
  }

  Future<String> _lerTextoLimitado(
    HttpClientResponse resp,
    int maxBytes,
  ) async {
    final clHeader = resp.headers.value(HttpHeaders.contentLengthHeader);
    final declarado = clHeader == null ? null : int.tryParse(clHeader.trim());
    if (resp.contentLength > maxBytes ||
        (declarado != null && declarado > maxBytes)) {
      await resp.listen((_) {}).cancel();
      throw const PortalException(
        FalhaPortal.portal,
        'O portal retornou uma resposta grande demais.',
      );
    }
    final builder = BytesBuilder(copy: false);
    final completer = Completer<String>();
    late final StreamSubscription<List<int>> sub;
    sub = resp.listen(
      (chunk) {
        if (builder.length + chunk.length > maxBytes) {
          unawaited(sub.cancel());
          if (!completer.isCompleted) {
            completer.completeError(
              const PortalException(
                FalhaPortal.portal,
                'O portal retornou uma resposta grande demais.',
              ),
            );
          }
          return;
        }
        builder.add(chunk);
      },
      onError: (Object err, StackTrace st) {
        if (!completer.isCompleted) completer.completeError(err, st);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(
            utf8.decode(builder.takeBytes(), allowMalformed: true),
          );
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  void _guardarCookies(HttpClientResponse resp) {
    for (final linha in resp.headers[HttpHeaders.setCookieHeader] ?? const []) {
      final par = linha.split(';').first;
      final i = par.indexOf('=');
      if (i <= 0) continue;
      final nome = par.substring(0, i).trim();
      final valor = par.substring(i + 1).trim();
      if (!_nomeCookieValido.hasMatch(nome)) continue;
      if (valor.isEmpty) {
        _cookies.remove(nome);
      } else if (!_valorCookieProibido.hasMatch(valor)) {
        _cookies[nome] = valor;
      }
    }
  }
}

class _Resposta {
  _Resposta(this.status, this._texto);
  final int status;
  final String _texto;

  /// `null` quando o corpo nao e JSON (pagina de erro em HTML, por exemplo).
  late final Object? json = () {
    try {
      return jsonDecode(_texto);
    } on FormatException {
      return null;
    }
  }();
}
