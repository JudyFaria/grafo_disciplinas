class BlocoHorario {
  final String codigoDisciplina;
  final int diaSemana; // 1 = segunda ... 6 = sábado
  final int horaInicio; // início do bloco fixo: 7, 9, 11, 13, 15, 17, 19
  final String sala;

  BlocoHorario({
    required this.codigoDisciplina,
    required this.diaSemana,
    required this.horaInicio,
    this.sala = '',
  });

  int get horaFim => horaInicio + 2;

  Map<String, dynamic> paraMapa() => {
        'codigoDisciplina': codigoDisciplina,
        'diaSemana': diaSemana,
        'horaInicio': horaInicio,
        'sala': sala,
      };

  factory BlocoHorario.deMapa(Map<String, dynamic> m) => BlocoHorario(
        codigoDisciplina: m['codigoDisciplina'] as String,
        diaSemana: m['diaSemana'] as int,
        horaInicio: m['horaInicio'] as int,
        sala: m['sala'] as String? ?? '',
      );
}