import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/disciplina_model.dart';

class DisciplinaService {
  Future<List<Disciplina>> carregarDisciplinas() async {
    try {
      final String respostaString =
          await rootBundle.loadString('assets/dados_materias.json');
      final Map<String, dynamic> jsonMap = jsonDecode(respostaString);

      Map<String, dynamic> periodos = {};
      try {
        final String periodosString =
            await rootBundle.loadString('assets/periodos_curriculo_atual_cc.json');
        periodos = jsonDecode(periodosString);
      } catch (_) {
        // opcional — sem esse arquivo, periodo fica null pra todo mundo
      }

      return jsonMap.entries.map((entry) {
        final dados = entry.value as Map<String, dynamic>;
        return Disciplina.fromJson({
          'codigo': entry.key,
          'nome': dados['nome'],
          'preRequisitos': dados['pre_requisitos'],
          'coRequisitos': dados['co_requisitos'],
          'periodo': periodos[entry.key],
        });
      }).toList();
    } catch (e) {
      throw Exception('Erro ao carregar os dados das disciplinas: $e');
    }
  }
}