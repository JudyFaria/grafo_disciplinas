// lib/widgets/mapa_periodos.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/disciplina_model.dart';
import '../models/semestre_academico.dart';
import '../services/progresso_service.dart';

class MapaPeriodosWidget extends StatefulWidget {
  final List<Disciplina> disciplinas;
  final Map<String, int>? periodosPersonalizados;
  final Set<String> concluidasIniciais;

  final String uid;
  final String? matricula; 
  final Map<String, dynamic>? estadoSalvo;

  const MapaPeriodosWidget({
    super.key,
    required this.disciplinas,
    required this.uid,
    this.periodosPersonalizados,
    this.concluidasIniciais = const {},
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

  late Map<String, Disciplina> _porCodigo;
  late Map<String, List<String>> _dependentesDiretos;
  late Map<String, Set<String>> _coRequisitosDiretos;
  final Map<String, SemestreAcademico> _semestre = {};
  final Set<SemestreAcademico> _colunasExtras = {}; // adicionadas manualmente
  late Set<String> _concluidas;
  final ValueNotifier<bool> _dropInvalido = ValueNotifier(false);
  Set<String> _destacados = {};
  Timer? _timerDestaque;

  final ProgressoService _progressoService = ProgressoService();

  @override
  void initState() {
    super.initState();
    _porCodigo = {for (var d in widget.disciplinas) d.codigo: d};
    _construirDependencias();

    if (widget.estadoSalvo != null) {
      _restaurarDeEstadoSalvo(widget.estadoSalvo!);
    } else {
      _concluidas = {...widget.concluidasIniciais};
      final base = SemestreAcademico.deData(DateTime.now());
      for (var d in widget.disciplinas) {
        if (_concluidas.contains(d.codigo)) continue;
        final periodo = widget.periodosPersonalizados?[d.codigo] ?? d.periodo;
        if (periodo != null) {
          _semestre[d.codigo] = base.avancar(periodo - 1);
        }
      }
    }
  }

  void _restaurarDeEstadoSalvo(Map<String, dynamic> dados) {
    _concluidas = Set<String>.from(dados['concluidas'] as List? ?? []);

    final semestreSalvo = dados['semestre'] as Map<String, dynamic>? ?? {};
    for (var entry in semestreSalvo.entries) {
      final s = entry.value as Map<String, dynamic>;
      _semestre[entry.key] = SemestreAcademico(s['ano'] as int, s['semestre'] as int);
    }

    for (var s in (dados['colunasExtras'] as List? ?? [])) {
      _colunasExtras.add(SemestreAcademico(s['ano'] as int, s['semestre'] as int));
    }
  }

  void _salvarProgresso() {
    _progressoService.salvar(
      uid: widget.uid,
      semestre: _semestre,
      concluidas: _concluidas,
      colunasExtras: _colunasExtras,
      matricula: widget.matricula,
    );
  }

  @override
  void dispose() {
    _timerDestaque?.cancel();
    _dropInvalido.dispose();
    super.dispose();
  }

  void _construirDependencias() {
    _dependentesDiretos = {};
    _coRequisitosDiretos = {};
    for (var d in widget.disciplinas) {
      for (var codigo in _codigosRelevantes(d)) {
        _dependentesDiretos.putIfAbsent(codigo, () => []).add(d.codigo);
      }
      for (var coReqBruto in d.coRequisitos) {
        final coReq = coReqBruto.trim();
        if (!_porCodigo.containsKey(coReq)) continue;
        _coRequisitosDiretos.putIfAbsent(d.codigo, () => {}).add(coReq);
        _coRequisitosDiretos.putIfAbsent(coReq, () => {}).add(d.codigo);
      }
    }
  }

  // Códigos usados pra aresta/cascata: interseção (obrigatório de fato) se
  // houver; senão, união dos códigos que existem de verdade no currículo —
  // cobre o caso de OU puro (ex: MAT4162).
  Set<String> _codigosRelevantes(Disciplina d) {
    if (d.preRequisitos.isEmpty) return {};
    final grupos = d.preRequisitos.map((g) => g.map((c) => c.trim()).toSet()).toList();
    final comuns = grupos.reduce((a, b) => a.intersection(b));
    if (comuns.isNotEmpty) return comuns;

    final uniao = grupos.expand((g) => g).toSet();
    return uniao.where((c) => _porCodigo.containsKey(c)).toSet();
  }

  // Verifica ANTES de aceitar o drop. Trata OU de verdade: basta 1 grupo
  // (caminho alternativo) inteiro satisfeito antes do destino pra liberar.
  bool _podeSoltarEm(String codigo, SemestreAcademico destino) {
    final disciplina = _porCodigo[codigo];
    
    if (disciplina == null) return true;
    
    for (var prereq in _codigosRelevantes(disciplina)) {
        if (_concluidas.contains(prereq)) continue;
        
        final semestrePrereq = _semestre[prereq];
        if (semestrePrereq != null && destino.compareTo(semestrePrereq) <= 0) {
            return false;
        }
    }
    return true;
  }

  void _moverDisciplina(String codigo, SemestreAcademico destino) {
    setState(() {
      _concluidas.remove(codigo); // se estava marcada como concluída, agora não está mais
      _semestre[codigo] = destino;
      
      final mudados = {codigo, ..._propagarAPartirDe(codigo)};
      _destacados = mudados;
    });
    
    _timerDestaque?.cancel();
    _timerDestaque = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _destacados = {});
    });

