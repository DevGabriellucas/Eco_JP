import 'package:cloud_firestore/cloud_firestore.dart';

/// Lê o papel (role) do usuário a partir da coleção `roles/{uid}`.
///
/// O papel de autoridade é concedido manualmente pelo Console do Firebase,
/// criando um documento `roles/{uid}` com `{ role: 'autoridade' }`. O app
/// nunca escreve nessa coleção — apenas lê o próprio papel.
class RoleService {
  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('roles');

  static const String papelAutoridade = 'autoridade';

  /// Lê uma vez se o usuário é autoridade.
  Future<bool> isAutoridade(String uid) async {
    final doc = await _ref.doc(uid).get();
    return doc.exists && doc.data()?['role'] == papelAutoridade;
  }

  /// Observa em tempo real se o usuário é autoridade. Útil para a UI reagir
  /// caso o papel seja concedido ou revogado durante a sessão.
  Stream<bool> observarAutoridade(String uid) {
    return _ref
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists && doc.data()?['role'] == papelAutoridade);
  }
}
