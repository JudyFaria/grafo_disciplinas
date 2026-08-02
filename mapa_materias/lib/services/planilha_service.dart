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

class PlanilhaService {
  static const _indiceColunaPeriodo = 0;
  static const _indiceColunaCodigo = 2;
  static const _linhasParaPular = 2; // metadado + cabeçalho

  Future<Map<String, int>> lerMateriasFaltantes(BuildContext context) async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true, // explícito — não depende do valor padrão da versão instalada
    );
    if (resultado == null) return {};

    final arquivo = resultado.files.single;
    if (arquivo.bytes == null) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Diagnóstico'),
            content: Text('O arquivo foi escolhido, mas os bytes vieram nulos (arquivo.bytes == null). '
                'É bem provável que o problema esteja aqui.'),
          ),
        );
      }
      return {};
    }

    final excel = Excel.decodeBytes(arquivo.bytes!);
    final nomeAba = excel.tables.keys.first;
    final sheet = excel.tables[nomeAba]!;
    final todasLinhas = sheet.rows.toList();

    final faltantes = <String, int>{};
    for (var row in todasLinhas.skip(_linhasParaPular)) {
      if (_indiceColunaCodigo >= row.length) continue;
      final codigo = row[_indiceColunaCodigo]?.value?.toString().trim();
      final periodoBruto = row[_indiceColunaPeriodo]?.value?.toString().trim();
      final match = periodoBruto != null ? RegExp(r'\d+').firstMatch(periodoBruto) : null;
      final periodo = match != null ? int.parse(match.group(0)!) : null;
      if (codigo != null && codigo.isNotEmpty && periodo != null) {
        faltantes[codigo] = periodo;
      }
    }

    if (context.mounted) {
      final amostra = todasLinhas
          .take(4)
          .map((r) => r.map((c) => c?.value).toList())
          .join('\n');
      // await showDialog(
      //   context: context,
      //   builder: (_) => AlertDialog(
      //     title: const Text('Diagnóstico da planilha'),
      //     content: SingleChildScrollView(
      //       child: Text(
      //         'Aba: $nomeAba\n'
      //         'Total de linhas: ${todasLinhas.length}\n'
      //         'Matérias encontradas: ${faltantes.length}\n\n'
      //         'Primeiras linhas (cru):\n$amostra',
      //       ),
      //     ),
      //     actions: [
      //       TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      //     ],
      //   ),
      // );
    }

    return faltantes;
  }
}