    _salvarProgresso();
  }

  // Pré-requisito empurra o dependente pra FRENTE; co-requisito puxa pro
  // MESMO semestre. Retorna quem mudou, pra destacar na tela.
  Set<String> _propagarAPartirDe(String codigoMovido) {
    final mudados = <String>{};
    final fila = [codigoMovido];
    var protecaoContraCiclo = 0;
    while (fila.isNotEmpty && protecaoContraCiclo < 500) {
      protecaoContraCiclo++;
      final atual = fila.removeAt(0);
      final semestreAtual = _semestre[atual];
      if (semestreAtual == null) continue;

      for (var dep in _dependentesDiretos[atual] ?? const <String>[]) {
        final minimo = semestreAtual.avancar(1);
        final semestreDep = _semestre[dep];
        if (semestreDep == null || semestreDep.compareTo(minimo) < 0) {
          _semestre[dep] = minimo;
          mudados.add(dep);
          fila.add(dep);
        }
      }

      for (var coReq in _coRequisitosDiretos[atual] ?? const <String>{}) {
        if (_semestre[coReq] != semestreAtual) {
          _semestre[coReq] = semestreAtual;
          mudados.add(coReq);
          fila.add(coReq);
        }
      }
    }
    return mudados;
  }

  Set<SemestreAcademico> _todosOsSemestresUsados() {
    final atual = SemestreAcademico.deData(DateTime.now());
    return {atual, ..._semestre.values, ..._colunasExtras};
  }

  void _adicionarProximoPeriodo() {
    setState(() {
      final usados = _todosOsSemestresUsados();
      final ultimo = usados.isEmpty
          ? SemestreAcademico.deData(DateTime.now())
          : (usados.toList()..sort()).last;
      _colunasExtras.add(ultimo.avancar(1));
    });

    _salvarProgresso();
  }

  void _removerColuna(SemestreAcademico semestre) {
    final vazia = !widget.disciplinas.any((d) => _semestre[d.codigo] == semestre);
    if (!vazia) return;
    setState(() => _colunasExtras.remove(semestre));

    _salvarProgresso();
  }

  void _marcarConcluida(String codigo) {
    setState(() {
        _concluidas.add(codigo);
        _semestre.remove(codigo);
    });

    _salvarProgresso();
  }

  @override
  Widget build(BuildContext context) {
    final semPeriodo = widget.disciplinas.where((d) => !_semestre.containsKey(d.codigo)).toList();

    final usados = _todosOsSemestresUsados();
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
    for (var d in widget.disciplinas) {
      final s = _semestre[d.codigo];
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
    for (var d in widget.disciplinas) {
      if (!_semestre.containsKey(d.codigo)) continue;
      for (var codigo in _codigosRelevantes(d)) {
        if (_semestre.containsKey(codigo)) arestas.add((codigo, d.codigo));
      }
    }

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _colunaConcluidas(),
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
                                final pode = _podeSoltarEm(details.data, colunas[col]);
                                _dropInvalido.value = !pode;
                                return pode;
                              },
                              onLeave: (_) => _dropInvalido.value = false,
                              onAcceptWithDetails: (details) {
                                _dropInvalido.value = false;
                                _moverDisciplina(details.data, colunas[col]);
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
                                        onPressed: () => _removerColuna(colunas[col]),
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
                              child: _CardArrastavel(
                                disciplina: d,
                                cor: _paleta[col % _paleta.length],
                                dropInvalido: _dropInvalido,
                                destacado: _destacados.contains(d.codigo),
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
                              onPressed: _adicionarProximoPeriodo,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Período'),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            size: Size(larguraGrade, maiorAltura),
                            painter: _SetasPainter(
                              arestas: arestas,
                              posicoes: posicoes,
                              larguraCard: _larguraColuna,
                              alturaCard: _alturaCard,
                              destacados: _destacados,
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

  Widget _colunaConcluidas() {
    final itens = widget.disciplinas.where((d) => _concluidas.contains(d.codigo)).toList()
        ..sort((a, b) => a.codigo.compareTo(b.codigo));

    return SizedBox(
        width: _larguraColuna,
        child: DragTarget<String>(
            onAcceptWithDetails: (details) => _marcarConcluida(details.data),
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
                                    child: _CardArrastavel(disciplina: d, cor: Colors.green, dropInvalido: _dropInvalido),
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

class _CardArrastavel extends StatelessWidget {
  final Disciplina disciplina;
  final MaterialColor cor;
  final ValueNotifier<bool> dropInvalido;
  final bool destacado;

  const _CardArrastavel({
    required this.disciplina,
    required this.cor,
    required this.dropInvalido,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: disciplina.codigo,
      onDragEnd: (_) => dropInvalido.value = false,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 196,
          child: ValueListenableBuilder<bool>(
            valueListenable: dropInvalido,
            builder: (context, invalido, _) => _card(elevado: true, invalido: invalido),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _card()),
      child: _card(),
    );
  }

  Widget _card({bool elevado = false, bool invalido = false}) {
    final corBorda = invalido ? Colors.red : (destacado ? Colors.deepOrange : cor);
    final corTexto = invalido
        ? Colors.red.shade900
        : (destacado ? Colors.deepOrange.shade900 : cor.shade900);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: corBorda, width: destacado ? 4 : 2),
        boxShadow: destacado
            ? [BoxShadow(color: Colors.deepOrange.withOpacity(0.5), blurRadius: 8)]
            : elevado
                ? [const BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(2, 4))]
                : const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(disciplina.codigo,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTexto)),
          Text(disciplina.nome,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _SetasPainter extends CustomPainter {
  final List<(String, String)> arestas;
  final Map<String, Offset> posicoes;
  final double larguraCard;
  final double alturaCard;
  final Set<String> destacados;

  _SetasPainter({
    required this.arestas,
    required this.posicoes,
    required this.larguraCard,
    required this.alturaCard,
    required this.destacados,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linhaNormal = Paint()
      ..color = Colors.blueGrey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final linhaDestaque = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final (origemCodigo, destinoCodigo) in arestas) {
      final origem = posicoes[origemCodigo];
      final destino = posicoes[destinoCodigo];
      if (origem == null || destino == null) continue;

      final destacada = destacados.contains(origemCodigo) && destacados.contains(destinoCodigo);
      final linha = destacada ? linhaDestaque : linhaNormal;

      final saida = origem + Offset(larguraCard, alturaCard / 2);
      final chegada = destino + Offset(0, alturaCard / 2);
      final meio1 = Offset((saida.dx + chegada.dx) / 2, saida.dy);
      final meio2 = Offset((saida.dx + chegada.dx) / 2, chegada.dy);

      final path = Path()
        ..moveTo(saida.dx, saida.dy)
        ..cubicTo(meio1.dx, meio1.dy, meio2.dx, meio2.dy, chegada.dx, chegada.dy);
      canvas.drawPath(path, linha);
      _desenharSeta(canvas, chegada, linha.color);
    }
  }

  void _desenharSeta(Canvas canvas, Offset ponta, Color cor) {
    const tamanho = 6.0;
    final path = Path()
      ..moveTo(ponta.dx, ponta.dy)
      ..lineTo(ponta.dx - tamanho, ponta.dy - tamanho / 2)
      ..lineTo(ponta.dx - tamanho, ponta.dy + tamanho / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant _SetasPainter oldDelegate) => true;
}