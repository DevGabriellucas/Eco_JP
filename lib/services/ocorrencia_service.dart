import 'dart:async';

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

  Stream<List<OcorrenciaModel>> listarFeedComFixadas(int limit) {
    final uid = _currentUserId;
    final recentes = <String, OcorrenciaModel>{};
    final fixadas = <String, OcorrenciaModel>{};

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? recentesSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? fixadasSub;

    late final StreamController<List<OcorrenciaModel>> controller;

    Map<String, OcorrenciaModel> parse(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      return {
        for (final doc in snapshot.docs)
          doc.id: OcorrenciaModel.fromMap(
            doc.data(),
            doc.id,
            currentUserId: uid,
          ),
      };
    }

    void emitir() {
      final merged = <String, OcorrenciaModel>{}
        ..addAll(recentes)
        ..addAll(fixadas);
      final lista = merged.values.toList()..sort(_ordenarFeed);
      controller.add(lista);
    }

    controller = StreamController<List<OcorrenciaModel>>(
      onListen: () {
        recentesSub = _ocorrenciasRef
            .orderBy('dataCriacao', descending: true)
            .limit(limit)
            .snapshots()
            .listen((snapshot) {
              recentes
                ..clear()
                ..addAll(parse(snapshot));
              emitir();
            }, onError: controller.addError);

        fixadasSub = _ocorrenciasRef
            .where('fixada', isEqualTo: true)
            .snapshots()
            .listen((snapshot) {
              fixadas
                ..clear()
                ..addAll(parse(snapshot));
              emitir();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await recentesSub?.cancel();
        await fixadasSub?.cancel();
      },
    );

    return controller.stream;
  }

  static int _ordenarFeed(OcorrenciaModel a, OcorrenciaModel b) {
    if (a.fixada != b.fixada) return a.fixada ? -1 : 1;
    final dataA = a.dataCriacao ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dataB = b.dataCriacao ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dataB.compareTo(dataA);
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
    var temAtualizacao = false;
    for (final doc in snapshot.docs) {
      // Denúncia anônima nunca recebe nome/foto, mesmo após edição de perfil.
      if (doc.data()['anonima'] == true) continue;
      temAtualizacao = true;
      batch.update(doc.reference, {
        'usuarioNome': nome,
        'usuarioFotoUrl': fotoUrl,
      });
    }
    if (temAtualizacao) await batch.commit();
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

  // ── VERIFICAÇÃO OFICIAL (autoridade) ──────────────────────────────────────

  /// Marca/desmarca uma denúncia como verificada por autoridade.
  /// Ao confirmar (verificar: true), limpa qualquer statusOficial intermediário.
  Future<void> definirVerificacao(
    String id, {
    required bool verificar,
    required String nomeAutoridade,
    String? autoridadeUid,
  }) async {
    try {
      if (verificar) {
        await _ocorrenciasRef.doc(id).update({
          'verificada': true,
          'verificadaPor': autoridadeUid ?? _currentUserId,
          'verificadaPorNome': nomeAutoridade,
          'verificadaEm': FieldValue.serverTimestamp(),
          'statusOficial': null,
        });
      } else {
        // Ao remover a verificação, zera também o ciclo oficial.
        await _ocorrenciasRef.doc(id).update({
          'verificada': false,
          'statusOficial': null,
        });
      }
    } catch (e) {
      debugPrint('Erro ao definir verificação: $e');
      rethrow;
    }
  }

  /// Define o status do ciclo oficial da autoridade.
  /// [status]: 'em_analise', 'nao_confirmada', 'encaminhada', 'resolvida' ou
  /// null (reverter). Grava o carimbo de tempo de auditoria ao encaminhar/resolver.
  Future<void> definirStatusOficial(String id, String? status) async {
    try {
      final data = <String, dynamic>{'statusOficial': status};
      if (status == 'encaminhada') {
        data['encaminhadaEm'] = FieldValue.serverTimestamp();
      } else if (status == 'resolvida') {
        data['resolvidaEm'] = FieldValue.serverTimestamp();
      }
      await _ocorrenciasRef.doc(id).update(data);
    } catch (e) {
      debugPrint('Erro ao definir status oficial: $e');
      rethrow;
    }
  }

  Future<void> definirFixada(String id, {required bool fixada}) async {
    try {
      await _ocorrenciasRef.doc(id).update({'fixada': fixada});
    } catch (e) {
      debugPrint('Erro ao definir destaque da denuncia: $e');
      rethrow;
    }
  }

  /// Retorna denúncias pendentes de verificação (mais antigas primeiro).
  /// Exclui as já confirmadas (verificada==true) e as marcadas como não confirmadas.
  Stream<List<OcorrenciaModel>> listarParaVerificacao() {
    final uid = _currentUserId;
    return _ocorrenciasRef
        .orderBy('dataCriacao', descending: false)
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
              .where(
                (o) => !o.verificada && o.statusOficial != 'nao_confirmada',
              )
              .toList(),
        );
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
    final uid = _currentUserId;
    return _ocorrenciasRef
        .doc(ocorrenciaId)
        .collection('comentarios')
        .orderBy('dataCriacao', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => ComentarioModel.fromMap(
                  doc.data(),
                  doc.id,
                  currentUserId: uid,
                ),
              )
              .toList(),
        );
  }

  Stream<ComentarioModel?> observarUltimoComentario(String ocorrenciaId) {
    final uid = _currentUserId;
    return _ocorrenciasRef
        .doc(ocorrenciaId)
        .collection('comentarios')
        .orderBy('dataCriacao', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          return ComentarioModel.fromMap(
            doc.data(),
            doc.id,
            currentUserId: uid,
          );
        });
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

  Future<void> editarComentario(
    String ocorrenciaId,
    String comentarioId,
    String texto,
  ) async {
    try {
      await _ocorrenciasRef
          .doc(ocorrenciaId)
          .collection('comentarios')
          .doc(comentarioId)
          .update({'texto': texto.trim()});
    } catch (e) {
      debugPrint('Erro ao editar comentário: $e');
      rethrow;
    }
  }

  /// Curte/descurte um comentário (toggle do próprio UID via transação).
  Future<void> toggleLikeComentario(
    String ocorrenciaId,
    String comentarioId,
    String userId,
  ) async {
    final ref = _ocorrenciasRef
        .doc(ocorrenciaId)
        .collection('comentarios')
        .doc(comentarioId);
    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final doc = await txn.get(ref);
        if (!doc.exists) return;
        final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);
        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
        } else {
          likedBy.add(userId);
        }
        txn.update(ref, {'likedBy': likedBy, 'likes': likedBy.length});
      });
    } catch (e) {
      debugPrint('Erro ao curtir comentário: $e');
      rethrow;
    }
  }

  Future<void> deletarComentario(
    String ocorrenciaId,
    String comentarioId,
  ) async {
    try {
      final comentariosRef = _ocorrenciasRef
          .doc(ocorrenciaId)
          .collection('comentarios');
      final respostas = await comentariosRef
          .where('parentId', isEqualTo: comentarioId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      batch.delete(comentariosRef.doc(comentarioId));
      for (final doc in respostas.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Erro ao deletar comentário: $e');
      rethrow;
    }
  }
}
