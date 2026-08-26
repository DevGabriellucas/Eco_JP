import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/occurrence_types.dart';
import '../../models/ocorrencia_model.dart';
import '../../services/analytics_service.dart';
import '../../services/rate_limiter.dart';
import '../../utils/log_erros.dart';
import '../../utils/texto.dart';

/// Acesso à coleção `ocorrencias` (denúncias) no Firestore: criação, feed,
/// consultas, status/histórico, ciclo oficial da autoridade, moderação de
/// ocorrência e reações (like/dislike, que mutam o próprio documento).
///
/// As dependências são injetáveis por construtor (com defaults) para permitir
/// testes unitários com `fake_cloud_firestore`.
class OcorrenciaRepository {
  OcorrenciaRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    RateLimiter? rateLimiter,
    AnalyticsService? analytics,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _rateLimiter = rateLimiter ?? RateLimiter.instance,
        _analytics = analytics ?? AnalyticsService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final RateLimiter _rateLimiter;
  final AnalyticsService _analytics;

  // Teto de leitura para visões agregadas (mapa, estatísticas). Evita baixar a
  // coleção inteira e limita o custo de Firestore conforme o app cresce.
  static const int tetoAgregado = 500;

  CollectionReference<Map<String, dynamic>> get _ocorrenciasRef =>
      _firestore.collection('ocorrencias');

  String? get _currentUserId => _auth.currentUser?.uid;

  // ── CREATE ────────────────────────────────────────────────────────────────

