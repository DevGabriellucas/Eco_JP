import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/comentario_model.dart';
import '../../services/rate_limiter.dart';
import '../../utils/log_erros.dart';
import '../../utils/texto.dart';

/// Acesso à subcoleção `ocorrencias/{id}/comentarios`: listagem, contagem,
/// criação (com anti-spam), edição, curtida e moderação de comentário.
///
/// Dependências injetáveis por construtor (com defaults) para testes.
class ComentarioRepository {
  ComentarioRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    RateLimiter? rateLimiter,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _rateLimiter = rateLimiter ?? RateLimiter.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final RateLimiter _rateLimiter;

  CollectionReference<Map<String, dynamic>> get _ocorrenciasRef =>
      _firestore.collection('ocorrencias');

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Comentários visíveis ao público de [ocorrenciaId]. As regras só liberam
  /// listagem filtrada por `oculto == false`.
  Query<Map<String, dynamic>> _visiveis(String ocorrenciaId) => _ocorrenciasRef
      .doc(ocorrenciaId)
      .collection('comentarios')
      .where('oculto', isEqualTo: false);

  // Quantidade de comentários via aggregation .count(): uma leitura de contagem
  // em vez de baixar todos os documentos. Pontual (não reativo) — o feed
  // recarrega ao abrir/reconstruir, suficiente para o contador.
  Future<int> contarComentarios(String ocorrenciaId) async {
    final snap = await _visiveis(ocorrenciaId).count().get();
    return snap.count ?? 0;
  }

  Stream<List<ComentarioModel>> listarComentarios(String ocorrenciaId) {
    final uid = _currentUserId;
    return _visiveis(ocorrenciaId)
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
    return _visiveis(ocorrenciaId)
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

  /// Se o usuário logado é o autor da denúncia anônima [ocorrenciaId] (pelo
  /// ponteiro privado em minhas_denuncias_anonimas). Usado para avisar antes
  /// de comentar: o comentário mostra nome e foto e revelaria a autoria.
  Future<bool> souAutorDaDenunciaAnonima(String ocorrenciaId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    try {
      final doc = await _firestore
          .collection('usuarios')
          .doc(uid)
          .collection('minhas_denuncias_anonimas')
          .doc(ocorrenciaId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Grava o comentário e devolve o ID gerado (usado no ID determinístico da
  /// notificação ao dono — ver [NotificacaoService.idComentario]).
  Future<String> adicionarComentario(
    String ocorrenciaId,
    ComentarioModel comentario,
  ) async {
    // Anti-spam client-side (mesma ressalva do cadastrarOcorrencia).
    _rateLimiter.checarERegistrar(
      'comentario_${_currentUserId ?? "anon"}',
      RateLimiter.intervaloComentario,
    );
    return comLogDeErro('adicionar comentário', () async {
      // Higieniza o texto no choke point de persistência: cobre todas as
      // entradas (input principal, resposta rápida) sem depender de cada UI.
      final dados = comentario.toMap();
      dados['texto'] = sanitizarTexto(dados['texto'] as String);
      final ref = await _ocorrenciasRef
          .doc(ocorrenciaId)
          .collection('comentarios')
          .add(dados);
      return ref.id;
    });
  }

  Future<void> editarComentario(
    String ocorrenciaId,
    String comentarioId,
    String texto,
  ) {
    return comLogDeErro('editar comentário', () async {
      await _ocorrenciasRef
          .doc(ocorrenciaId)
          .collection('comentarios')
          .doc(comentarioId)
          .update({'texto': sanitizarTexto(texto)});
    });
  }

  /// Curte/descurte um comentário (toggle do próprio UID via transação).
  ///
  /// Quando [ehAutoridade], grava também `curtidoPorAutoridade` — o selo
  /// "❤️ pela autoridade" antes dependia de quem estava olhando e só aparecia
  /// para a própria autoridade.
  Future<void> toggleLikeComentario(
    String ocorrenciaId,
    String comentarioId,
    String userId, {
    bool ehAutoridade = false,
  }) {
    final ref = _ocorrenciasRef
        .doc(ocorrenciaId)
        .collection('comentarios')
        .doc(comentarioId);
    return comLogDeErro('curtir comentário', () async {
      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(ref);
        if (!doc.exists) return;
        final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);
        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
        } else {
          likedBy.add(userId);
        }
        txn.update(ref, {
          'likedBy': likedBy,
          'likes': likedBy.length,
          if (ehAutoridade) 'curtidoPorAutoridade': likedBy.contains(userId),
        });
      });
    });
  }

  Future<void> deletarComentario(
    String ocorrenciaId,
    String comentarioId,
  ) {
    return comLogDeErro('deletar comentário', () async {
      final comentariosRef =
          _ocorrenciasRef.doc(ocorrenciaId).collection('comentarios');
      // Só apaga o que é do próprio usuário: o comentário e as respostas
      // dele no fio. A regra deixa cada autor apagar apenas o seu, e com uma
      // única resposta alheia no lote o batch inteiro era negado — o
      // comentário nunca saía. Respostas de outras pessoas ficam, sob o
      // marcador "Comentário removido" na UI.
      final respostas = await comentariosRef
          .where('parentId', isEqualTo: comentarioId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      final batch = _firestore.batch();
      batch.delete(comentariosRef.doc(comentarioId));
      for (final doc in respostas.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    });
  }

  /// Oculta/reexibe um comentário denunciado por abuso.
  Future<void> definirComentarioOculto(
    String ocorrenciaId,
    String comentarioId, {
    required bool oculto,
  }) {
    return comLogDeErro('ocultar comentário', () async {
      await _ocorrenciasRef
          .doc(ocorrenciaId)
          .collection('comentarios')
          .doc(comentarioId)
          .update({'oculto': oculto});
    });
  }
}
