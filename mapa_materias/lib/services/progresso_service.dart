import 'dart:convert';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import '../models/semestre_academico.dart';

class ProgressoService {
  void salvar({
    required Map<String, SemestreAcademico> semestre,
    required Set<String> concluidas,
    required Set<SemestreAcademico> colunasExtras,
  }) {
    final dados = {
      'semestre': semestre.map(
        (codigo, s) => MapEntry(codigo, {'ano': s.ano, 'semestre': s.semestre}),
      ),
      'concluidas': concluidas.toList(),
      'colunasExtras':
          colunasExtras.map((s) => {'ano': s.ano, 'semestre': s.semestre}).toList(),
    };

    final bytes = utf8.encode(jsonEncode(dados));
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'meu_progresso.json')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<Map<String, dynamic>?> carregar() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (resultado == null || resultado.files.single.bytes == null) return null;
    final texto = utf8.decode(resultado.files.single.bytes!);
    return jsonDecode(texto) as Map<String, dynamic>;
  }
}