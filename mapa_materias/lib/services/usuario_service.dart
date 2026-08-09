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

  String _chaveNickname(String nickname) => nickname.trim().toLowerCase();

  Future<bool> nicknameDisponivel(String nickname) async {
    final doc = await _db.collection('nicknames').doc(_chaveNickname(nickname)).get();
    return !doc.exists;
  }

  // Só isso é público (ver regras do Firestore) — existe unicamente pra
  // resolver nickname -> e-mail antes do login, quando o usuário ainda
  // não está autenticado e não pode ler a coleção "usuarios".
  Future<String?> resolverEmailPorNickname(String nickname) async {
    final doc = await _db.collection('nicknames').doc(_chaveNickname(nickname)).get();
    return doc.data()?['email'] as String?;
  }

  Future<void> salvarPerfil(String uid, {required String curso, String? nickname, String? email}) async {
    await _documento(uid).set({
      'curso': curso,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
    }, SetOptions(merge: true));

    if (nickname != null && nickname.isNotEmpty && email != null) {
      await _db.collection('nicknames').doc(_chaveNickname(nickname)).set({
        'uid': uid,
        'email': email,
      });
    }
  }

  Future<PerfilUsuario?> carregarPerfil(String uid) async {
    final doc = await _documento(uid).get();
    final dados = doc.data();
    if (dados == null || dados['curso'] == null) return null;
    return PerfilUsuario(curso: dados['curso'] as String, nickname: dados['nickname'] as String?);
  }
}