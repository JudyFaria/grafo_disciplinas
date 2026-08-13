import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/disciplina_model.dart';

class DisciplinaService {
  // Só existe currículo de Ciência da Computação por enquanto — os
  // arquivos continuam nos mesmos caminhos de sempre. Quando tiver dados
  // de outros cursos, mapeia `curso` pro caminho certo aqui.
  Future<List<Disciplina>> carregarDisciplinas(String curso) async {
    try {
      final String respostaString =
          await rootBundle.loadString('assets/dados_materias.json');
      final Map<String, dynamic> jsonMap = jsonDecode(respostaString);

      Map<String, dynamic> periodos = {};
      try {
        final String periodosString =
            await rootBundle.loadString('assets/periodos_curriculo_atual_cc.json');
        periodos = jsonDecode(periodosString);
      } catch (_) {}

      return jsonMap.entries.map((entry) {
        final dados = entry.value as Map<String, dynamic>;
        return Disciplina.fromJson({
          'codigo': entry.key,
          'nome': dados['nome'],
          'preRequisitos': dados['pre_requisitos'],
          'coRequisitos': dados['co_requisitos'],
          'periodo': periodos[entry.key],
          'grupoDisciplinas': dados['grupo_disciplinas'],
        });
      }).toList();
    } catch (e) {
      throw Exception('Erro ao carregar os dados das disciplinas: $e');
    }
  }
}