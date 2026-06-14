import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/usuario_model.dart';

class UsuarioService {
  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('usuarios');

  // Observa o perfil em tempo real
  Stream<UsuarioModel?> observarPerfil(String uid) {
    return _ref.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return UsuarioModel.fromMap(data, uid);
    });
  }

  // Carrega o perfil uma vez
  Future<UsuarioModel?> carregarPerfil(String uid) async {
    final doc = await _ref.doc(uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return UsuarioModel.fromMap(data, uid);
  }

  // Cria ou atualiza o perfil
  Future<void> salvarPerfil(UsuarioModel usuario) async {
    try {
      await _ref.doc(usuario.uid).set(usuario.toMap());
    } catch (e) {
      debugPrint('Erro ao salvar perfil: $e');
      rethrow;
    }
  }

  // Verifica se já existe outro usuário com o mesmo nome (ignora maiúsculas/
  // minúsculas e espaços nas pontas). [ignorarUid] permite que o próprio
  // usuário mantenha o nome ao editar o perfil.
  Future<bool> nomeEmUso(String nome, {String? ignorarUid}) async {
    final alvo = nome.trim().toLowerCase();
    if (alvo.isEmpty) return false;
    final snapshot = await _ref.get();
    for (final doc in snapshot.docs) {
      if (doc.id == ignorarUid) continue;
      final outro = (doc.data()['nome'] as String?)?.trim().toLowerCase();
      if (outro == alvo) return true;
    }
    return false;
  }
}
