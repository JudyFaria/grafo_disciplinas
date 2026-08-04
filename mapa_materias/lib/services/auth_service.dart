import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get mudancasDeEstado => _auth.authStateChanges();
  User? get usuarioAtual => _auth.currentUser;

  Future<UserCredential> entrar(String email, String senha) {
    return _auth.signInWithEmailAndPassword(email: email, password: senha);
  }

  Future<UserCredential> cadastrar(String email, String senha) {
    return _auth.createUserWithEmailAndPassword(email: email, password: senha);
  }

  Future<void> sair() => _auth.signOut();

  Future<void> redefinirSenha(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}