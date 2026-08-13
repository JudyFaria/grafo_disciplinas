import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _documento(String uid) =>
      _db.collection('progressos').doc(uid);

  Future<void> salvar({
    required String uid,
    required Map<String, dynamic> dados,
    String? matricula,
  }) {
    return _documento(uid).set({
      'matricula': matricula,
      ...dados,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> carregar(String uid) async {
    final doc = await _documento(uid).get();
    return doc.data();
  }
}