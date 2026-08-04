import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/semestre_academico.dart';

class ProgressoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _documento(String uid) =>
      _db.collection('progressos').doc(uid);

  Future<void> salvar({
    required String uid,
    required Map<String, SemestreAcademico> semestre,
    required Set<String> concluidas,
    required Set<SemestreAcademico> colunasExtras,
    String? matricula,
  }) {
    return _documento(uid).set({
      'matricula': matricula,
      'semestre': semestre.map(
        (codigo, s) => MapEntry(codigo, {'ano': s.ano, 'semestre': s.semestre}),
      ),
      'concluidas': concluidas.toList(),
      'colunasExtras':
          colunasExtras.map((s) => {'ano': s.ano, 'semestre': s.semestre}).toList(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> carregar(String uid) async {
    final doc = await _documento(uid).get();
    return doc.data();
  }
}