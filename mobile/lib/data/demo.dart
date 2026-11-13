/// Historico ficticio para explorar o app sem conta no portal.
library;

import '../domain/models.dart';

Historico historicoDemo(DateTime agora) {
  var seq = 0;
  Disciplina d(
    String nome,
    String sigla,
    List<double?> notas, {
    int faltas = 0,
    String? situacao,
  }) {
    final completas = notas.every((n) => n != null);
    final media = completas
        ? (notas.fold<double>(0, (a, b) => a + b!) / 3 * 10).round() / 10
        : null;
    return Disciplina(
      chave: 'demo-${seq++}',
      codTurma: 'ESW-N',
      codDisc: sigla,
      nomeBruto: '${nome.toUpperCase()} - $sigla',
      situacao:
          situacao ??
          (media == null
              ? 'Matriculado'
              : media >= 6
              ? 'Aprovado'
              : 'Reprovado'),
      notas: notas,
      mediaFinal: media,
      faltas: faltas,
    );
  }

  Semestre s(String codigo, List<Disciplina> ds) => Semestre(
    codigo: codigo,
    curso: 'ENGENHARIA DE SOFTWARE',
    situacaoMatricula: 'Matriculado',
    disciplinas: ds,
    atualizadoEm: agora,
  );

  return Historico(
    aluno: const Aluno(
      nome: 'ALUNO DE DEMONSTRAÇÃO',
      ra: '000000',
      curso: 'ENGENHARIA DE SOFTWARE',
    ),
    semestres: [
      s('202411', [
        d('Algoritmos e Programação', 'ALG1', [6.5, 7.0, 7.8], faltas: 4),
        d('Matemática Discreta', 'MDI', [5.0, 6.2, 7.1], faltas: 8),
        d('Introdução à Engenharia de Software', 'IES', [8.0, 8.5, 9.0]),
        d('Comunicação e Expressão', 'COM', [7.5, 8.0, 7.0], faltas: 4),
        d('Cálculo I', 'CAL1', [4.0, 5.5, 6.0], faltas: 12),
      ]),
      s('202423', [
        d('Estrutura de Dados', 'EDA', [6.0, 7.5, 8.2], faltas: 4),
        d('Cálculo I', 'CAL1', [6.5, 6.0, 7.5], faltas: 4),
        d('Arquitetura de Computadores', 'ARQ', [7.0, 7.2, 8.0], faltas: 8),
        d('Programação Orientada a Objetos', 'POO', [8.5, 8.0, 9.2]),
        d('Filosofia e Ética', 'FIL', [9.0, 8.5, 9.5], faltas: 4),
      ]),
      s('202511', [
        d('Banco de Dados I', 'BD1', [7.5, 8.0, 8.8]),
        d('Engenharia de Requisitos', 'REQ', [8.0, 8.4, 9.0], faltas: 4),
        d('Sistemas Operacionais', 'SOP', [6.0, 6.5, 7.5], faltas: 8),
        d('Probabilidade e Estatística', 'PES', [5.5, 6.8, 7.0], faltas: 12),
        d('Desenvolvimento Web', 'WEB', [9.0, 9.2, 9.6]),
      ]),
      s('202523', [
        d('Banco de Dados II', 'BD2', [8.0, 8.2, 9.0]),
        d('Redes de Computadores', 'RED', [7.0, 7.5, 8.0], faltas: 4),
        d('Projeto de Software', 'PSW', [8.5, 9.0, 9.4]),
        d('Interação Humano-Computador', 'IHC', [9.0, 9.5, 9.0]),
        d('Análise de Algoritmos', 'AAL', [6.0, 6.4, 7.8], faltas: 8),
      ]),
      s('202611', [
        d('Desenvolvimento Mobile', 'MOB', [9.0, 9.4, 9.8]),
        d('Qualidade e Teste de Software', 'QTS', [8.0, 8.6, 9.0], faltas: 4),
        d('Segurança da Informação', 'SEG', [8.5, 8.0, 9.2]),
        d('Sistemas Distribuídos', 'SDI', [7.0, 7.4, 8.4], faltas: 4),
        d('Gestão de Projetos', 'GPR', [8.8, 9.0, 9.0]),
      ]),
      s('202623', [
        d('Inteligência Artificial', 'IA', [9.8, null, null]),
        d('Arquitetura de Software', 'ASW', [9.0, 9.2, null], faltas: 4),
        d('Computação em Nuvem', 'NUV', [6.0, 5.5, null], faltas: 8),
        d('Compiladores', 'CMP', [3.5, null, null], faltas: 17),
        d('Empreendedorismo', 'EMP', [2.0, 4.5, null], faltas: 4),
        d('Trabalho de Conclusão I', 'TCC1', [null, null, null]),
      ]),
    ],
  );
}
