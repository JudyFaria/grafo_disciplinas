import 'package:cloud_firestore/cloud_firestore.dart';

class Momento {
  final String id;
  final String nome;
  final DateTime? criadoEm;
  final Map<String, dynamic> dados;

  Momento({required this.id, required this.nome, this.criadoEm, required this.dados});
}

class MomentoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _colecao(String uid) =>
      _db.collection('progressos').doc(uid).collection('momentos');

  Future<void> salvar(String uid, String nome, Map<String, dynamic> dados) {
    return _colecao(uid).add({
      'nome': nome,
      'criadoEm': FieldValue.serverTimestamp(),
      ...dados,
    });
  }

  Future<List<Momento>> listar(String uid) async {
    final snapshot = await _colecao(uid).orderBy('criadoEm', descending: true).get();
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return Momento(
        id: doc.id,
        nome: d['nome'] as String? ?? 'Sem nome',
        criadoEm: (d['criadoEm'] as Timestamp?)?.toDate(),
        dados: d,
      );
    }).toList();
  }

  Future<void> excluir(String uid, String id) {
    return _colecao(uid).doc(id).delete();
  }
}