import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/comentario_model.dart';
import '../models/ocorrencia_model.dart';
import 'analytics_service.dart';
import 'rate_limiter.dart';

class OcorrenciaService {
  // Teto de leitura para visões agregadas (mapa, estatísticas). Evita baixar a
  // coleção inteira e limita o custo de Firestore conforme o app cresce.
  static const int tetoAgregado = 500;

  // Instância compartilhada opcional — evita recriar o service em cada
  // widget (43+ pontos no app faziam `OcorrenciaService()` direto). O
  // construtor padrão continua disponível para quem preferir instanciar.
  static final OcorrenciaService instance = OcorrenciaService();

  final CollectionReference<Map<String, dynamic>> _ocorrenciasRef =
      FirebaseFirestore.instance.collection('ocorrencias');
  final AnalyticsService _analytics = AnalyticsService();

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // ── CREATE ────────────────────────────────────────────────────────────────

  Future<void> cadastrarOcorrencia(OcorrenciaModel ocorrencia) async {
    // Anti-spam client-side: bloqueia envios em rajada do mesmo usuário.
    // Proteção real fica no servidor (Blaze/Cloud Functions), ver RateLimiter.
    RateLimiter.instance.checarERegistrar(
      'denuncia_${_currentUserId ?? "anon"}',
      RateLimiter.intervaloDenuncia,
    );
    try {
      final doc = await _ocorrenciasRef.add(ocorrencia.toMap());

      // Denúncia anônima: o UID real não vai no documento público (toMap()
      // já grava usuarioId como null nesse caso) — guardamos numa subcoleção
      // privada, legível só pelo próprio dono e pela autoridade (protege
      // contra correlacionar denúncias anônimas pelo autor, S2). Também
      // gravamos um ponteiro no perfil do dono, senão "Minhas denúncias" não
      // consegue mais encontrar essa denúncia (o campo usuarioId sumiu dela).
      if (ocorrencia.anonima && ocorrencia.usuarioId != null) {
        final uid = ocorrencia.usuarioId!;
        await doc.collection('dono').doc('info').set({'usuarioId': uid});
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .collection('minhas_denuncias_anonimas')
            .doc(doc.id)
            .set({});
      }

      unawaited(
        _analytics.denunciaCriada(
          categoria: ocorrencia.tipoLixo,
          anonima: ocorrencia.anonima,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao salvar ocorrência: $e');
      rethrow;
    }
  }

  // ── READ ──────────────────────────────────────────────────────────────────

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

  /// IDs das próprias denúncias anônimas do usuário (ponteiros gravados em
  /// `usuarios/{uid}/minhas_denuncias_anonimas`, já que o documento público
  /// dessas denúncias não guarda usuarioId — ver cadastrarOcorrencia/S2).
  Stream<Set<String>> observarMinhasDenunciasAnonimasIds(String uid) {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('minhas_denuncias_anonimas')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// "Minhas denúncias" completo: combina as não-anônimas (query direta por
  /// usuarioId) com as anônimas (buscadas pelos ponteiros do próprio perfil).
  Stream<List<OcorrenciaModel>> listarMinhasDenuncias(String uid) {
    final naoAnonimas = listarPorUsuario(uid);
    final anonimasIds = observarMinhasDenunciasAnonimasIds(uid);

    late final StreamController<List<OcorrenciaModel>> controller;
    List<OcorrenciaModel> ultimasNaoAnonimas = const [];
    Set<String> ultimosIdsAnonimos = const {};
    StreamSubscription? subNaoAnonimas;
    StreamSubscription? subIds;
    StreamSubscription<List<OcorrenciaModel>>? subAnonimas;

    void emitirAnonimas(Set<String> ids) {
      subAnonimas?.cancel();
      subAnonimas = observarPorIds(ids).listen((anonimas) {
        final merged = <String, OcorrenciaModel>{
          for (final o in ultimasNaoAnonimas) o.id: o,
          for (final o in anonimas) o.id: o,
        };
        final lista = merged.values.toList()..sort(_ordenarFeed);
        controller.add(lista);
      });
    }

    controller = StreamController<List<OcorrenciaModel>>(
      onListen: () {
        subNaoAnonimas = naoAnonimas.listen((lista) {
          ultimasNaoAnonimas = lista;
          emitirAnonimas(ultimosIdsAnonimos);
        });
        subIds = anonimasIds.listen((ids) {
          ultimosIdsAnonimos = ids;
          emitirAnonimas(ids);
        });
      },
      onCancel: () async {
        await subNaoAnonimas?.cancel();
        await subIds?.cancel();
        await subAnonimas?.cancel();
      },
    );

    return controller.stream;
  }

  // Observa um conjunto específico de ocorrências por id (usado nos favoritos
  // do perfil). Evita baixar a coleção inteira só para filtrar por id. O
  // Firestore limita `whereIn` a 30 valores; para conjuntos maiores, particiona.
  Stream<List<OcorrenciaModel>> observarPorIds(Set<String> ids) {
    if (ids.isEmpty) {
      return Stream.value(const <OcorrenciaModel>[]);
    }
    final uid = _currentUserId;
    final lista = ids.toList();
    final lotes = <List<String>>[];
    for (var i = 0; i < lista.length; i += 30) {
      lotes.add(lista.sublist(i, i + 30 > lista.length ? lista.length : i + 30));
    }

    final streams = lotes.map(
      (lote) => _ocorrenciasRef
          .where(FieldPath.documentId, whereIn: lote)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map(
                  (doc) => OcorrenciaModel.fromMap(
                    doc.data(),
                    doc.id,
                    currentUserId: uid,
                  ),
                )
                .toList(),
          ),
    );

    // Combina os lotes num único stream de lista concatenada.
    return _combinarListas(streams.toList());
  }

  static Stream<List<OcorrenciaModel>> _combinarListas(
    List<Stream<List<OcorrenciaModel>>> streams,
  ) {
    if (streams.length == 1) return streams.first;
    final atual = List<List<OcorrenciaModel>>.filled(streams.length, const []);
    late final StreamController<List<OcorrenciaModel>> controller;
    final subs = <StreamSubscription<List<OcorrenciaModel>>>[];

    void emitir() => controller.add([for (final l in atual) ...l]);

    controller = StreamController<List<OcorrenciaModel>>(
      onListen: () {
        for (var i = 0; i < streams.length; i++) {
          final idx = i;
          subs.add(
            streams[idx].listen((lista) {
              atual[idx] = lista;
              emitir();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
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
      // Denúncia anônima tem documentos auxiliares (dono/info e o ponteiro
      // em minhas_denuncias_anonimas) que não são apagados em cascata pelo
      // Firestore — precisam ser limpos manualmente antes/junto da exclusão
      // do doc principal, senão ficam órfãos.
      final ref = _ocorrenciasRef.doc(id);
      final snap = await ref.get();
      final data = snap.data();
      final uid = _currentUserId;

      if (data?['anonima'] == true && uid != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .collection('minhas_denuncias_anonimas')
            .doc(id)
            .delete();
        await ref.collection('dono').doc('info').delete();
      }

      await ref.delete();
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
      if (status != null) {
        unawaited(_analytics.statusAvancado(statusOficial: status));
      }
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

  // ── MODERAÇÃO (autoridade) ────────────────────────────────────────────────

  /// Oculta/reexibe uma ocorrência denunciada por abuso. Conteúdo oculto some
  /// do feed do cidadão (ver filtro em listarFeedComFixadas / home_page).
  Future<void> definirOculto(String id, {required bool oculto}) async {
    try {
      await _ocorrenciasRef.doc(id).update({'oculto': oculto});
    } catch (e) {
      debugPrint('Erro ao ocultar denúncia: $e');
      rethrow;
    }
  }

  /// Oculta/reexibe um comentário denunciado por abuso.
  Future<void> definirComentarioOculto(
    String ocorrenciaId,
    String comentarioId, {
    required bool oculto,
  }) async {
    try {
      await _ocorrenciasRef
          .doc(ocorrenciaId)
          .collection('comentarios')
          .doc(comentarioId)
          .update({'oculto': oculto});
    } catch (e) {
      debugPrint('Erro ao ocultar comentário: $e');
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

  // Quantidade de comentários via aggregation .count(): uma leitura de contagem
  // em vez de baixar todos os documentos. Pontual (não reativo) — o feed
  // recarrega ao abrir/reconstruir, suficiente para o contador.
  Future<int> contarComentarios(String ocorrenciaId) async {
    final snap = await _ocorrenciasRef
        .doc(ocorrenciaId)
        .collection('comentarios')
        .count()
        .get();
    return snap.count ?? 0;
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
    // Anti-spam client-side (mesma ressalva do cadastrarOcorrencia).
    RateLimiter.instance.checarERegistrar(
      'comentario_${_currentUserId ?? "anon"}',
      RateLimiter.intervaloComentario,
    );
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
