/// Contrato de acesso ao portal + conversao do JSON do TOTVS para o dominio.
/// Sem `dart:io` aqui, para o app tambem compilar para web (modo demonstracao).
library;

import '../domain/models.dart';

class Credenciais {
  const Credenciais(this.usuario, this.senha);
  final String usuario;
  final String senha;

  // Nunca deixa a senha vazar em log ou mensagem de erro.
  @override
  String toString() => 'Credenciais($usuario, ***)';
}

enum FalhaPortal { credenciais, rede, portal }

class PortalException implements Exception {
  const PortalException(this.tipo, this.mensagem);
  final FalhaPortal tipo;
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Um periodo letivo em que o aluno tem matricula.
class ContextoPeriodo {
  const ContextoPeriodo({
    required this.id,
    required this.codigo,
    required this.curso,
    required this.situacaoMatricula,
  });

  /// IDCONTEXTOALUNO: valor do cookie que seleciona o periodo no portal.
  final String id;
  final String codigo;
  final String curso;
  final String situacaoMatricula;
}

abstract interface class PortalGateway {
  /// Autentica e devolve uma sessao; lanca [PortalException].
  Future<PortalSessao> entrar(Credenciais c);
}

abstract interface class PortalSessao {
  Aluno get aluno;
  List<ContextoPeriodo> get contextos;
  Future<List<Disciplina>> disciplinas(ContextoPeriodo contexto);
  void fechar();
}

final _tags = RegExp(r'<[^>]+>');

/// O portal embrulha notas abaixo da media em HTML
/// (ex.: `<font color=red>3,3</font>`) e usa virgula decimal.
double? parseNota(Object? valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  final texto = valor.toString().replaceAll(_tags, '').trim();
  return double.tryParse(texto.replaceAll(',', '.'));
}

String _txt(Object? v) => v?.toString() ?? '';

List<ContextoPeriodo> contextosDoJson(Object? data) => [
  for (final c in (data as List? ?? const []).whereType<Map>())
    if (_txt(c['IDCONTEXTOALUNO']).isNotEmpty)
      ContextoPeriodo(
        id: _txt(c['IDCONTEXTOALUNO']),
        codigo: _txt(c['CODPERLET']),
        curso: _txt(c['NOMECURSO']),
        situacaoMatricula: _txt(c['SITMATPERLET']),
      ),
];

Aluno alunoDoJson(Object? data) {
  final ctx = (data as List? ?? const []).whereType<Map>().firstOrNull;
  return Aluno(
    nome: _txt(ctx?['NOMEALUNO']),
    ra: _txt(ctx?['RA']),
    curso: _txt(ctx?['NOMECURSO']),
  );
}

/// Cruza NotaEtapa com FaltaEtapa por IDTURMADISC.
List<Disciplina> disciplinasDoJson(List notas, List faltas) {
  final faltasPorTurma = <String, Map>{
    for (final f in faltas.whereType<Map>())
      if (f['IDTURMADISC'] != null) _txt(f['IDTURMADISC']): f,
  };
  return [
    for (final n in notas.whereType<Map>())
      Disciplina(
        chave: _txt(n['IDTURMADISC'] ?? n['CODDISC']),
        codTurma: _txt(n['CODTURMA']),
        codDisc: _txt(n['CODDISC']),
        nomeBruto: _txt(n['DISCIPLINA']),
        situacao: _txt(n['SITUACAO']),
        notas: [
          parseNota(n['1 - Nota 1']),
          parseNota(n['2 - Nota 2']),
          parseNota(n['3 - Nota 3']),
        ],
        mediaParcial: parseNota(n['5 - Média Parcial']),
        mediaFinal: parseNota(n['6 - Média Final'] ?? n['4 - Média Final']),
        faltas:
            parseNota(
              faltasPorTurma[_txt(
                n['IDTURMADISC'],
              )]?['1 - Faltas Sala de Aula'],
            )?.toInt() ??
            0,
      ),
  ];
}
