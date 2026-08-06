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

  void _resetarParaGradeOficial() {
    setState(() {
      _periodosDaPlanilha = null;
      _faltantesSemPeriodo = {};
      _matricula = null;
      _progressoSalvo = null;
    });
  }

  void _confirmarReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetar para o padrão da universidade?'),
        content: const Text(
          'Isso descarta a planilha importada e qualquer alteração manual, '
          'voltando pra grade oficial da PUC do zero, como um usuário novo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _resetarParaGradeOficial();
            },
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
  }

  Widget _construirMenu() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Mapa de Matérias', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Importar pendências'),
              onTap: () {
                Navigator.pop(context);
                _importarPendencias();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Resetar para grade oficial'),
              onTap: () {
                Navigator.pop(context);
                _confirmarReset();
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_outlined),
              title: const Text('Salvar momento'),
              subtitle: const Text('em breve'),
              enabled: false,
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () {
                Navigator.pop(context);
                AuthService().sair();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Pré-requisitos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: _construirMenu(),
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
                  );
                }

                if (_periodosDaPlanilha == null) {
                  return MapaPeriodosWidget(
                    key: const ValueKey('grade-geral'),
                    disciplinas: disciplinas,
                    uid: _uid,
                  );
                }

                final gradeOficial =
                    disciplinas.where((d) => d.periodo != null).map((d) => d.codigo).toSet();
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
                );
              },
            ),
    );
  }
}