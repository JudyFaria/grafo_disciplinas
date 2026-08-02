// Mostra as disciplinas organizadas em colunas por período (como no site),
// com setas ligando pré-requisito -> matéria dependente. Só entre períodos
// imediatamente adjacentes, pra manter a visualização limpa (dependências
// que "pulam" período não são desenhadas nesta versão).

import 'package:flutter/material.dart';
import '../models/disciplina_model.dart';
import '../models/semestre_academico.dart';

class MapaPeriodosWidget extends StatefulWidget {
  final List<Disciplina> disciplinas;

  const MapaPeriodosWidget({super.key, required this.disciplinas});

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
  late Map<String, List<String>> _dependentesDiretos; // codigo -> quem depende dele
  final Map<String, SemestreAcademico> _semestre = {}; // ausente = "sem período fixo"

  @override
  void initState() {
    super.initState();
    _porCodigo = {for (var d in widget.disciplinas) d.codigo: d};
    _construirDependencias();

    final base = SemestreAcademico.deData(DateTime.now());
    for (var d in widget.disciplinas) {
      if (d.periodo != null) {
        _semestre[d.codigo] = base.avancar(d.periodo! - 1);
      }
    }
  }

  void _construirDependencias() {
        _dependentesDiretos = {};
        for (var d in widget.disciplinas) {
            for (var codigo in _codigosRelevantes(d)) {
            _dependentesDiretos.putIfAbsent(codigo, () => []).add(d.codigo);
            }
        }
    }

  void _moverDisciplina(String codigo, SemestreAcademico destino) {
    setState(() {
      _semestre[codigo] = destino;
      _corrigirDependentes(codigo);
    });
  }

  // Propaga pra frente: ninguém pode ficar no mesmo semestre ou antes do
  // próprio pré-requisito. Empurra quem precisar, e propaga a partir deles.
  void _corrigirDependentes(String codigoMovido) {
    final fila = [codigoMovido];
    while (fila.isNotEmpty) {
      final atual = fila.removeAt(0);
      final semestreAtual = _semestre[atual];
      if (semestreAtual == null) continue;

      for (var dep in _dependentesDiretos[atual] ?? const <String>[]) {
        final minimo = semestreAtual.avancar(1);
        final semestreDep = _semestre[dep];
        if (semestreDep == null || semestreDep.compareTo(minimo) < 0) {
          _semestre[dep] = minimo;
          fila.add(dep);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semPeriodo = widget.disciplinas.where((d) => !_semestre.containsKey(d.codigo)).toList();

    final usados = _semestre.values.toSet();
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
            _colunaSemPeriodo(semPeriodo),
            const SizedBox(width: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: larguraGrade,
                    height: maiorAltura,
                    child: Stack(
                      children: [
                        for (var col = 0; col < colunas.length; col++) ...[
                          // fundo/alvo de arraste da coluna inteira (embaixo dos cards)
                          Positioned(
                            left: col * (_larguraColuna + _espacoColuna),
                            top: 0,
                            width: _larguraColuna,
                            height: maiorAltura,
                            child: DragTarget<String>(
                              onAcceptWithDetails: (details) =>
                                  _moverDisciplina(details.data, colunas[col]),
                              builder: (context, candidate, rejected) => Container(
                                color: candidate.isNotEmpty
                                    ? _paleta[col % _paleta.length].withOpacity(0.08)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          // cabeçalho (só visual — o fundo já cobre essa área)
                          Positioned(
                            left: col * (_larguraColuna + _espacoColuna),
                            top: 0,
                            width: _larguraColuna,
                            child: IgnorePointer(
                              child: Container(
                                height: _alturaCabecalho,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _paleta[col % _paleta.length].shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  colunas[col].toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _paleta[col % _paleta.length].shade900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // cards por cima de tudo
                          for (var d in porColuna[colunas[col]]!)
                            Positioned(
                              left: posicoes[d.codigo]!.dx,
                              top: posicoes[d.codigo]!.dy,
                              width: _larguraColuna,
                              height: _alturaCard,
                              child: _CardArrastavel(
                                disciplina: d,
                                cor: _paleta[col % _paleta.length],
                              ),
                            ),
                        ],
                        IgnorePointer(
                          child: CustomPaint(
                            size: Size(larguraGrade, maiorAltura),
                            painter: _SetasPainter(
                              arestas: arestas,
                              posicoes: posicoes,
                              larguraCard: _larguraColuna,
                              alturaCard: _alturaCard,
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

  Widget _colunaSemPeriodo(List<Disciplina> itens) {
    return SizedBox(
      width: _larguraColuna,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: _alturaCabecalho,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6)),
            child: const Text('Sem período fixo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (var d in itens)
                  Padding(
                    padding: const EdgeInsets.only(bottom: _espacoCard),
                    child: _CardArrastavel(disciplina: d, cor: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardArrastavel extends StatelessWidget {
  final Disciplina disciplina;
  final MaterialColor cor;

  const _CardArrastavel({required this.disciplina, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: disciplina.codigo,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 196, child: _card(elevado: true)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _card()),
      child: _card(),
    );
  }

  Widget _card({bool elevado = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor, width: 2),
        boxShadow: elevado
            ? [const BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(2, 4))]
            : const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(disciplina.codigo,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cor.shade900)),
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

  _SetasPainter({
    required this.arestas,
    required this.posicoes,
    required this.larguraCard,
    required this.alturaCard,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linha = Paint()
      ..color = Colors.blueGrey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final (origemCodigo, destinoCodigo) in arestas) {
      final origem = posicoes[origemCodigo];
      final destino = posicoes[destinoCodigo];
      if (origem == null || destino == null) continue;

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