  Future<void> cadastrarOcorrencia(OcorrenciaModel ocorrencia) async {
    // Anti-spam client-side: bloqueia envios em rajada do mesmo usuário.
    // Proteção real fica no servidor (Blaze/Cloud Functions), ver RateLimiter.
    _rateLimiter.checarERegistrar(
      'denuncia_${_currentUserId ?? "anon"}',
      RateLimiter.intervaloDenuncia,
    );
    return comLogDeErro('salvar ocorrência', () async {
      // Higieniza os textos livres no choke point de persistência (remove
      // controle/zero-width/bidi; título e localização viram linha única).
      final dados = ocorrencia.toMap();
      dados['titulo'] = sanitizarLinhaUnica(dados['titulo'] as String);
      dados['descricao'] = sanitizarTexto(dados['descricao'] as String);
      dados['localizacao'] = sanitizarLinhaUnica(dados['localizacao'] as String);
      if (dados['usuarioNome'] is String) {
        dados['usuarioNome'] = sanitizarLinhaUnica(dados['usuarioNome'] as String);
      }
      final doc = await _ocorrenciasRef.add(dados);

      // Denúncia anônima: o UID real não vai no documento público (toMap()
      // já grava usuarioId como null nesse caso) — guardamos numa subcoleção
      // privada, legível só pelo próprio dono e pela autoridade (protege
      // contra correlacionar denúncias anônimas pelo autor, S2). Também
      // gravamos um ponteiro no perfil do dono, senão "Minhas denúncias" não
      // consegue mais encontrar essa denúncia (o campo usuarioId sumiu dela).
      if (ocorrencia.anonima && ocorrencia.usuarioId != null) {
        final uid = ocorrencia.usuarioId!;
        await doc.collection('dono').doc('info').set({'usuarioId': uid});
        await _firestore
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
    });
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
    return _firestore
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

  // Observa um conjunto específico de ocorrências por id (usado para listar as
  // denúncias anônimas do próprio usuário). Evita baixar a coleção inteira só
  // para filtrar por id. O Firestore limita `whereIn` a 30 valores; para
  // conjuntos maiores, particiona.
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
    final batch = _firestore.batch();
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

  // Anexa um evento imutável à linha do tempo de auditoria da ocorrência.
  // Chamado dentro do MESMO batch da mudança de status (verificação / status
  // oficial), para que o registro seja atômico com a ação que ele descreve.
  // As Rules só deixam a autoridade criar e nunca editar/apagar (append-only).
  void _registrarHistorico(
    WriteBatch batch,
    String id,
    String statusChave, {
    String? por,
  }) {
    final evento = <String, dynamic>{
      'status': statusChave,
      'data': FieldValue.serverTimestamp(),
    };
    if (por != null && por.trim().isNotEmpty) {
      evento['por'] = por.trim();
    }
    batch.set(_ocorrenciasRef.doc(id).collection('historico').doc(), evento);
  }

  // Linha do tempo (auditoria) das ações oficiais sobre a ocorrência.
  Stream<List<({String status, String? por, DateTime? data})>> listarHistorico(
    String id,
  ) {
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
              por: data['por'] as String?,
              data: data['data'] != null
                  ? (data['data'] as Timestamp).toDate()
                  : null,
            );
          }).toList(),
        );
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<void> deletarOcorrencia(String id) {
    return comLogDeErro('deletar ocorrência', () async {
      // Denúncia anônima tem documentos auxiliares (dono/info e o ponteiro
      // em minhas_denuncias_anonimas) que não são apagados em cascata pelo
      // Firestore — precisam ser limpos manualmente antes/junto da exclusão
      // do doc principal, senão ficam órfãos.
      final ref = _ocorrenciasRef.doc(id);
      final snap = await ref.get();
      final data = snap.data();
      final uid = _currentUserId;

      if (data?['anonima'] == true && uid != null) {
        await _firestore
            .collection('usuarios')
            .doc(uid)
            .collection('minhas_denuncias_anonimas')
            .doc(id)
            .delete();
        await ref.collection('dono').doc('info').delete();
      }

      await ref.delete();
    });
  }

  Future<void> atualizarTextos(
    String id,
    String titulo,
    String descricao,
  ) {
    return comLogDeErro('editar denúncia', () async {
      await _ocorrenciasRef.doc(id).update({
        'titulo': sanitizarLinhaUnica(titulo),
        'descricao': sanitizarTexto(descricao),
      });
    });
  }

  // ── VERIFICAÇÃO OFICIAL (autoridade) ──────────────────────────────────────

  /// Marca/desmarca uma denúncia como verificada por autoridade.
  /// Ao confirmar (verificar: true), limpa qualquer statusOficial intermediário.
  Future<void> definirVerificacao(
    String id, {
    required bool verificar,
    required String nomeAutoridade,
    String? autoridadeUid,
  }) {
    return comLogDeErro('definir verificação', () async {
      if (verificar) {
        final batch = _firestore.batch();
        batch.update(_ocorrenciasRef.doc(id), {
          'verificada': true,
          'verificadaPor': autoridadeUid ?? _currentUserId,
          'verificadaPorNome': nomeAutoridade,
          'verificadaEm': FieldValue.serverTimestamp(),
          'statusOficial': null,
        });
        _registrarHistorico(batch, id, 'verificada', por: nomeAutoridade);
        await batch.commit();
      } else {
        // Ao remover a verificação, zera também o ciclo oficial.
        await _ocorrenciasRef.doc(id).update({
          'verificada': false,
          'statusOficial': null,
        });
      }
    });
  }

  /// Define o status do ciclo oficial da autoridade. [status] null reverte.
  /// Grava o carimbo de tempo de auditoria ao encaminhar/resolver.
  Future<void> definirStatusOficial(String id, StatusOficial? status) {
    return comLogDeErro('definir status oficial', () async {
      final data = <String, dynamic>{'statusOficial': status?.valor};
      if (status == StatusOficial.encaminhada) {
        data['encaminhadaEm'] = FieldValue.serverTimestamp();
      } else if (status == StatusOficial.resolvida) {
        data['resolvidaEm'] = FieldValue.serverTimestamp();
      }
      final batch = _firestore.batch();
      batch.update(_ocorrenciasRef.doc(id), data);
      // Reverter (status == null) não gera evento — é um "desfazer".
      if (status != null) {
        _registrarHistorico(batch, id, status.valor);
      }
      await batch.commit();
      if (status != null) {
        unawaited(_analytics.statusAvancado(statusOficial: status.valor));
      }
    });
  }

  Future<void> definirFixada(String id, {required bool fixada}) {
    return comLogDeErro('definir destaque da denuncia', () async {
      await _ocorrenciasRef.doc(id).update({'fixada': fixada});
    });
  }

  // ── MODERAÇÃO (autoridade) ────────────────────────────────────────────────

  /// Oculta/reexibe uma ocorrência denunciada por abuso. Conteúdo oculto some
  /// do feed do cidadão (ver filtro em listarFeedComFixadas / home_page).
  Future<void> definirOculto(String id, {required bool oculto}) {
    return comLogDeErro('ocultar denúncia', () async {
      await _ocorrenciasRef.doc(id).update({'oculto': oculto});
    });
  }

  /// Retorna denúncias pendentes de verificação (mais antigas primeiro).
  /// Exclui as já confirmadas (verificada==true) e as marcadas como não confirmadas.
  ///
  /// O filtro de pendência roda no cliente (ver `.where` abaixo) porque
  /// `verificada`/`statusOficial` não são gravados no documento na criação
  /// (só quando a autoridade age sobre a ocorrência) — uma query composta do
  /// Firestore não encontraria os documentos que nunca tiveram esses campos
  /// escritos. Por isso **não dá pra aplicar `.limit()` na busca bruta**
  /// ordenada por `dataCriacao` ascendente: as pendentes de verdade tendem a
  /// ser as mais recentes (documentos antigos já foram verificados há tempo),
  /// e um `.limit()` sobre "mais antigas primeiro" cortaria justamente essas —
  /// mostrando a fila como "vazia" enquanto pendentes reais ficam invisíveis.
  /// Em vez disso, busca as mais recentes primeiro (onde a pendência
  /// realmente se concentra) até um teto alto, e a UI ordena para exibição.
  Stream<List<OcorrenciaModel>> listarParaVerificacao() {
    final uid = _currentUserId;
    return _ocorrenciasRef
        .orderBy('dataCriacao', descending: true)
        .limit(tetoAgregado)
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
                (o) =>
                    !o.verificada &&
                    o.statusOficial != StatusOficial.naoConfirmada,
              )
              .toList()
            ..sort((a, b) {
              final dataA = a.dataCriacao ?? DateTime.fromMillisecondsSinceEpoch(0);
              final dataB = b.dataCriacao ?? DateTime.fromMillisecondsSinceEpoch(0);
              return dataA.compareTo(dataB); // mais antigas primeiro
            }),
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

  Future<void> toggleLike(String ocorrenciaId, String userId) =>
      _toggleReacao(ocorrenciaId, userId, curtir: true);

  Future<void> toggleDislike(String ocorrenciaId, String userId) =>
      _toggleReacao(ocorrenciaId, userId, curtir: false);

  // Alterna a reação do usuário de forma mutuamente exclusiva ([curtir] true =
  // like; false = dislike). Tocar na reação já ativa a remove (toggle off);
  // tocar na oposta troca (remove a anterior, adiciona a nova). Usa transação
  // para evitar race condition; os contadores são sempre derivados das listas.
  Future<void> _toggleReacao(
    String ocorrenciaId,
    String userId, {
    required bool curtir,
  }) {
    final ref = _ocorrenciasRef.doc(ocorrenciaId);
    return comLogDeErro('dar ${curtir ? 'like' : 'dislike'}', () async {
      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(ref);
        if (!doc.exists) return;

        final likedBy = List<String>.from(doc.data()!['likedBy'] ?? []);
        final dislikedBy = List<String>.from(doc.data()!['dislikedBy'] ?? []);

        // Lista da reação tocada e a oposta (aliases das listas acima).
        final tocada = curtir ? likedBy : dislikedBy;
        final oposta = curtir ? dislikedBy : likedBy;

        if (tocada.contains(userId)) {
          tocada.remove(userId); // desfaz a reação
        } else {
          tocada.add(userId); // adiciona a reação
          oposta.remove(userId); // remove a oposta se existia
        }

        txn.update(ref, {
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
          'likes': likedBy.length,
          'dislikes': dislikedBy.length,
        });
      });
    });
  }
}
