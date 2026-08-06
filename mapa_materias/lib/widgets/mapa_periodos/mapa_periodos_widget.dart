import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/disciplina_model.dart';
import '../../models/semestre_academico.dart';
import '../../models/estado_grafo.dart';
import '../../services/progresso_service.dart';
import 'card_arrastavel.dart';
import 'setas_painter.dart';

class MapaPeriodosWidget extends StatefulWidget {
  final List<Disciplina> disciplinas;
  final String uid;
  final Map<String, int>? periodosPersonalizados;
  final Set<String> concluidasIniciais;
  final Set<String> faltantesSemPeriodo;
  final String? matricula;
  final Map<String, dynamic>? estadoSalvo;
  final VoidCallback? onResetar;

  const MapaPeriodosWidget({
    super.key,
    required this.disciplinas,
    required this.uid,
    this.periodosPersonalizados,
    this.concluidasIniciais = const {},
    this.faltantesSemPeriodo = const {},
    this.matricula,
    this.estadoSalvo,
    this.onResetar,
  });

  @override
  State<MapaPeriodosWidget> createState() => _MapaPeriodosWidgetState();
}

class _MapaPeriodosWidgetState extends State<MapaPeriodosWidget> {
  static const double _larguraColuna = 200;
  static const double _espacoColuna = 48;
  static const double _alturaCard = 56;
  static const double _espacoCard = 12;
  static const double _alturaCabecalho = 44;
  static const List<MaterialColor> _paleta = [
    Colors.blue, Colors.teal, Colors.deepPurple, Colors.orange,
    Colors.green, Colors.indigo, Colors.brown, Colors.pink, Colors.cyan,
  ];

  late final EstadoGrafo _estado;
  final ProgressoService _progressoService = ProgressoService();
  final ValueNotifier<bool> _dropInvalido = ValueNotifier(false);
  Set<String> _destacados = {};
  Timer? _timerDestaque;

  String? _codigoSelecionado;
  String? _codigoHover;

  String? get _codigoEmFoco => _codigoHover ?? _codigoSelecionado;

  void _alternarSelecao(String codigo) {
    setState(() => _codigoSelecionado = _codigoSelecionado == codigo ? null : codigo);
  }

  void _setHover(String codigo, bool entrou) {
    setState(() => _codigoHover = entrou ? codigo : (_codigoHover == codigo ? null : _codigoHover));
  }

  @override
  void initState() {
    super.initState();
    _estado = EstadoGrafo(
      disciplinas: widget.disciplinas,
      periodosPersonalizados: widget.periodosPersonalizados,
      concluidasIniciais: widget.concluidasIniciais,
      faltantesSemPeriodo: widget.faltantesSemPeriodo,
      estadoSalvo: widget.estadoSalvo,
    );
    _estado.addListener(_salvarProgresso);
    _salvarProgresso();
  }

  void _salvarProgresso() {
    _progressoService.salvar(
      uid: widget.uid,
      dados: _estado.paraSalvar(),
      matricula: widget.matricula,
    );
  }

