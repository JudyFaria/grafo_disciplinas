import 'package:flutter/material.dart';
import '../models/disciplina_model.dart';
import '../models/cursos_disponiveis.dart';
import '../widgets/mapa_periodos/mapa_periodos_widget.dart';
import '../services/disciplina_service.dart';
import '../services/planilha_service.dart';
import '../services/progresso_service.dart';
import '../services/auth_service.dart';
import '../services/usuario_service.dart';
import 'tela_ajuda.dart';

import '../models/estado_grafo.dart';
import '../services/momento_service.dart';
import 'tela_momentos.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final DisciplinaService _disciplinaService = DisciplinaService();
  final PlanilhaService _planilhaService = PlanilhaService();
  final ProgressoService _progressoService = ProgressoService();
  final UsuarioService _usuarioService = UsuarioService();
  
  final MomentoService _momentoService = MomentoService();
  EstadoGrafo? _estadoAtual;
  
  Future<List<Disciplina>>? _futureDisciplinas;
  PerfilUsuario? _perfil;
  bool _carregandoPerfil = true;
  String _cursoEscolha = cursosDisponiveis.first.$1;

  Map<String, int>? _periodosDaPlanilha;
  Set<String> _faltantesSemPeriodo = {};
  String? _matricula;
  Map<String, dynamic>? _progressoSalvo;
  bool _carregandoProgresso = true;

  int _resetKey = 0;

  String get _uid => AuthService().usuarioAtual!.uid;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
    _carregarProgressoSalvo();
  }

  Future<void> _carregarPerfil() async {
    final perfil = await _usuarioService.carregarPerfil(_uid);
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _carregandoPerfil = false;
      if (perfil != null) {
        _futureDisciplinas = _disciplinaService.carregarDisciplinas(perfil.curso);
      }
    });
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao importar a planilha: $e')));
    }
  }

  void _resetarParaGradeOficial() {
    setState(() {
      _periodosDaPlanilha = null;
      _faltantesSemPeriodo = {};
      _matricula = null;
      _progressoSalvo = null;
      _resetKey++;
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

  void _abrirEscolhaCurso() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Seu curso'),
          content: DropdownButtonFormField<String>(
            initialValue: _perfil?.curso ?? _cursoEscolha,
            items: [
              for (final (valor, rotulo) in cursosDisponiveis)
                DropdownMenuItem(value: valor, child: Text(rotulo)),
            ],
            onChanged: (v) => setDialogState(() => _cursoEscolha = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _usuarioService.salvarPerfil(_uid, curso: _cursoEscolha);
                if (!mounted) return;
                setState(() {
                  _perfil = PerfilUsuario(curso: _cursoEscolha, nickname: _perfil?.nickname);
                  _futureDisciplinas = _disciplinaService.carregarDisciplinas(_cursoEscolha);
                  _progressoSalvo = null;
                  _periodosDaPlanilha = null;
                  _faltantesSemPeriodo = {};
                });
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirSalvarMomento() async {
    if (_estadoAtual == null) return;
    final nomeController = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar momento'),
        content: TextField(
          controller: nomeController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome (ex: Plano A — foco em IA)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, nomeController.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (nome == null || nome.isEmpty) return;

    try {
      await _momentoService.salvar(_uid, nome, _estadoAtual!.paraSalvar());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Momento "$nome" salvo!')));
    } catch (e) {
      debugPrint('Erro ao salvar momento: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  Future<void> _recarregarAposRestaurar() async {
    final dados = await _progressoService.carregar(_uid);
    if (!mounted) return;
    setState(() {
      _progressoSalvo = dados;
      _periodosDaPlanilha = null;
      _faltantesSemPeriodo = {};
      _matricula = null;
      _resetKey++;
    });
  }

  Future<void> _abrirMeusMomentos() async {
    if (_futureDisciplinas == null) return;
    final disciplinas = await _futureDisciplinas!;
    if (!mounted) return;
    final precisaRecarregar = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TelaMomentos(disciplinas: disciplinas, uid: _uid)),
    );
    if (precisaRecarregar == true) _recarregarAposRestaurar();
  }
  

  Widget _construirMenu() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  (_perfil?.nickname?.isNotEmpty ?? false) ? 'Olá, ${_perfil!.nickname}' : 'GradeFlow',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Meu curso'),
              subtitle: Text(
                cursosDisponiveis.firstWhere((c) => c.$1 == _perfil?.curso, orElse: () => cursosDisponiveis.first).$2,
              ),
              onTap: () {
                Navigator.pop(context);
                _abrirEscolhaCurso();
              },
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
              onTap: () {
                Navigator.pop(context);
                _abrirSalvarMomento();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Meus momentos'),
              onTap: () {
                Navigator.pop(context);
                _abrirMeusMomentos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Como usar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaAjuda()));
              },
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
        title: const Text('GradeFlow'),
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
                  return const Center(child: Text('Nenhuma disciplina encontrada.', style: TextStyle(fontSize: 16)));
                }

                final disciplinas = snapshot.data!;

                if (_progressoSalvo != null) {
                  return MapaPeriodosWidget(
                    key: ValueKey('progresso-salvo-$_resetKey'),
                    disciplinas: disciplinas,
                    uid: _uid,
                    estadoSalvo: _progressoSalvo,
                    matricula: _progressoSalvo!['matricula'] as String?,
                    onEstadoCriado: (estado) => _estadoAtual = estado,
                  );
                }

                if (_periodosDaPlanilha == null) {
                  return MapaPeriodosWidget(
                    key: ValueKey('grade-geral-$_resetKey'),
                    disciplinas: disciplinas,
                    uid: _uid,
                    onEstadoCriado: (estado) => _estadoAtual = estado,
                  );
                }

                final gradeOficial = disciplinas.where((d) => d.periodo != null).map((d) => d.codigo).toSet();
                final faltantes = {..._periodosDaPlanilha!.keys, ..._faltantesSemPeriodo};
                final concluidasIniciais = gradeOficial.difference(faltantes);

                return MapaPeriodosWidget(
                  key: ValueKey('pendentes-$_resetKey'),
                  disciplinas: disciplinas,
                  uid: _uid,
                  periodosPersonalizados: _periodosDaPlanilha,
                  faltantesSemPeriodo: _faltantesSemPeriodo,
                  concluidasIniciais: concluidasIniciais,
                  matricula: _matricula,
                  onEstadoCriado: (estado) => _estadoAtual = estado,
                );
              },
      ),
    );
  }
}