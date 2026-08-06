import 'package:flutter/material.dart';
import '../models/disciplina_model.dart';
import '../widgets/mapa_periodos/mapa_periodos_widget.dart';
import '../services/disciplina_service.dart';
import '../services/planilha_service.dart';
import '../services/progresso_service.dart';
import '../services/auth_service.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final DisciplinaService _disciplinaService = DisciplinaService();
  final PlanilhaService _planilhaService = PlanilhaService();
  final ProgressoService _progressoService = ProgressoService();
  late Future<List<Disciplina>> _futureDisciplinas;

  Map<String, int>? _periodosDaPlanilha;
  Set<String> _faltantesSemPeriodo = {};
  String? _matricula;
  Map<String, dynamic>? _progressoSalvo;
  bool _carregandoProgresso = true;

  String get _uid => AuthService().usuarioAtual!.uid;

  @override
  void initState() {
    super.initState();
    _futureDisciplinas = _disciplinaService.carregarDisciplinas();
    _carregarProgressoSalvo();
  }

  Future<void> _carregarProgressoSalvo() async {
    final dados = await _progressoService.carregar(_uid);
    if (!mounted) return;
    setState(() {
      _progressoSalvo = dados;
      _carregandoProgresso = false;
    });
  }

  Future<void> _importarPendencias() async {
    try {
      final resultado = await _planilhaService.lerMateriasFaltantes();
      if (resultado.periodos.isEmpty && resultado.semPeriodo.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma matéria foi encontrada nessa planilha.')),
        );
        return;
      }
      setState(() {
        _periodosDaPlanilha = resultado.periodos;
        _faltantesSemPeriodo = resultado.semPeriodo;
        _matricula = resultado.matricula;
        _progressoSalvo = null;
      });
    } catch (e) {
      debugPrint('Erro ao importar pendências: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar a planilha: $e')),
      );
    }
  }

  // "Padrão da universidade": descarta planilha, matrícula e progresso
  // salvo — o próximo build monta a grade oficial do zero, como um
  // usuário que nunca importou nada.
  void _resetarParaGradeOficial() {
    setState(() {
      _periodosDaPlanilha = null;
      _faltantesSemPeriodo = {};
      _matricula = null;
      _progressoSalvo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Pré-requisitos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => AuthService().sair(),
          ),
        ],
      ),
      body: _carregandoProgresso
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Disciplina>>(
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
                  return const Center(
                    child: Text('Nenhuma disciplina encontrada.', style: TextStyle(fontSize: 16)),
                  );
                }

                final disciplinas = snapshot.data!;

                if (_progressoSalvo != null) {
                  return MapaPeriodosWidget(
                    key: const ValueKey('progresso-salvo'),
                    disciplinas: disciplinas,
                    uid: _uid,
                    estadoSalvo: _progressoSalvo,
                    matricula: _progressoSalvo!['matricula'] as String?,
                    onResetar: _resetarParaGradeOficial,
                  );
                }

                if (_periodosDaPlanilha == null) {
                  return MapaPeriodosWidget(
                    key: const ValueKey('grade-geral'),
                    disciplinas: disciplinas,
                    uid: _uid,
                    onResetar: _resetarParaGradeOficial,
                  );
                }

                // Grade oficial = códigos que a própria universidade indica
                // com período no currículo (não o catálogo geral, que
                // inclui opções de optativa/extensão).
                final gradeOficial = disciplinas
                    .where((d) => d.periodo != null)
                    .map((d) => d.codigo)
                    .toSet();
                final faltantes = {..._periodosDaPlanilha!.keys, ..._faltantesSemPeriodo};
                final concluidasIniciais = gradeOficial.difference(faltantes);

                return MapaPeriodosWidget(
                  key: const ValueKey('pendentes'),
                  disciplinas: disciplinas,
                  uid: _uid,
                  periodosPersonalizados: _periodosDaPlanilha,
                  faltantesSemPeriodo: _faltantesSemPeriodo,
                  concluidasIniciais: concluidasIniciais,
                  matricula: _matricula,
                  onResetar: _resetarParaGradeOficial,
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