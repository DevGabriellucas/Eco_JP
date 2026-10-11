import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/notificacao_model.dart';
import '../utils/texto.dart';

/// Notificações "in-app": cada usuário tem sua subcoleção em
/// notificacoes/{uid}/items. Quando alguém comenta ou curte a denúncia
/// de outra pessoa, criamos um documento para o DONO da denúncia.
///
/// Curtida, comentário e conquista usam ID determinístico. A regra só aceita
/// create, então uma segunda gravação com o mesmo ID vira update e é negada:
/// curtir/descurtir em loop não gera uma notificação por volta, e a mesma
/// conquista não é notificada duas vezes. As regras também conferem que o ID
/// corresponde a um fato real (quem curtiu está em likedBy; o comentário
/// existe e é de quem notifica).
class NotificacaoService {
  static final NotificacaoService instance = NotificacaoService();

  /// Teto de não lidas contadas no badge; acima disso a UI mostra "99+".
  static const int tetoNaoLidas = 100;

  CollectionReference<Map<String, dynamic>> _ref(String uid) =>
      FirebaseFirestore.instance
          .collection('notificacoes')
          .doc(uid)
          .collection('items');

  /// ID da notificação de curtida de [uid] na denúncia [ocorrenciaId].
  static String idCurtida(String ocorrenciaId, String uid) =>
      'curtida_${ocorrenciaId}_$uid';

  /// ID da notificação do comentário [comentarioId].
  static String idComentario(String comentarioId) => 'comentario_$comentarioId';

  /// ID da notificação da conquista [titulo].
  static String idConquista(String titulo) => 'conquista_${slugify(titulo)}';

  /// Cria a notificação para o dono da denúncia. [notifId] vem de
  /// [idCurtida] / [idComentario]; mudanças de status (só a autoridade) usam
  /// ID aleatório.
  Future<void> notificar({
    required String donoId,
    required String tipo,
    required String deUsuarioNome,
    required String ocorrenciaId,
    required String ocorrenciaTitulo,
    String? notifId,
  }) async {
    try {
      final dados = NotificacaoModel(
        id: '',
        tipo: tipo,
        deUsuarioNome: deUsuarioNome,
        ocorrenciaId: ocorrenciaId,
        ocorrenciaTitulo: ocorrenciaTitulo,
      ).toMap();
      if (notifId == null) {
        await _ref(donoId).add(dados);
      } else {
        await _ref(donoId).doc(notifId).set(dados);
      }
    } catch (e) {
      // permission-denied aqui é, na maioria das vezes, a deduplicação: a
      // notificação com esse ID já existe.
      debugPrint('Notificação não criada: $e');
    }
  }

  Future<void> notificarConquista({
    required String userId,
    required String conquistaTitulo,
  }) async {
    try {
      await _ref(userId).doc(idConquista(conquistaTitulo)).set(
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
      debugPrint('Notificação de conquista não criada: $e');
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

  /// Não lidas, até [tetoNaoLidas]. Sem o limite, o listener do badge
  /// baixava (e cobrava) todas as não lidas de quem acumulou milhares.
  Stream<int> contarNaoLidas(String uid) {
    return _ref(uid)
        .where('lida', isEqualTo: false)
        .limit(tetoNaoLidas)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Marca todas como lidas em lotes de 450 (o WriteBatch aceita até 500;
  /// num lote único, quem tinha mais que isso nunca conseguia marcar).
  Future<void> marcarTodasComoLidas(String uid) async {
    try {
      final snap = await _ref(uid).where('lida', isEqualTo: false).get();
      final docs = snap.docs;
      for (var i = 0; i < docs.length; i += 450) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in docs.skip(i).take(450)) {
          batch.update(doc.reference, {'lida': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Erro ao marcar notificações como lidas: $e');
    }
  }
}
