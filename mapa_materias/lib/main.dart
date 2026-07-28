import 'package:flutter/material.dart';
import 'services/disciplina_service.dart';
import 'models/disciplina_model.dart';

void main(){
  runApp(const MapaMateriasApp());
}

class MapaMateriasApp extends StatelessWidget {
  const MapaMateriasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa de Materias',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TelaInicial(),
    );
  }
}

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  final DisciplinaService _disciplinaService = DisciplinaService();
  late Future<List<Disciplina>> _futureDisciplinas;

  @override
  void initState() {
    // Inicia o carregamento dos dados assim que a tela é criada
    super.initState();
    _futureDisciplinas = _disciplinaService.carregarDisciplinas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Pré-requisitos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Disciplina>>(
        future: _futureDisciplinas,
        builder: (context, snapshot) {
          // 1. Estado de carregamento (mostra a bolinha girando)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } 
          
          // 2. Estado de erro (caso o JSON tenha algum problema)
          else if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar dados: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } 
          
          // 3. Estado de sucesso (dados carregados)
          else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final disciplinas = snapshot.data!;
            
            // Aqui é onde o grafo vai entrar de fato! 
            // Por enquanto, apenas confirmamos que os dados chegaram.
            return Center(
              child: Text(
                'Sucesso! ${disciplinas.length} matérias carregadas.\nO grafo ficará aqui!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            );
          }

          // 4. Estado vazio
          return const Center(child: Text('Nenhuma disciplina encontrada.'));
        },
      )
    );
  }
}