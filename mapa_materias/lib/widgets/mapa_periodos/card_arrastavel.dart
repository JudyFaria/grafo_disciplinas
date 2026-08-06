import 'package:flutter/material.dart';
import '../../models/disciplina_model.dart';

class CardArrastavel extends StatelessWidget {
  final Disciplina disciplina;
  final MaterialColor cor;
  final ValueNotifier<bool> dropInvalido;
  final bool destacado;
  final bool emFoco;
  final bool conectado;
  final bool ehOptativa;
  final bool optativaResolvida;
  final VoidCallback? onTapOptativa;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHover;

  const CardArrastavel({
    super.key,
    required this.disciplina,
    required this.cor,
    required this.dropInvalido,
    this.destacado = false,
    this.emFoco = false,
    this.conectado = false,
    this.ehOptativa = false,
    this.optativaResolvida = false,
    this.onTapOptativa,
    this.onTap,
    this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: onHover == null ? null : (_) => onHover!(true),
      onExit: onHover == null ? null : (_) => onHover!(false),
      child: Draggable<String>(
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
        child: GestureDetector(onTap: onTap, child: _card()),
      ),
    );
  }

  Widget _card({bool elevado = false, bool invalido = false}) {
    final Color corBorda = invalido
        ? Colors.red
        : destacado
            ? Colors.deepOrange
            : emFoco
                ? Colors.amber.shade800
                : (ehOptativa && !optativaResolvida)
                    ? Colors.purple
                    : cor;
    final Color corTexto = invalido
        ? Colors.red.shade900
        : destacado
            ? Colors.deepOrange.shade900
            : emFoco
                ? Colors.amber.shade900
                : (ehOptativa && !optativaResolvida)
                    ? Colors.purple.shade900
                    : cor.shade900;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: conectado ? Colors.amber.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: corBorda, width: (destacado || emFoco) ? 4 : 2),
        boxShadow: destacado
            ? [BoxShadow(color: Colors.deepOrange.withOpacity(0.5), blurRadius: 8)]
            : emFoco
                ? [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 8)]
                : elevado
                    ? [const BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(2, 4))]
                    : const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(disciplina.codigo,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTexto)),
              if (ehOptativa) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onTapOptativa,
                  child: Icon(
                    optativaResolvida ? Icons.swap_horiz : Icons.list_alt,
                    size: 14,
                    color: corTexto,
                  ),
                ),
              ],
            ],
          ),
          Text(disciplina.nome,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}