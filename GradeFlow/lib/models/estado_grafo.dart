import 'package:flutter/foundation.dart';
import 'disciplina_model.dart';
import 'semestre_academico.dart';

class EstadoGrafo extends ChangeNotifier {
  final List<Disciplina> disciplinas;
  final Map<String, int>? periodosPersonalizados;
  final Set<String> concluidasIniciais;
  final Set<String> faltantesSemPeriodo; // códigos com período >10 na planilha (ex: 20)

  late final Map<String, Disciplina> porCodigoOriginal;
  late Map<String, Disciplina> porCodigo;
  late Set<String> codigosDeOpcaoApenas;
  late Map<String, List<String>> dependentesDiretos;
  late Map<String, Set<String>> coRequisitosDiretos;

//   late Set<String> codigosComAlternativasDePrereq;
  final Map<String, int> grupoPrereqEscolhido = {};

  final Map<String, SemestreAcademico> semestre = {};
  final Set<SemestreAcademico> colunasExtras = {};
  final Map<String, String> escolhaOptativa = {};
  late Set<String> concluidas;

  EstadoGrafo({
    required this.disciplinas,
    this.periodosPersonalizados,
    this.concluidasIniciais = const {},
    this.faltantesSemPeriodo = const {},
    Map<String, dynamic>? estadoSalvo,

    this.concluidas = const {},
  }) {
    // Códigos de currículos antigos: sem período no currículo atual, e não
    // são opção de nenhuma optativa/extensão — só existiam como alternativa
    // (OU) de pré-requisito em versões antigas da grade. Dispensados de vez.
    final opcoesDeAlgumGrupo = disciplinas.expand((d) => d.grupoDisciplinas).toSet();
    final foraDoCurriculoAtual = disciplinas
        .where((d) =>
            d.periodo == null &&
            !opcoesDeAlgumGrupo.contains(d.codigo) &&
            !faltantesSemPeriodo.contains(d.codigo))
        .map((d) => d.codigo)
        .toSet();

    final disciplinasValidas = disciplinas.where((d) => !foraDoCurriculoAtual.contains(d.codigo));
    porCodigoOriginal = {for (var d in disciplinasValidas) d.codigo: d};
    porCodigo = Map.of(porCodigoOriginal);
    codigosDeOpcaoApenas = _calcularCodigosDeOpcaoApenas();
    _construirDependencias();

    if (estadoSalvo != null) {
        _restaurarDeEstadoSalvo(estadoSalvo);
    } else {
        _inicializarPadrao();
    }
  }

  // Tem alternativa quando existe algum código que varia entre os grupos
  // (ou seja, a interseção não cobre tudo que aparece no total).
  bool _temAlternativasDePrerequisito(Disciplina d) {
    if (d.preRequisitos.length <= 1) return false;
    final grupos = d.preRequisitos.map((g) => g.map((c) => c.trim()).toSet()).toList();
    final comuns = grupos.reduce((a, b) => a.intersection(b));
    final uniao = grupos.expand((g) => g).toSet();
    return uniao.length > comuns.length;
  }

  Set<String> _calcularCodigosDeOpcaoApenas() {
    final todos = disciplinas.expand((d) => d.grupoDisciplinas).toSet();
    return todos.where((codigo) {
      final d = porCodigoOriginal[codigo];
      if (d == null) return true;
      final temPeriodo = (periodosPersonalizados?[codigo] ?? d.periodo) != null;
      return !temPeriodo;
    }).toSet();
  }

  void _inicializarPadrao() {
    concluidas = {...concluidasIniciais}..removeAll(codigosDeOpcaoApenas);
    final base = SemestreAcademico.deData(DateTime.now());
    for (var d in porCodigo.values) {
        if (concluidas.contains(d.codigo)) continue;
        if (codigosDeOpcaoApenas.contains(d.codigo)) continue;
        if (faltantesSemPeriodo.contains(d.codigo)) continue;
        final periodo = periodosPersonalizados?[d.codigo] ?? d.periodo;
        if (periodo != null) {
        semestre[d.codigo] = base.avancar(periodo - 1);
        }
    }
  }

  void _restaurarDeEstadoSalvo(Map<String, dynamic> dados) {
    concluidas = Set<String>.from(dados['concluidas'] as List? ?? []);

    final semestreSalvo = dados['semestre'] as Map<String, dynamic>? ?? {};
    for (var entry in semestreSalvo.entries) {
      final s = entry.value as Map<String, dynamic>;
      semestre[entry.key] = SemestreAcademico(s['ano'] as int, s['semestre'] as int);
    }

    for (var s in (dados['colunasExtras'] as List? ?? [])) {
      colunasExtras.add(SemestreAcademico(s['ano'] as int, s['semestre'] as int));
    }

    final escolhasSalvas = dados['escolhas'] as Map<String, dynamic>? ?? {};
    for (var entry in escolhasSalvas.entries) {
      _aplicarEscolha(entry.key, entry.value as String);
    }
    
    final grupoPrereqSalvo = dados['grupoPrereq'] as Map<String, dynamic>? ?? {};
    grupoPrereqEscolhido.addAll(grupoPrereqSalvo.map((k, v) => MapEntry(k, v as int)));

    if (escolhasSalvas.isNotEmpty || grupoPrereqSalvo.isNotEmpty) _construirDependencias();
  }

