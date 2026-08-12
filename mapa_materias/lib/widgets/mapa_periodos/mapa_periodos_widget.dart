import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/disciplina_model.dart';
import '../../models/semestre_academico.dart';
import '../../models/estado_grafo.dart';
import '../../services/progresso_service.dart';
import 'card_arrastavel.dart';
import 'setas_painter.dart';
import 'secao_expansivel.dart';

import 'package:flutter/foundation.dart';

class MapaPeriodosWidget extends StatefulWidget {
  final List<Disciplina> disciplinas;
  final String uid;
  final Map<String, int>? periodosPersonalizados;
  final Set<String> concluidasIniciais;
  final Set<String> faltantesSemPeriodo;
  final String? matricula;
  final Map<String, dynamic>? estadoSalvo;

  const MapaPeriodosWidget({
    super.key,
    required this.disciplinas,
    required this.uid,
    this.periodosPersonalizados,
    this.concluidasIniciais = const {},
    this.faltantesSemPeriodo = const {},
    this.matricula,
    this.estadoSalvo,
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

  void _abrirEscolhaGrupoPrereq(String codigo) {
    final disciplina = _estado.porCodigoOriginal[codigo]!;
    final grupos = _estado.gruposPrereqValidos(codigo);
    final grupoAtivo = _estado.grupoPrereqAtivo(codigo);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Pré-requisito usado — ${disciplina.nome}'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < grupos.length; i++)
                ListTile(
                  title: Text(grupos[i].join(' + ')),
                  selected: setEquals(grupos[i], grupoAtivo),
                  onTap: () {
                    Navigator.pop(context);
                    _destacar(_estado.escolherGrupoPrereq(codigo, i));
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _estado, builder: (context, _) => _construirConteudo());
  }

  Widget _cardCompacto(Disciplina d, MaterialColor cor, String? foco, Set<String> relacionados,
      {bool ehOptativa = false, bool optativaResolvida = false}) {
    return SizedBox(
      width: 160,
      height: _alturaCard,
      child: CardArrastavel(
        disciplina: d,
        cor: cor,
        dropInvalido: _dropInvalido,
        emFoco: d.codigo == foco,
        conectado: relacionados.contains(d.codigo),
        ehOptativa: ehOptativa,
        optativaResolvida: optativaResolvida,
        onTapOptativa: ehOptativa ? () => _abrirEscolhaOptativa(d.codigo) : null,
        onTap: () => _alternarSelecao(d.codigo),
        onHover: (entrou) => _setHover(d.codigo, entrou),
        
        onTapAlternativasPrereq: () => _abrirEscolhaGrupoPrereq(d.codigo),
      ),
    );
  }

  Widget _construirConteudo() {
    final semPeriodo = _estado.porCodigo.values
        .where((d) =>
            !_estado.semestre.containsKey(d.codigo) &&
            !_estado.concluidas.contains(d.codigo) &&
            !_estado.codigosDeOpcaoApenas.contains(d.codigo))
        .toList();
    final concluidas = _estado.porCodigo.values.where((d) => _estado.concluidas.contains(d.codigo)).toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SecaoExpansivel(
              titulo: 'Concluídas',
              quantidade: concluidas.length,
              cor: Colors.green,
              inicialmenteAberta: false,
              aoAceitar: _estado.marcarConcluida,
              itens: [
                for (var d in concluidas) _cardCompacto(d, Colors.green, foco, relacionados),
              ],
            ),
            SecaoExpansivel(
              titulo: 'Sem período fixo',
              quantidade: semPeriodo.length,
              cor: Colors.grey,
              inicialmenteAberta: true,
              podeAceitar: _estado.naoTemPeriodoDefinido,
              aoAceitar: _estado.removerDoGrafo,
              itens: [
                for (var d in semPeriodo)
                  _cardCompacto(
                    d, Colors.grey, foco, relacionados,
                    ehOptativa: _estado.porCodigoOriginal[d.codigo]?.grupoDisciplinas.isNotEmpty ?? false,
                    optativaResolvida: _estado.escolhaOptativa.containsKey(d.codigo),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(120),
                minScale: 0.4,
                maxScale: 2.5,
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

                              temAlternativasPrereq: _estado.temMultiplosGruposPrereq(d.codigo),
                              onTapAlternativasPrereq: () => _abrirEscolhaGrupoPrereq(d.codigo),
                            ),
                          ),
                      ],
                      Positioned(
                        left: colunas.length * (_larguraColuna + _espacoColuna),
                        top: 0,
                        width: _larguraColuna,
                        height: _alturaCabecalho,
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: _estado.adicionarProximoPeriodo,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Período'),
                          ),
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
          ],
        ),
      ),
    );
  }
}