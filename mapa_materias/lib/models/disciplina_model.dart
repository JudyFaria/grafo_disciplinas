class Disciplina {
  final String codigo;
  final String nome;
  final List<List<String>> preRequisitos;
  final List<String> coRequisitos;
  final int? periodo;
  final List<String> grupoDisciplinas; // códigos das opções, se for optativa/eletiva

  Disciplina({
    required this.codigo,
    required this.nome,
    required this.preRequisitos,
    required this.coRequisitos,
    this.periodo,
    this.grupoDisciplinas = const [],
  });

  factory Disciplina.fromJson(Map<String, dynamic> json) {
    return Disciplina(
      codigo: json['codigo'] as String,
      nome: json['nome'] as String,
      preRequisitos: (json['preRequisitos'] as List<dynamic>?)
              ?.map((g) => (g as List<dynamic>).map((i) => i as String).toList())
              .toList() ??
          [],
      coRequisitos: (json['coRequisitos'] as List<dynamic>?)
              ?.map((i) => i as String)
              .toList() ??
          [],
      periodo: json['periodo'] as int?,
      grupoDisciplinas: (json['grupoDisciplinas'] as List<dynamic>?)
              ?.map((item) => (item as Map<String, dynamic>)['codigo'] as String)
              .toList() ??
          [],
    );
  }
}