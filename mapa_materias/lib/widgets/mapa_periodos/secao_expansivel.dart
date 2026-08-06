import 'package:flutter/material.dart';

// Seção recolhível (Concluídas, Sem período fixo). O cabeçalho continua
// sendo um alvo de arraste válido mesmo com a seção fechada — só a lista
// de cards some quando recolhida.
class SecaoExpansivel extends StatefulWidget {
  final String titulo;
  final int quantidade;
  final MaterialColor cor;
  final bool inicialmenteAberta;
  final List<Widget> itens;
  final bool Function(String codigo)? podeAceitar;
  final void Function(String codigo) aoAceitar;

  const SecaoExpansivel({
    super.key,
    required this.titulo,
    required this.quantidade,
    required this.cor,
    required this.itens,
    required this.aoAceitar,
    this.inicialmenteAberta = false,
    this.podeAceitar,
  });

  @override
  State<SecaoExpansivel> createState() => _SecaoExpansivelState();
}

class _SecaoExpansivelState extends State<SecaoExpansivel> {
  late bool _aberta = widget.inicialmenteAberta;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: widget.cor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DragTarget<String>(
            onWillAcceptWithDetails: widget.podeAceitar == null
                ? null
                : (details) => widget.podeAceitar!(details.data),
            onAcceptWithDetails: (details) => widget.aoAceitar(details.data),
            builder: (context, candidate, rejected) => InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _aberta = !_aberta),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: candidate.isNotEmpty
                      ? widget.cor.withOpacity(0.3)
                      : rejected.isNotEmpty
                          ? Colors.red.withOpacity(0.15)
                          : widget.cor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(_aberta ? Icons.expand_less : Icons.expand_more, color: widget.cor.shade900),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.titulo} (${widget.quantidade})',
                      style: TextStyle(fontWeight: FontWeight.bold, color: widget.cor.shade900),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_aberta)
            Padding(
              padding: const EdgeInsets.all(10),
              child: widget.itens.isEmpty
                  ? const Text('Nenhuma matéria aqui', style: TextStyle(color: Colors.grey))
                  : Wrap(spacing: 8, runSpacing: 8, children: widget.itens),
            ),
        ],
      ),
    );
  }
}