  void _construirDependencias() {
    dependentesDiretos = {};
    coRequisitosDiretos = {};
    for (var d in porCodigo.values) {
      for (var codigo in codigosRelevantes(d)) {
        dependentesDiretos.putIfAbsent(codigo, () => []).add(d.codigo);
      }
      for (var coReqBruto in d.coRequisitos) {
        final coReq = coReqBruto.trim();
        if (!porCodigo.containsKey(coReq)) continue;
        coRequisitosDiretos.putIfAbsent(d.codigo, () => {}).add(coReq);
        coRequisitosDiretos.putIfAbsent(coReq, () => {}).add(d.codigo);
      }
    }
  }

  List<Set<String>> _gruposValidos(Disciplina d) {
  return d.preRequisitos
      .map((g) => g.map((c) => c.trim()).toSet())
      .where((g) => g.isNotEmpty && g.every((c) => porCodigo.containsKey(c)))
      .toList();
}

// Grupos do pré-requisito original que existem por inteiro no currículo
// atual — usado pra saber se há ambiguidade real a resolver.
List<Set<String>> gruposPrereqValidos(String codigo) {
  final d = porCodigoOriginal[codigo];
  if (d == null) return [];
  return _gruposValidos(d);
}

bool temMultiplosGruposPrereq(String codigo) => gruposPrereqValidos(codigo).length > 1;

Set<String> escolherGrupoPrereq(String codigo, int indice) {
  grupoPrereqEscolhido[codigo] = indice;
  _construirDependencias();
  final mudados = _reencaixarSlot(codigo);
  notifyListeners();
  return mudados;
}

  Set<String> codigosRelevantes(Disciplina d) {
    if (d.preRequisitos.isEmpty) return {};

    final gruposValidos = _gruposValidos(d);

    if (gruposValidos.isEmpty) {
      final grupos = d.preRequisitos.map((g) => g.map((c) => c.trim()).toSet()).toList();
      final comuns = grupos.reduce((a, b) => a.intersection(b));
      if (comuns.isNotEmpty) return comuns.where((c) => porCodigo.containsKey(c)).toSet();
      return grupos.expand((g) => g).where((c) => porCodigo.containsKey(c)).toSet();
    }

    if (gruposValidos.length == 1) return gruposValidos.first;

    if (!grupoPrereqEscolhido.containsKey(d.codigo)) {
      // "satisfeito" = já está posicionado no grafo OU já foi concluído
      bool satisfeito(String c) => semestre.containsKey(c) || concluidas.contains(c);

      final gruposSatisfeitos = gruposValidos.where((g) => g.every(satisfeito)).toList();
      if (gruposSatisfeitos.length == 1) return gruposSatisfeitos.first;

      if (gruposSatisfeitos.isEmpty) {
        // Nenhum grupo 100% satisfeito ainda -- usa o que já tem mais
        // peças batendo como palpite, até ficar completo ou ser escolhido.
        var melhor = gruposValidos.first;
        var melhorContagem = -1;
        for (var g in gruposValidos) {
          final contagem = g.where(satisfeito).length;
          if (contagem > melhorContagem) {
            melhorContagem = contagem;
            melhor = g;
          }
        }
        return melhor;
      }
    }

    final indice = (grupoPrereqEscolhido[d.codigo] ?? 0).clamp(0, gruposValidos.length - 1);
    return gruposValidos[indice];
  }

  Set<String>? grupoPrereqAtivo(String codigo) {
    final d = porCodigoOriginal[codigo];
    if (d == null) return null;
    return codigosRelevantes(d);
  }

  bool podeSoltarEm(String codigo, SemestreAcademico destino) {
    final disciplina = porCodigo[codigo];
    if (disciplina == null) return true;
    for (var prereq in codigosRelevantes(disciplina)) {
      if (concluidas.contains(prereq)) continue;
      final semestrePrereq = semestre[prereq];
      if (semestrePrereq != null && destino.compareTo(semestrePrereq) <= 0) {
        return false;
      }
    }
    return true;
  }

  bool naoTemPeriodoDefinido(String codigo) {
    if (faltantesSemPeriodo.contains(codigo)) return true;
    final original = porCodigoOriginal[codigo];
    if (original == null) return true;
    final periodo = periodosPersonalizados?[codigo] ?? original.periodo;
    return periodo == null;
  }

