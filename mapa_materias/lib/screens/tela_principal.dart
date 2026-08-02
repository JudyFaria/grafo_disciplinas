import 'package:flutter/material.dart';
import '../models/disciplina_model.dart';
import '../widgets/mapa_periodos.dart';
import '../services/disciplina_service.dart';
import '../services/planilha_service.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final DisciplinaService _disciplinaService = DisciplinaService();
  final PlanilhaService _planilhaService = PlanilhaService();
  late Future<List<Disciplina>> _futureDisciplinas;
  Map<String, int>? _periodosDaPlanilha; // null = ainda não importou

  @override
  void initState() {
    super.initState();
    _futureDisciplinas = _disciplinaService.carregarDisciplinas();
  }

  Future<void> _importarPendencias() async {
    try {
        final periodos = await _planilhaService.lerMateriasFaltantes(context);
        if (periodos.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nenhuma matéria foi encontrada nessa planilha.')),
            );
            return;
        }
        setState(() => _periodosDaPlanilha = periodos);
    } catch (e) {
        debugPrint('Erro ao importar pendências: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar a planilha: $e')),
        );
    }   
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_periodosDaPlanilha == null ? 'Mapa de Pré-requisitos' : 'Suas matérias pendentes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_periodosDaPlanilha != null)
            IconButton(
              icon: const Icon(Icons.grid_view),
              tooltip: 'Voltar pra grade geral do curso',
              onPressed: () => setState(() => _periodosDaPlanilha = null),
            ),
        ],
      ),
      body: FutureBuilder<List<Disciplina>>(
        future: _futureDisciplinas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar os dados das disciplinas: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma disciplina encontrada.', style: TextStyle(fontSize: 16)));
          }

          final disciplinas = snapshot.data!;
          if (_periodosDaPlanilha == null) {
            return MapaPeriodosWidget(disciplinas: disciplinas);
          }

          final faltantes = disciplinas
              .where((d) => _periodosDaPlanilha!.containsKey(d.codigo))
              .toList();
          return MapaPeriodosWidget(
            disciplinas: faltantes,
            periodosPersonalizados: _periodosDaPlanilha,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importarPendencias,
        icon: const Icon(Icons.upload_file),
        label: const Text('Importar pendências'),
      ),
    );
  }
}