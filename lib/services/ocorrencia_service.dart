import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/comentario_model.dart';
import '../models/ocorrencia_model.dart';

class OcorrenciaService {
  final CollectionReference<Map<String, dynamic>> _ocorrenciasRef =
      FirebaseFirestore.instance.collection('ocorrencias');

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // ── CREATE ────────────────────────────────────────────────────────────────

  Future<void> cadastrarOcorrencia(OcorrenciaModel ocorrencia) async {
    try {
      await _ocorrenciasRef.add(ocorrencia.toMap());
    } catch (e) {
      debugPrint('Erro ao salvar ocorrência: $e');
      rethrow;
    }
  }

  // ── READ — stream completo (estatísticas / perfil) ────────────────────────

  Stream<List<OcorrenciaModel>> listarOcorrencias() {
    final uid = _currentUserId;
    return _ocorrenciasRef
        .orderBy('dataCriacao', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OcorrenciaModel.fromMap(
                  doc.data(),
                  doc.id,
                  currentUserId: uid,
                ),
              )
              .toList(),
        );
  }

  Stream<List<OcorrenciaModel>> listarOcorrenciasLimitadas(int limit) {
    final uid = _currentUserId;
    return _ocorrenciasRef
        .orderBy('dataCriacao', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OcorrenciaModel.fromMap(
                  doc.data(),
                  doc.id,
                  currentUserId: uid,
                ),
              )
              .toList(),
        );
  }

  Stream<List<OcorrenciaModel>> listarPorUsuario(String usuarioId) {
    final uid = _currentUserId;
    return _ocorrenciasRef
        .where('usuarioId', isEqualTo: usuarioId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OcorrenciaModel.fromMap(
                  doc.data(),
                  doc.id,
                  currentUserId: uid,
                ),
              )
              .toList(),
        );
  }

  // Busca uma única ocorrência pelo id (usado ao tocar numa notificação).
  Future<OcorrenciaModel?> buscarPorId(String id) async {
    final doc = await _ocorrenciasRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return OcorrenciaModel.fromMap(
      doc.data()!,
      doc.id,
      currentUserId: _currentUserId,
    );
  }

  // ── READ — paginado (feed da home) ───────────────────────────────────────

  Future<List<OcorrenciaModel>> listarOcorrenciasPaginadas({
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int limit = 10,
  }) async {
    final uid = _currentUserId;
    var query = _ocorrenciasRef
        .orderBy('dataCriacao', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              OcorrenciaModel.fromMap(doc.data(), doc.id, currentUserId: uid),
        )
        .toList();
  }

  // Retorna o DocumentSnapshot cursor para a próxima página.
  Future<QuerySnapshot<Map<String, dynamic>>> listarOcorrenciasRaw({
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int limit = 10,
  }) async {
    var query = _ocorrenciasRef
        .orderBy('dataCriacao', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.get();
  }

  // ── UPDATE — status ───────────────────────────────────────────────────────

  Future<void> atualizarPerfilNasOcorrencias(
    String uid,
    String nome,
    String? fotoUrl,
  ) async {
    final snapshot = await _ocorrenciasRef
        .where('usuarioId', isEqualTo: uid)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'usuarioNome': nome,
        'usuarioFotoUrl': fotoUrl,
      });
    }
    await batch.commit();
  }

  Future<void> atualizarStatus(String id, String novoStatus) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_ocorrenciasRef.doc(id), {'status': novoStatus});
      // Registra o evento na linha do tempo (histórico de status).
      batch.set(_ocorrenciasRef.doc(id).collection('historico').doc(), {
        'status': novoStatus,
        'data': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      debugPrint('Erro ao atualizar status: $e');
      rethrow;
    }
  }

  // Linha do tempo das mudanças de status de uma ocorrência.
  Stream<List<({String status, DateTime? data})>> listarHistorico(String id) {
    return _ocorrenciasRef
        .doc(id)
        .collection('historico')
        .orderBy('data', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return (
              status: (data['status'] ?? '') as String,
              data: data['data'] != null
                  ? (data['data'] as Timestamp).toDate()
                  : null,
            );
          }).toList(),
        );
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<void> deletarOcorrencia(String id) async {
    try {
      await _ocorrenciasRef.doc(id).delete();
    } catch (e) {
      debugPrint('Erro ao deletar ocorrência: $e');
      rethrow;
    }
  }

  Future<void> atualizarTextos(
    String id,
    String titulo,
    String descricao,
  ) async {
    try {
      await _ocorrenciasRef.doc(id).update({
        'titulo': titulo,
        'descricao': descricao,
      });
    } catch (e) {
      debugPrint('Erro ao editar denúncia: $e');
      rethrow;
    }
  }

  // ── LIKE / DISLIKE ────────────────────────────────────────────────────────
  //
  // Regras:
  //   • Like e dislike são mutuamente exclusivos.
  //   • Clicar em like quando já curtiu → remove o like (toggle off).
  //   • Clicar em dislike quando já curtiu → remove like e adiciona dislike.
  //   • Mesma lógica simétrica para dislike.
  //   Usamos transação Firestore para evitar race condition.

  Future<void> toggleLike(String ocorrenciaId, String userId) async {
    final ref = _ocorrenciasRef.doc(ocorrenciaId);
    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final doc = await txn.get(ref);
        if (!doc.exists) return;

        final likedBy = List<String>.from(doc.data()!['likedBy'] ?? []);
        final dislikedBy = List<String>.from(doc.data()!['dislikedBy'] ?? []);

        if (likedBy.contains(userId)) {
          likedBy.remove(userId); // desfaz like
        } else {
          likedBy.add(userId); // adiciona like
          dislikedBy.remove(userId); // remove dislike se existia
        }

        // Contadores sempre derivados das listas (mantém likes == likedBy.length).
        txn.update(ref, {
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
          'likes': likedBy.length,
          'dislikes': dislikedBy.length,
        });
      });
    } catch (e) {
      debugPrint('Erro ao dar like: $e');
      rethrow;
    }
  }

  Future<void> toggleDislike(String ocorrenciaId, String userId) async {
    final ref = _ocorrenciasRef.doc(ocorrenciaId);
    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final doc = await txn.get(ref);
        if (!doc.exists) return;

        final likedBy = List<String>.from(doc.data()!['likedBy'] ?? []);
        final dislikedBy = List<String>.from(doc.data()!['dislikedBy'] ?? []);

        if (dislikedBy.contains(userId)) {
          dislikedBy.remove(userId); // desfaz dislike
        } else {
          dislikedBy.add(userId); // adiciona dislike
          likedBy.remove(userId); // remove like se existia
        }

        txn.update(ref, {
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
          'likes': likedBy.length,
          'dislikes': dislikedBy.length,
        });
      });
    } catch (e) {
      debugPrint('Erro ao dar dislike: $e');
      rethrow;
    }
  }

  // ── COMENTÁRIOS ───────────────────────────────────────────────────────────

  // Quantidade de comentários em tempo real (usado no contador do feed).
  Stream<int> contarComentarios(String ocorrenciaId) {
    return _ocorrenciasRef
        .doc(ocorrenciaId)
        .collection('comentarios')
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<List<ComentarioModel>> listarComentarios(String ocorrenciaId) {
    return _ocorrenciasRef
        .doc(ocorrenciaId)
        .collection('comentarios')
        .orderBy('dataCriacao', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ComentarioModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> adicionarComentario(
    String ocorrenciaId,
    ComentarioModel comentario,
  ) async {
    try {
      await _ocorrenciasRef
          .doc(ocorrenciaId)
          .collection('comentarios')
          .add(comentario.toMap());
    } catch (e) {
      debugPrint('Erro ao adicionar comentário: $e');
      rethrow;
    }
  }

  Future<void> deletarComentario(
    String ocorrenciaId,
    String comentarioId,
  ) async {
    try {
      await _ocorrenciasRef
          .doc(ocorrenciaId)
          .collection('comentarios')
          .doc(comentarioId)
          .delete();
    } catch (e) {
      debugPrint('Erro ao deletar comentário: $e');
      rethrow;
    }
  }
}