  void _destacar(Set<String> codigos) {
    if (codigos.isEmpty) return;
    setState(() => _destacados = codigos);
    _timerDestaque?.cancel();
    _timerDestaque = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _destacados = {});
    });
  }

  @override
  void dispose() {
    _estado.removeListener(_salvarProgresso);
    _timerDestaque?.cancel();
    _dropInvalido.dispose();
    super.dispose();
  }

  void _confirmarReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetar para o padrão da universidade?'),
        content: const Text(
          'Isso desfaz arrastes, escolhas de optativa e concluídas marcadas '
          'manualmente, voltando pra grade oficial sugerida pela PUC.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onResetar?.call();
            },
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
  }

  void _abrirEscolhaOptativa(String codigoSlot) {
    final original = _estado.porCodigoOriginal[codigoSlot]!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Escolher matéria — ${original.nome}'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var codigoOpcao in original.grupoDisciplinas)
                ListTile(
                  title: Text(codigoOpcao),
                  subtitle: Text(_estado.porCodigoOriginal[codigoOpcao]?.nome ?? '(sem ementa)'),
                  selected: _estado.escolhaOptativa[codigoSlot] == codigoOpcao,
                  onTap: () {
                    Navigator.pop(context);
                    _destacar(_estado.escolherOptativa(codigoSlot, codigoOpcao));
                  },
                ),
              if (_estado.escolhaOptativa.containsKey(codigoSlot))
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Remover escolha'),
                  onTap: () {
                    Navigator.pop(context);
                    _estado.desfazerEscolha(codigoSlot);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _estado, builder: (context, _) => _construirConteudo());
  }

  Widget _construirConteudo() {
    final semPeriodo = _estado.porCodigo.values
        .where((d) =>
            !_estado.semestre.containsKey(d.codigo) &&
            !_estado.concluidas.contains(d.codigo) &&
            !_estado.codigosDeOpcaoApenas.contains(d.codigo))
        .toList();

    final usados = _estado.todosOsSemestresUsados();
    final colunas = <SemestreAcademico>[];
    if (usados.isNotEmpty) {
      final ordenados = usados.toList()..sort();
      var atual = ordenados.first;
      while (atual.compareTo(ordenados.last) <= 0) {
        colunas.add(atual);
        atual = atual.avancar(1);
      }
    }

    final porColuna = <SemestreAcademico, List<Disciplina>>{for (var s in colunas) s: []};
    for (var d in _estado.porCodigo.values) {
      final s = _estado.semestre[d.codigo];
      if (s != null) porColuna[s]!.add(d);
    }

    final posicoes = <String, Offset>{};
    var maiorAltura = _alturaCabecalho;
    for (var col = 0; col < colunas.length; col++) {
      final x = col * (_larguraColuna + _espacoColuna);
      final itens = porColuna[colunas[col]]!;
      for (var linha = 0; linha < itens.length; linha++) {
        posicoes[itens[linha].codigo] =
            Offset(x, _alturaCabecalho + linha * (_alturaCard + _espacoCard));
      }
      final altura = _alturaCabecalho + itens.length * (_alturaCard + _espacoCard);
      if (altura > maiorAltura) maiorAltura = altura;
    }
    final larguraGrade =
        colunas.isEmpty ? 0.0 : colunas.length * (_larguraColuna + _espacoColuna) - _espacoColuna;

    final arestas = <(String, String)>[];
    for (var d in _estado.porCodigo.values) {
      if (!_estado.semestre.containsKey(d.codigo)) continue;
      for (var codigo in _estado.codigosRelevantes(d)) {
        if (_estado.semestre.containsKey(codigo)) arestas.add((codigo, d.codigo));
      }
    }

    final foco = _codigoEmFoco;
    final relacionados = <String>{};
    if (foco != null) {
      for (final (origemCodigo, destinoCodigo) in arestas) {
        if (origemCodigo == foco) relacionados.add(destinoCodigo);
        if (destinoCodigo == foco) relacionados.add(origemCodigo);
      }
    }

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _colunaConcluidas(foco, relacionados),
            const SizedBox(width: 16),
            _colunaSemPeriodo(semPeriodo, foco, relacionados),
            const SizedBox(width: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: larguraGrade + _larguraColuna + _espacoColuna,
                    height: maiorAltura,
                    child: Stack(
                      children: [
                        for (var col = 0; col < colunas.length; col++) ...[
                          Positioned(
                            left: col * (_larguraColuna + _espacoColuna),
                            top: 0,
                            width: _larguraColuna,
                            height: maiorAltura,
                            child: DragTarget<String>(
                              onWillAcceptWithDetails: (details) {
                                final pode = _estado.podeSoltarEm(details.data, colunas[col]);
                                _dropInvalido.value = !pode;
                                return pode;
                              },
                              onLeave: (_) => _dropInvalido.value = false,
                              onAcceptWithDetails: (details) {
                                _dropInvalido.value = false;
                                _destacar(_estado.moverDisciplina(details.data, colunas[col]));
                              },
                              builder: (context, candidate, rejected) => Container(
                                color: candidate.isNotEmpty
                                    ? _paleta[col % _paleta.length].withOpacity(0.15)
                                    : rejected.isNotEmpty
                                        ? Colors.red.withOpacity(0.15)
                                        : Colors.transparent,
                              ),
                            ),
                          ),
                          Positioned(
                            left: col * (_larguraColuna + _espacoColuna),
                            top: 0,
                            width: _larguraColuna,
                            child: Container(
                              height: _alturaCabecalho,
                              decoration: BoxDecoration(
                                color: _paleta[col % _paleta.length].shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    colunas[col].toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _paleta[col % _paleta.length].shade900,
                                    ),
                                  ),
                                  if (porColuna[colunas[col]]!.isEmpty &&
                                      (col == 0 || col == colunas.length - 1))
                                    Positioned(
                                      right: 0,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        tooltip: 'Remover coluna vazia',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _estado.removerColuna(colunas[col]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          for (var d in porColuna[colunas[col]]!)
                            Positioned(
                              left: posicoes[d.codigo]!.dx,
                              top: posicoes[d.codigo]!.dy,
                              width: _larguraColuna,
                              height: _alturaCard,
                              child: CardArrastavel(
                                disciplina: d,
                                cor: _paleta[col % _paleta.length],
                                dropInvalido: _dropInvalido,
                                destacado: _destacados.contains(d.codigo),
                                emFoco: d.codigo == foco,
                                conectado: relacionados.contains(d.codigo),
                                ehOptativa:
                                    _estado.porCodigoOriginal[d.codigo]!.grupoDisciplinas.isNotEmpty,
                                optativaResolvida: _estado.escolhaOptativa.containsKey(d.codigo),
                                onTapOptativa: () => _abrirEscolhaOptativa(d.codigo),
                                onTap: () => _alternarSelecao(d.codigo),
                                onHover: (entrou) => _setHover(d.codigo, entrou),
                              ),
                            ),
                        ],
                        Positioned(
                          left: colunas.length * (_larguraColuna + _espacoColuna),
                          top: 0,
                          width: _larguraColuna,
                          child: Column(
                            children: [
                              SizedBox(
                                height: _alturaCabecalho,
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed: _estado.adicionarProximoPeriodo,
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Período'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _confirmarReset,
                                icon: const Icon(Icons.restart_alt, size: 16),
                                label: const Text('Resetar'),
                              ),
                            ],
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            size: Size(larguraGrade, maiorAltura),
                            painter: SetasPainter(
                              arestas: arestas,
                              posicoes: posicoes,
                              larguraCard: _larguraColuna,
                              alturaCard: _alturaCard,
                              destacados: _destacados,
                              codigoFoco: foco,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colunaConcluidas(String? foco, Set<String> relacionados) {
    final itens = _estado.porCodigo.values.where((d) => _estado.concluidas.contains(d.codigo)).toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));

    return SizedBox(
      width: _larguraColuna,
      child: DragTarget<String>(
        onAcceptWithDetails: (details) => _estado.marcarConcluida(details.data),
        builder: (context, candidate, rejected) => Container(
          decoration: BoxDecoration(
            color: candidate.isNotEmpty ? Colors.green.withOpacity(0.08) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: _alturaCabecalho,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: candidate.isNotEmpty ? Colors.green.shade200 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Concluídas', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (var d in itens)
                      Padding(
                        padding: const EdgeInsets.only(bottom: _espacoCard),
                        child: CardArrastavel(
                          disciplina: d,
                          cor: Colors.green,
                          dropInvalido: _dropInvalido,
                          emFoco: d.codigo == foco,
                          conectado: relacionados.contains(d.codigo),
                          onTap: () => _alternarSelecao(d.codigo),
                          onHover: (entrou) => _setHover(d.codigo, entrou),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colunaSemPeriodo(List<Disciplina> itens, String? foco, Set<String> relacionados) {
    return SizedBox(
      width: _larguraColuna,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => _estado.naoTemPeriodoDefinido(details.data),
        onAcceptWithDetails: (details) => _estado.removerDoGrafo(details.data),
        builder: (context, candidate, rejected) => Container(
          decoration: BoxDecoration(
            color: candidate.isNotEmpty ? Colors.grey.withOpacity(0.15) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: _alturaCabecalho,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: candidate.isNotEmpty ? Colors.grey.shade400 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Sem período definido', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (var d in itens)
                      Padding(
                        padding: const EdgeInsets.only(bottom: _espacoCard),
                        child: CardArrastavel(
                          disciplina: d,
                          cor: Colors.grey,
                          dropInvalido: _dropInvalido,
                          emFoco: d.codigo == foco,
                          conectado: relacionados.contains(d.codigo),
                          ehOptativa: _estado.porCodigoOriginal[d.codigo]?.grupoDisciplinas.isNotEmpty ?? false,
                          optativaResolvida: _estado.escolhaOptativa.containsKey(d.codigo),
                          onTapOptativa: () => _abrirEscolhaOptativa(d.codigo),
                          onTap: () => _alternarSelecao(d.codigo),
                          onHover: (entrou) => _setHover(d.codigo, entrou),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}