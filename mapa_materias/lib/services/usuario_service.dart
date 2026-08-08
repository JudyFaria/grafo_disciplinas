import 'package:cloud_firestore/cloud_firestore.dart';

class PerfilUsuario {
  final String curso;
  final String? nickname;
  PerfilUsuario({required this.curso, this.nickname});
}

class UsuarioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _documento(String uid) =>
      _db.collection('usuarios').doc(uid);

  Future<void> salvarPerfil(String uid, {required String curso, String? nickname}) {
    return _documento(uid).set({
      'curso': curso,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
    }, SetOptions(merge: true));
  }

  Future<PerfilUsuario?> carregarPerfil(String uid) async {
    final doc = await _documento(uid).get();
    final dados = doc.data();
    if (dados == null || dados['curso'] == null) return null;
    return PerfilUsuario(curso: dados['curso'] as String, nickname: dados['nickname'] as String?);
  }
}