import 'package:flutter/material.dart';
import '../models/disciplina_model.dart';
import '../models/bloco_horario.dart';
import '../services/horario_service.dart';

class TelaHorarios extends StatefulWidget {
  final List<Disciplina> disciplinas;
  final String uid;
  final String semestreChave;

  const TelaHorarios({
    super.key,
    required this.disciplinas,
    required this.uid,
    required this.semestreChave,
  });

  @override
  State<TelaHorarios> createState() => _TelaHorariosState();
}

class _TelaHorariosState extends State<TelaHorarios> {
  final _horarioService = HorarioService();
  List<BlocoHorario> _blocos = [];
  bool _carregando = true;
  bool _colunaAberta = true;

  static const _dias = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
  static const _blocosDeHora = [7, 9, 11, 13, 15, 17, 19]; // início de cada bloco de 2h
  static const _alturaBloco = 72.0;
  static const _larguraDia = 150.0;
  static const _larguraHora = 64.0;
  static const _alturaCabecalho = 36.0;
  static const _larguraListaDisciplinas = 220.0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final blocos = await _horarioService.carregar(widget.uid, widget.semestreChave);
    if (!mounted) return;
    setState(() {
      _blocos = blocos;
      _carregando = false;
    });
  }

  Future<void> _salvar() => _horarioService.salvar(widget.uid, widget.semestreChave, _blocos);

  MaterialColor _corPara(String codigo) {
    const paleta = [
      Colors.blue, Colors.teal, Colors.deepPurple, Colors.orange,
      Colors.green, Colors.indigo, Colors.brown, Colors.pink, Colors.cyan,
    ];
    return paleta[codigo.hashCode.abs() % paleta.length];
  }

  BlocoHorario? _blocoEm(int dia, int horaInicio) {
    for (var b in _blocos) {
      if (b.diaSemana == dia && b.horaInicio == horaInicio) return b;
    }
    return null;
  }

  Future<void> _abrirAdicionarNaGrade(Disciplina d) async {
    int horaSelecionada = _blocosDeHora.first;
    final diasSelecionados = <int>{};
    final salaController = TextEditingController();
    String? erro;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${d.codigo} — ${d.nome}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Horário', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: horaSelecionada,
                  items: [
                    for (var h in _blocosDeHora)
                      DropdownMenuItem(value: h, child: Text('${h}h-${h + 2}h')),
                  ],
                  onChanged: (v) => setDialogState(() => horaSelecionada = v!),
                ),
                const SizedBox(height: 12),
                const Text('Dias da semana', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < _dias.length; i++)
                      FilterChip(
                        label: Text(_dias[i]),
                        selected: diasSelecionados.contains(i + 1),
                        onSelected: (marcado) => setDialogState(() {
                          if (marcado) {
                            diasSelecionados.add(i + 1);
                          } else {
                            diasSelecionados.remove(i + 1);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salaController,
                  decoration: const InputDecoration(labelText: 'Sala / local'),
                ),
                if (erro != null) ...[
                  const SizedBox(height: 8),
                  Text(erro!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: diasSelecionados.isEmpty
                  ? null
                  : () {
                      BlocoHorario? conflito;
                      for (var dia in diasSelecionados) {
                        conflito = _blocoEm(dia, horaSelecionada);
                        if (conflito != null) break;
                      }
                      if (conflito != null) {
                        setDialogState(() {
                          erro =
                              'Já tem ${conflito!.codigoDisciplina} nesse horário em ${_dias[conflito.diaSemana - 1]}';
                        });
                        return;
                      }
                      setState(() {
                        for (var dia in diasSelecionados) {
                          _blocos.add(BlocoHorario(
                            codigoDisciplina: d.codigo,
                            diaSemana: dia,
                            horaInicio: horaSelecionada,
                            sala: salaController.text.trim(),
                          ));
                        }
                      });
                      _salvar();
                      Navigator.pop(context);
                    },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirOpcoesBloco(BlocoHorario bloco) async {
    final salaController = TextEditingController(text: bloco.sala);

    final acao = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
        title: Text(bloco.codigoDisciplina),
        content: TextField(
            controller: salaController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Sala / local'),
        ),
        actions: [
            TextButton(
            onPressed: () => Navigator.pop(context, 'remover'),
            child: const Text('Remover da grade', style: TextStyle(color: Colors.red)),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, 'salvar'), child: const Text('Salvar')),
        ],
        ),
    );

    if (acao == 'remover') {
        setState(() => _blocos.removeWhere((b) => b.codigoDisciplina == bloco.codigoDisciplina));
        _salvar();
    } else if (acao == 'salvar') {
        final novaSala = salaController.text.trim();
        setState(() {
        _blocos = _blocos.map((b) {
            if (b.codigoDisciplina != bloco.codigoDisciplina) return b;
            return BlocoHorario(
            codigoDisciplina: b.codigoDisciplina,
            diaSemana: b.diaSemana,
            horaInicio: b.horaInicio,
            sala: novaSala,
            );
        }).toList();
        });
        _salvar();
    }
    }

  @override
  Widget build(BuildContext context) {
    final larguraGrade = _larguraHora + _dias.length * _larguraDia;
    final alturaGrade = _alturaCabecalho + _blocosDeHora.length * _alturaBloco;
    final codigosNaGrade = _blocos.map((b) => b.codigoDisciplina).toSet();
    final disciplinasDisponiveis =
        widget.disciplinas.where((d) => !codigosNaGrade.contains(d.codigo)).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Horário — ${widget.semestreChave}')),
      body: widget.disciplinas.isEmpty
          ? const Center(
              child: Text('Nenhuma matéria no período atual pra montar horário.',
                  style: TextStyle(color: Colors.grey)),
            )
          : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (disciplinasDisponiveis.isNotEmpty) _listaDisciplinas(disciplinasDisponiveis),
                Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                            final conteudo = SizedBox(
                            width: larguraGrade,
                            height: alturaGrade,
                            child: _grade(),
                            );
                            if (larguraGrade <= constraints.maxWidth) {
                            return SingleChildScrollView(
                                child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(child: conteudo),
                                ),
                            );
                            }
                            return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(padding: const EdgeInsets.all(16), child: conteudo),
                            );
                        },
                    ),
                ),
            ],
        ),
    );
  }

  Widget _listaDisciplinas(List<Disciplina> disciplinas) {
    if (!_colunaAberta) {
        return Container(
        width: 40,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
        child: Column(
            children: [
            const SizedBox(height: 4),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Mostrar matérias',
                onPressed: () => setState(() => _colunaAberta = true),
            ),
            ],
        ),
        );
    }

    return Container(
        width: _larguraListaDisciplinas,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                const Text('Toque pra adicionar', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Esconder',
                onPressed: () => setState(() => _colunaAberta = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                ),
            ],
            ),
            const SizedBox(height: 8),
            Expanded(
            child: ListView(
                children: [
                for (var d in disciplinas)
                    Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _abrirAdicionarNaGrade(d),
                        child: _cardDisciplina(d),
                    ),
                    ),
                ],
            ),
            ),
        ],
        ),
    );
  }

  Widget _cardDisciplina(Disciplina d) {
    final cor = _corPara(d.codigo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cor, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(d.codigo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cor.shade900)),
          Text(d.nome, style: const TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _grade() {
    return Stack(
      children: [
        for (var d = 0; d < _dias.length; d++)
          Positioned(
            left: _larguraHora + d * _larguraDia,
            top: 0,
            width: _larguraDia,
            height: _alturaCabecalho,
            child: Container(
              alignment: Alignment.center,
              color: Colors.blue.shade50,
              child: Text(_dias[d], style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        for (var h = 0; h < _blocosDeHora.length; h++)
          Positioned(
            left: 0,
            top: _alturaCabecalho + h * _alturaBloco,
            width: _larguraHora,
            height: _alturaBloco,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Text(
                '${_blocosDeHora[h]}h-${_blocosDeHora[h] + 2}h',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        for (var d = 1; d <= _dias.length; d++)
          for (var h = 0; h < _blocosDeHora.length; h++)
            Positioned(
              left: _larguraHora + (d - 1) * _larguraDia,
              top: _alturaCabecalho + h * _alturaBloco,
              width: _larguraDia,
              height: _alturaBloco,
              child: _celula(d, _blocosDeHora[h]),
            ),
      ],
    );
  }

  Widget _celula(int dia, int horaInicio) {
    final bloco = _blocoEm(dia, horaInicio);

    if (bloco == null) {
      return Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200)),
      );
    }

    final cor = _corPara(bloco.codigoDisciplina);
    return GestureDetector(
      onTap: () => _abrirOpcoesBloco(bloco),
      child: Container(
        margin: const EdgeInsets.all(1),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: cor.shade100, border: Border.all(color: cor, width: 2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(bloco.codigoDisciplina,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cor.shade900)),
            if (bloco.sala.isNotEmpty)
              Text(bloco.sala, style: TextStyle(fontSize: 11, color: cor.shade900)),
          ],
        ),
      ),
    );
  }
}