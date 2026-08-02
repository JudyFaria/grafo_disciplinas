// Calcula o status de cada disciplina (concluída / disponível / bloqueada)
// a partir da lista completa do curso e do conjunto de códigos já concluídos.

import '../models/disciplina_model.dart';

enum StatusDisciplina { concluida, disponivel, bloqueada }

Map<String, StatusDisciplina> calcularStatusDisciplinas(
  List<Disciplina> disciplinas,
  Set<String> concluidas,
) {
  final status = <String, StatusDisciplina>{};

  for (var d in disciplinas) {
    if (concluidas.contains(d.codigo)) {
      status[d.codigo] = StatusDisciplina.concluida;
      continue;
    }
    status[d.codigo] = _prerequisitosAtendidos(d.preRequisitos, concluidas)
        ? StatusDisciplina.disponivel
        : StatusDisciplina.bloqueada;
  }

  return status;
}

bool _prerequisitosAtendidos(
  List<List<String>> grupos,
  Set<String> concluidas,
) {
  if (grupos.isEmpty) return true;
  // lista externa = OU: um grupo inteiro satisfeito já basta
  return grupos.any(
    (grupo) => grupo.every((codigo) => concluidas.contains(codigo.trim())),
  );
}

/// A partir da planilha de pendências (matérias que faltam), descobre
/// quais disciplinas já foram concluídas: tudo que existe no curso e
/// NÃO aparece como faltante.
Set<String> calcularConcluidas(
  List<Disciplina> todasDoCurso,
  Set<String> faltantes,
) {
  return todasDoCurso.map((d) => d.codigo).toSet().difference(faltantes);
}