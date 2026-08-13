class SemestreAcademico implements Comparable<SemestreAcademico> {
  final int ano;
  final int semestre; // 1 ou 2

  const SemestreAcademico(this.ano, this.semestre);

  factory SemestreAcademico.deData(DateTime data) =>
      SemestreAcademico(data.year, data.month <= 6 ? 1 : 2);

  SemestreAcademico avancar(int quantidade) {
    var ano2 = ano, sem2 = semestre;
    for (var i = 0; i < quantidade; i++) {
      if (sem2 == 1) {
        sem2 = 2;
      } else {
        sem2 = 1;
        ano2++;
      }
    }
    return SemestreAcademico(ano2, sem2);
  }

  @override
  int compareTo(SemestreAcademico other) =>
      (ano * 2 + semestre).compareTo(other.ano * 2 + other.semestre);

  @override
  bool operator ==(Object other) =>
      other is SemestreAcademico && ano == other.ano && semestre == other.semestre;

  @override
  int get hashCode => Object.hash(ano, semestre);

  @override
  String toString() => '${(ano % 100).toString().padLeft(2, '0')}.$semestre';
}