import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bloco_horario.dart';

class HorarioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _documento(String uid, String semestreChave) =>
      _db.collection('progressos').doc(uid).collection('horarios').doc(semestreChave);

  Future<List<BlocoHorario>> carregar(String uid, String semestreChave) async {
    final doc = await _documento(uid, semestreChave).get();
    final blocos = doc.data()?['blocos'] as List<dynamic>? ?? [];
    return blocos.map((b) => BlocoHorario.deMapa(b as Map<String, dynamic>)).toList();
  }

  Future<void> salvar(String uid, String semestreChave, List<BlocoHorario> blocos) {
    return _documento(uid, semestreChave).set({
      'blocos': blocos.map((b) => b.paraMapa()).toList(),
    });
  }
}