import 'package:flutter/material.dart';
import '../models/disciplina_model.dart';
import '../services/momento_service.dart';
import '../services/progresso_service.dart';
import '../widgets/mapa_periodos/mapa_periodos_widget.dart';

class TelaMomentos extends StatefulWidget {
  final List<Disciplina> disciplinas;
  final String uid;

  const TelaMomentos({super.key, required this.disciplinas, required this.uid});

  @override
  State<TelaMomentos> createState() => _TelaMomentosState();
}

class _TelaMomentosState extends State<TelaMomentos> {
  final _momentoService = MomentoService();
  final _progressoService = ProgressoService();
  late Future<List<Momento>> _futureMomentos;

  @override
  void initState() {
    super.initState();
    _futureMomentos = _momentoService.listar(widget.uid);
  }

  void _recarregar() => setState(() => _futureMomentos = _momentoService.listar(widget.uid));

  Future<void> _excluir(Momento momento) async {
    await _momentoService.excluir(widget.uid, momento.id);
    _recarregar();
  }

  Future<void> _restaurar(Momento momento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar este momento?'),
        content: Text(
          'Isso substitui o seu grafo atual pelo estado salvo em "${momento.nome}". '
          'O que você tem agora só continua guardado se também tiver salvo como um momento.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmar != true) return;

    await _progressoService.salvar(
      uid: widget.uid,
      dados: momento.dados,
      matricula: momento.dados['matricula'] as String?,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _visualizar(Momento momento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Momento: ${momento.nome}')),
          body: MapaPeriodosWidget(
            disciplinas: widget.disciplinas,
            uid: widget.uid,
            estadoSalvo: momento.dados,
            somenteLeitura: true,
          ),
        ),
      ),
    );
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} '
      '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus momentos')),
      body: FutureBuilder<List<Momento>>(
        future: _futureMomentos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final momentos = snapshot.data ?? [];
          if (momentos.isEmpty) {
            return const Center(child: Text('Nenhum momento salvo ainda.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            itemCount: momentos.length,
            itemBuilder: (context, index) {
              final momento = momentos[index];
              return ListTile(
                title: Text(momento.nome),
                subtitle: momento.criadoEm != null ? Text(_formatarData(momento.criadoEm!)) : null,
                onTap: () => _visualizar(momento),
                trailing: PopupMenuButton<String>(
                  onSelected: (acao) {
                    if (acao == 'restaurar') _restaurar(momento);
                    if (acao == 'excluir') _excluir(momento);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'restaurar', child: Text('Restaurar como atual')),
                    PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}