import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/notificacao_model.dart';

/// Notificações "in-app": cada usuário tem sua subcoleção em
/// notificacoes/{uid}/items. Quando alguém comenta ou curte a denúncia
/// de outra pessoa, criamos um documento para o DONO da denúncia.
class NotificacaoService {
  static final NotificacaoService instance = NotificacaoService();

  CollectionReference<Map<String, dynamic>> _ref(String uid) =>
      FirebaseFirestore.instance
          .collection('notificacoes')
          .doc(uid)
          .collection('items');

  Future<void> notificar({
    required String donoId,
    required String tipo,
    required String deUsuarioNome,
    required String ocorrenciaId,
    required String ocorrenciaTitulo,
  }) async {
    try {
      await _ref(donoId).add(
        NotificacaoModel(
          id: '',
          tipo: tipo,
          deUsuarioNome: deUsuarioNome,
          ocorrenciaId: ocorrenciaId,
          ocorrenciaTitulo: ocorrenciaTitulo,
        ).toMap(),
      );
    } catch (e) {
      debugPrint('Erro ao criar notificação: $e');
    }
  }

  Future<void> notificarConquista({
    required String userId,
    required String conquistaTitulo,
  }) async {
    try {
      await _ref(userId).add(
        NotificacaoModel(
          id: '',
          tipo: 'conquista',
          deUsuarioNome: 'EcoJP',
          ocorrenciaId: '',
          ocorrenciaTitulo: '',
          conquistaTitulo: conquistaTitulo,
        ).toMap(),
      );
    } catch (e) {
      debugPrint('Erro ao criar notificação de conquista: $e');
    }
  }

  Stream<List<NotificacaoModel>> listar(String uid) {
    return _ref(uid)
        .orderBy('dataCriacao', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => NotificacaoModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Stream<int> contarNaoLidas(String uid) {
    return _ref(uid)
        .where('lida', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> marcarTodasComoLidas(String uid) async {
    try {
      final snap = await _ref(uid).where('lida', isEqualTo: false).get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'lida': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Erro ao marcar notificações como lidas: $e');
    }
  }
}