  Set<String> moverDisciplina(String codigo, SemestreAcademico destino) {
    concluidas.remove(codigo);
    semestre[codigo] = destino;
    _construirDependencias();
    final mudados = {codigo, ..._propagarAPartirDe(codigo)};
    notifyListeners();
    return mudados;
  }

  Set<String> _propagarAPartirDe(String codigoMovido) {
    final mudados = <String>{};
    final fila = [codigoMovido];
    var protecaoContraCiclo = 0;
    while (fila.isNotEmpty && protecaoContraCiclo < 500) {
      protecaoContraCiclo++;
      final atual = fila.removeAt(0);
      final semestreAtual = semestre[atual];
      if (semestreAtual == null) continue;

      for (var dep in dependentesDiretos[atual] ?? const <String>[]) {
        if (concluidas.contains(dep)) continue;
        if (!semestre.containsKey(dep)) continue;
        final minimo = semestreAtual.avancar(1);
        if (semestre[dep]!.compareTo(minimo) < 0) {
          semestre[dep] = minimo;
          mudados.add(dep);
          fila.add(dep);
        }
      }

      for (var coReq in coRequisitosDiretos[atual] ?? const <String>{}) {
        if (concluidas.contains(coReq)) continue;
        if (!semestre.containsKey(coReq)) continue;
        if (semestre[coReq] != semestreAtual) {
          semestre[coReq] = semestreAtual;
          mudados.add(coReq);
          fila.add(coReq);
        }
      }
    }
    return mudados;
  }

  Set<SemestreAcademico> todosOsSemestresUsados() {
    final atual = SemestreAcademico.deData(DateTime.now());
    return {atual, ...semestre.values, ...colunasExtras};
  }

  void adicionarProximoPeriodo() {
    final usados = todosOsSemestresUsados();
    final ultimo = usados.isEmpty
        ? SemestreAcademico.deData(DateTime.now())
        : (usados.toList()..sort()).last;
    colunasExtras.add(ultimo.avancar(1));
    notifyListeners();
  }

  void removerColuna(SemestreAcademico s) {
    final vazia = !porCodigo.values.any((d) => semestre[d.codigo] == s);
    if (!vazia) return;
    colunasExtras.remove(s);
    notifyListeners();
  }

  void marcarConcluida(String codigo) {
    concluidas.add(codigo);
    semestre.remove(codigo);
    _construirDependencias();
    notifyListeners();
  }

  void removerDoGrafo(String codigo) {
    concluidas.remove(codigo);
    semestre.remove(codigo);
    _construirDependencias();
    notifyListeners();
  }

  void _aplicarEscolha(String codigoSlot, String codigoEscolhido) {
    final escolhida = porCodigo[codigoEscolhido];
    final original = porCodigoOriginal[codigoSlot];
    if (escolhida == null || original == null) return;

    escolhaOptativa[codigoSlot] = codigoEscolhido;
    porCodigo[codigoSlot] = Disciplina(
      codigo: original.codigo,
      nome: escolhida.nome,
      preRequisitos: escolhida.preRequisitos,
      coRequisitos: escolhida.coRequisitos,
      periodo: original.periodo,
      grupoDisciplinas: original.grupoDisciplinas,
    );
  }

  Set<String> escolherOptativa(String codigoSlot, String codigoEscolhido) {
    _aplicarEscolha(codigoSlot, codigoEscolhido);
    _construirDependencias();
    final mudados = _reencaixarSlot(codigoSlot);
    notifyListeners();
    return mudados;
  }

  void desfazerEscolha(String codigoSlot) {
    escolhaOptativa.remove(codigoSlot);
    porCodigo[codigoSlot] = porCodigoOriginal[codigoSlot]!;
    _construirDependencias();
    notifyListeners();
  }

  Set<String> _reencaixarSlot(String codigoSlot) {
    final semestreAtual = semestre[codigoSlot];
    if (semestreAtual == null) return {};

    var minimo = semestreAtual;
    for (var prereq in codigosRelevantes(porCodigo[codigoSlot]!)) {
      final semestrePrereq = semestre[prereq];
      if (semestrePrereq != null) {
        final exigido = semestrePrereq.avancar(1);
        if (exigido.compareTo(minimo) > 0) minimo = exigido;
      }
    }
    if (minimo.compareTo(semestreAtual) > 0) {
      semestre[codigoSlot] = minimo;
      return {codigoSlot, ..._propagarAPartirDe(codigoSlot)};
    }
    return {};
  }

  Map<String, dynamic> paraSalvar() {
    return {
      'semestre': semestre.map((c, s) => MapEntry(c, {'ano': s.ano, 'semestre': s.semestre})),
      'concluidas': concluidas.toList(),
      'colunasExtras': colunasExtras.map((s) => {'ano': s.ano, 'semestre': s.semestre}).toList(),
      'escolhas': escolhaOptativa,
      'grupoPrereq': grupoPrereqEscolhido,
    };
  }
}