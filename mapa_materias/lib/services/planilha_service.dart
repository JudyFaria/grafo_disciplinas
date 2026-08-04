// Lê a planilha "FaltaCursar" exportada pelo SAU e devolve o conjunto
// de códigos das matérias que ainda faltam cursar.
//
// Formato confirmado:
//   linha 1 = metadado (curso, matrícula, nome, data de geração)
//   linha 2 = cabeçalho: Período | Tipo | Código | Disciplina | Créditos
//   linha 3+ = dados

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

class ResultadoPlanilha {
  final Map<String, int> periodos;
  final String? matricula;
  ResultadoPlanilha({required this.periodos, this.matricula});
}

class PlanilhaService {
  static const _indiceColunaPeriodo = 0;
  static const _indiceColunaCodigo = 2;
  static const _linhasParaPular = 2; // metadado + cabeçalho

  Future<ResultadoPlanilha> lerMateriasFaltantes() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (resultado == null || resultado.files.single.bytes == null) {
      return ResultadoPlanilha(periodos: {});
    }

    final excel = Excel.decodeBytes(resultado.files.single.bytes!);
    final linhas = excel.tables[excel.tables.keys.first]!.rows.toList();

    String? matricula;
    if (linhas.isNotEmpty && linhas.first.isNotEmpty) {
      final metadado = linhas.first.first?.value?.toString() ?? '';
      matricula = RegExp(r'Matr[ií]cula:\s*(\d+)').firstMatch(metadado)?.group(1);
    }

    final periodos = <String, int>{};
    for (var row in linhas.skip(_linhasParaPular)) {
      if (_indiceColunaCodigo >= row.length) continue;
      final codigo = row[_indiceColunaCodigo]?.value?.toString().trim();
      final periodoBruto = row[_indiceColunaPeriodo]?.value?.toString().trim();
      final match = periodoBruto != null ? RegExp(r'\d+').firstMatch(periodoBruto) : null;
      final periodo = match != null ? int.parse(match.group(0)!) : null;
      if (codigo != null && codigo.isNotEmpty && periodo != null) {
        periodos[codigo] = periodo;
      }
    }

    return ResultadoPlanilha(periodos: periodos, matricula: matricula);
  }
}