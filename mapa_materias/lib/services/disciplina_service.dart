import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/disciplina_model.dart'; 

class DisciplinaService {
  // Método assíncrono para carregar os dados
  Future<List<Disciplina>> carregarDisciplinas() async {
    try {
      // 1. Lê o arquivo JSON da pasta assets
      final String respostaString = await rootBundle.loadString('assets/dados_materias.json');
      
      // 2. Converte a string JSON para um Map do Dart
      final Map<String, dynamic> jsonMap = jsonDecode(respostaString);
      
      // 3. Itera pelas entradas (entries) do mapa para construir as disciplinas
      List<Disciplina> disciplinas = jsonMap.entries.map((entry) {
        final String codigoDisciplina = entry.key; // Ex: "ACP0900"
        final Map<String, dynamic> dados = entry.value; // Ex: {"nome": "...", "pre_requisitos": []}
        
        // Montamos um mapa intermediário com as chaves exatas que o seu
        // construtor Disciplina.fromJson() está esperando ler.
        final Map<String, dynamic> jsonFormatado = {
          'codigo': codigoDisciplina,
          'nome': dados['nome'],
          // Traduzindo do snake_case do JSON para o camelCase do Dart
          'preRequisitos': dados['pre_requisitos'], 
          'coRequisitos': dados['co_requisitos'],
        };
        
        return Disciplina.fromJson(jsonFormatado);
      }).toList();
      
      return disciplinas;
      
    } catch (e) {
      // Em caso de erro (arquivo não encontrado ou json malformado)
      throw Exception('Erro ao carregar os dados das disciplinas: $e');
    }
  }
}