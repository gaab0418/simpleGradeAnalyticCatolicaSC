// Exercita o fluxo real de login contra um portal falso em localhost:
// cookies, token em base64, troca de contexto e tratamento de erros.
import 'dart:convert';
import 'dart:io';

import 'package:boletim_catolica/data/portal.dart';
import 'package:boletim_catolica/data/totvs_client_io.dart';
import 'package:flutter_test/flutter_test.dart';

const _usuario = 'aluno';
const _senha = 's3nh@ "com" espaço';
const _contextoLogin = '{"ctx":"inicial"}';

void main() {
  late HttpServer servidor;
  late TotvsClient cliente;
  late List<String> pedidos;
  var falharNotas = false;

  Map<String, String> cookies(HttpRequest r) => {
    for (final par in (r.headers.value('cookie') ?? '').split('; '))
      if (par.contains('='))
        par.substring(0, par.indexOf('=')): par.substring(par.indexOf('=') + 1),
  };

  Future<void> json(HttpRequest r, Object corpo, {int status = 200}) async {
    r.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(corpo));
    await r.response.close();
  }

  setUp(() async {
    pedidos = [];
    falharNotas = false;
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cliente = TotvsClient(base: Uri.parse('http://127.0.0.1:${servidor.port}'));

    servidor.listen((r) async {
      final rota = r.uri.path.split('/').last;
      pedidos.add('${r.method} ${r.uri.path}');
      final ck = cookies(r);
      final logado = ck['SESSAO'] == 'abc' && ck['AUTO'] == 'ok';

      switch (rota) {
        case '': // pagina inicial do portal
          r.response.headers.add('set-cookie', 'SESSAO=abc; Path=/; HttpOnly');
          await r.response.close();
        case 'Login':
          final corpo = jsonDecode(await utf8.decoder.bind(r).join()) as Map;
          if (ck['SESSAO'] != 'abc' ||
              corpo['user'] != _usuario ||
              corpo['password'] != _senha ||
              corpo['alias'] != 'CorporeRM') {
            return json(r, {'messages': 'invalido'}, status: 401);
          }
          final token = Uri.encodeComponent(
            base64.encode(utf8.encode(_contextoLogin)),
          );
          await json(r, {
            'data': {'value': token},
          });
        case 'AutoLoginPortal':
          final chave = r.uri.queryParameters['key'] ?? '';
          final ok =
              utf8.decode(base64.decode(chave)) == _contextoLogin &&
              ck['EduContextoAlunoResponsavelAPI'] == _contextoLogin;
          // Redireciona para provar que cookies de saltos sao mantidos.
          r.response
            ..statusCode = 302
            ..headers.set('location', '/FrameHTML/RM/API/user/Fim')
            ..headers.add('set-cookie', 'AUTO=${ok ? 'ok' : 'falhou'}');
          await r.response.close();
        case 'Fim':
          await json(r, {});
        case 'Contexto':
          if (!logado) return json(r, {}, status: 401);
          await json(r, {
            'data': [
              {
                'IDCONTEXTOALUNO': 'CTX-2',
                'CODPERLET': 202623,
                'NOMECURSO': 'ENG. DE SOFTWARE',
                'NOMEALUNO': 'FULANO DE TAL',
                'RA': '123',
                'SITMATPERLET': 'Matriculado',
              },
              {
                'IDCONTEXTOALUNO': 'CTX-1',
                'CODPERLET': 202611,
                'NOMECURSO': 'ENG. DE SOFTWARE',
                'NOMEALUNO': 'FULANO DE TAL',
                'RA': '123',
                'SITMATPERLET': 'Matriculado',
              },
            ],
          });
        case 'NotaEtapa':
          if (!logado) return json(r, {}, status: 401);
          if (falharNotas) {
            r.response.statusCode = 500;
            r.response.write('<html>erro</html>');
            return r.response.close();
          }
          // A resposta depende do cookie de contexto selecionado.
          final atual = ck['EduContextoAlunoResponsavelAPI'] == 'CTX-2';
          await json(r, {
            'data': {
              'Notas': [
                {
                  'IDTURMADISC': atual ? 2 : 1,
                  'CODTURMA': 'T',
                  'CODDISC': 'D',
                  'DISCIPLINA': atual ? 'COMPILADORES - CMP' : 'REDES - RED',
                  'SITUACAO': atual ? 'Matriculado' : 'Aprovado',
                  '1 - Nota 1': atual ? '<font color=red>3,5</font>' : '8,0',
                  '2 - Nota 2': atual ? null : '7,0',
                  '3 - Nota 3': atual ? null : '9,0',
                  '6 - Média Final': atual ? null : '8,0',
                },
              ],
            },
          });
        case 'FaltaEtapa':
          await json(r, {
            'data': {
              'FaltasEtapa': [
                {'IDTURMADISC': 2, '1 - Faltas Sala de Aula': '12'},
              ],
            },
          });
        default:
          r.response.statusCode = 404;
          await r.response.close();
      }
    });
  });

  tearDown(() => servidor.close(force: true));

  test('login completo e leitura de dois períodos', () async {
    final sessao = await cliente.entrar(const Credenciais(_usuario, _senha));
    addTearDown(sessao.fechar);

    expect(sessao.aluno.nome, 'FULANO DE TAL');
    expect(sessao.contextos.map((c) => c.codigo), ['202623', '202611']);

    final atual = await sessao.disciplinas(sessao.contextos[0]);
    expect(atual.single.nomeBruto, 'COMPILADORES - CMP');
    expect(atual.single.notas, [3.5, null, null]);
    expect(atual.single.faltas, 12);

    final antigo = await sessao.disciplinas(sessao.contextos[1]);
    expect(antigo.single.nomeBruto, 'REDES - RED');
    expect(antigo.single.mediaFinal, 8.0);
    expect(antigo.single.faltas, 0);
  });

  test('senha errada vira erro de credenciais', () async {
    await expectLater(
      cliente.entrar(const Credenciais(_usuario, 'errada')),
      throwsA(
        isA<PortalException>().having(
          (e) => e.tipo,
          'tipo',
          FalhaPortal.credenciais,
        ),
      ),
    );
    // Parou no login: nada alem dele foi consultado.
    expect(pedidos.any((p) => p.contains('Contexto')), isFalse);
  });

  test('erro 500 com HTML vira erro do portal', () async {
    final sessao = await cliente.entrar(const Credenciais(_usuario, _senha));
    addTearDown(sessao.fechar);
    falharNotas = true;
    await expectLater(
      sessao.disciplinas(sessao.contextos.first),
      throwsA(
        isA<PortalException>().having(
          (e) => e.tipo,
          'tipo',
          FalhaPortal.portal,
        ),
      ),
    );
  });

  test('portal fora do ar vira erro de rede', () async {
    final porta = servidor.port;
    await servidor.close(force: true);
    final offline = TotvsClient(base: Uri.parse('http://127.0.0.1:$porta'));
    await expectLater(
      offline.entrar(const Credenciais(_usuario, _senha)),
      throwsA(
        isA<PortalException>().having((e) => e.tipo, 'tipo', FalhaPortal.rede),
      ),
    );
  });

  test('credenciais não aparecem em toString', () {
    expect(
      const Credenciais('u', 'segredo').toString(),
      isNot(contains('segredo')),
    );
  });
}
