class Disciplina {
    final String codigo;
    final String nome;
    
    // Lista das mmaterias: lista externa -> OU, lista INter a -> E
    final List<List<String>> preRequisitos;
    final List<String> coRequisitos;

    Disciplina({
        required this.codigo,
        required this.nome,
        required this.preRequisitos,
        required this.coRequisitos,
    });

    // Construtor para converter o JSON em um objeto Dart
    factory Disciplina.fromJson(Map<String, dynamic> json) {
        return Disciplina(
            codigo: json['codigo'] as String,
            nome: json['nome'] as String,
            
            // Mapeando a lista de listas
            preRequisitos: (json['preRequisitos'] as List<dynamic>?)
                    ?.map((listaInterna) => (listaInterna as List<dynamic>)
                        .map((item) => item as String)
                        .toList())
                    .toList() ??
                [],
                
            // Mapeando a lista simples
            coRequisitos: (json['coRequisitos'] as List<dynamic>?)
                    ?.map((item) => item as String)
                    .toList() ??
                [],
        );
    }
}