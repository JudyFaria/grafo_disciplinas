import 'package:flutter/material.dart';

class TelaAjuda extends StatelessWidget {
  const TelaAjuda({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Como usar o GrafoFlow')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SecaoAjuda(
            titulo: '1. Baixe seu "Falta Cursar"',
            texto: 'No sistema acadêmico da PUC, procure o relatório de disciplinas '
                'curriculares não cumpridas ("Falta Cursar") e baixe o arquivo em Excel (.xlsx).',
          ),
          _SecaoAjuda(
            titulo: '2. Importe o arquivo',
            texto: 'Abra o menu (ícone no canto superior esquerdo) e toque em '
                '"Importar pendências". O app monta seu grafo pessoal automaticamente.',
          ),
          _SecaoAjuda(
            titulo: '3. Mova as matérias',
            texto: 'Segure uma matéria por um instante e arraste pra outra coluna '
                '(período). Se ela depender de algo que ainda não está no período '
                'certo, o app avisa em vermelho e não deixa soltar ali.',
          ),
          _SecaoAjuda(
            titulo: '4. Marque como concluída',
            texto: 'Arraste a matéria pra dentro da seção "Concluídas". Pra desfazer, '
                'arraste de volta pra uma coluna de período.',
          ),
          _SecaoAjuda(
            titulo: '5. Optativas e eletivas',
            texto: 'Cards com ícone de lista são "vagas" ainda sem matéria escolhida. '
                'Toque no ícone pra ver as opções e escolher. Depois de escolhida, o '
                'ícone vira uma seta de troca — toque de novo pra trocar.',
          ),
          _SecaoAjuda(
            titulo: '6. Sem período fixo',
            texto: 'Matérias sem período definido no seu Falta Cursar ficam aqui. '
                'Arraste pra uma coluna quando quiser planejar quando vai cursá-la.',
          ),
          _SecaoAjuda(
            titulo: '7. Resetar',
            texto: 'No menu, "Resetar para grade oficial" desfaz tudo que você mexeu '
                'manualmente, voltando pra grade sugerida pela universidade.',
          ),
        ],
      ),
    );
  }
}

class _SecaoAjuda extends StatelessWidget {
  final String titulo;
  final String texto;

  const _SecaoAjuda({required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(texto),
          ],
        ),
      ),
    );
  }
}