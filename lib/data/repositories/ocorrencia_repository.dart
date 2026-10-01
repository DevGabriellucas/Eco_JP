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

  /// Ocorrências visíveis ao público. As regras só liberam consultas
  /// filtradas por `oculto == false` (conteúdo ocultado pela moderação fica
  /// legível só para o dono e a autoridade).
  Query<Map<String, dynamic>> get _visiveis =>
      _ocorrenciasRef.where('oculto', isEqualTo: false);

  // ── CREATE ────────────────────────────────────────────────────────────────

  String get _chaveLimiteDenuncia => 'denuncia_${_currentUserId ?? "anon"}';

  /// Tempo máximo esperando a confirmação do servidor. Sem rede, o SDK
  /// mantém a escrita na fila local e só confirma quando a conexão volta;
  /// passado esse prazo tratamos a denúncia como enviada (pendente de sync).
  static const Duration prazoConfirmacaoEnvio = Duration(seconds: 20);

  /// ID para uma denúncia nova, gerado no cliente. O formulário gera um por
  /// envio e o reaproveita nas novas tentativas: se a primeira já chegou ao
  /// servidor, a segunda não cria uma duplicata.
  String novoIdOcorrencia() => _ocorrenciasRef.doc().id;

  /// Lança [RateLimitException] se o usuário enviou outra denúncia há pouco.
  /// Chamado ANTES dos uploads — senão a mídia sobe e só depois o envio é
  /// recusado, deixando arquivos órfãos no Cloudinary.
  void verificarLimiteDenuncia() {
    _rateLimiter.verificar(_chaveLimiteDenuncia, RateLimiter.intervaloDenuncia);
  }

  /// Grava a denúncia com o ID [id] (ver [novoIdOcorrencia]).
  ///
  /// Denúncia anônima: documento público, `dono/info` e o ponteiro em
  /// `minhas_denuncias_anonimas` vão num único WriteBatch — ou gravam os três
  /// ou nenhum. Em escritas separadas, uma queda de rede no meio deixava a
  /// denúncia sem dono, e as regras aceitavam o primeiro usuário que
  /// gravasse `dono/info`, permitindo que outra conta "sequestrasse" a
  /// denúncia.
  ///
  /// Retorna `false` se o servidor não confirmou dentro de
  /// [prazoConfirmacaoEnvio] (a escrita segue na fila offline do SDK).
  Future<bool> cadastrarOcorrencia(
    OcorrenciaModel ocorrencia, {
    required String id,
  }) async {
    // Anti-spam client-side: bloqueia envios em rajada do mesmo usuário.
    // Proteção real fica no servidor (Blaze/Cloud Functions), ver RateLimiter.
    verificarLimiteDenuncia();
    return comLogDeErro('salvar ocorrência', () async {
      final docRef = _ocorrenciasRef.doc(id);

      // Nova tentativa depois de uma falha de rede: se a anterior já chegou
      // ao servidor, regravar seria um update (negado pelas regras). Nesse
      // caso a denúncia já está publicada.
      final existente = await docRef
          .get(const GetOptions(source: Source.server))
          .then<bool>((s) => s.exists)
          .catchError((_) => false);
      if (existente) {
        _rateLimiter.registrar(_chaveLimiteDenuncia);
        return true;
      }

      // Higieniza os textos livres no choke point de persistência (remove
      // controle/zero-width/bidi; título e localização viram linha única).
      final dados = ocorrencia.toMap();
      dados['titulo'] = sanitizarLinhaUnica(dados['titulo'] as String);
      dados['descricao'] = sanitizarTexto(dados['descricao'] as String);
      dados['localizacao'] =
          sanitizarLinhaUnica(dados['localizacao'] as String);
      // usuarioNome NÃO é higienizado aqui: as regras exigem que seja
      // idêntico ao `nome` do perfil, que já foi higienizado ao salvar.

      final batch = _firestore.batch()..set(docRef, dados);

      // Denúncia anônima: o UID real não vai no documento público (toMap()
      // já grava usuarioId como null nesse caso) — guardamos numa subcoleção
      // privada, legível só pelo próprio dono e pela autoridade (protege
      // contra correlacionar denúncias anônimas pelo autor, S2). Também
      // gravamos um ponteiro no perfil do dono, senão "Minhas denúncias" não
      // consegue mais encontrar essa denúncia (o campo usuarioId sumiu dela).
      if (ocorrencia.anonima) {
        final uid = _currentUserId;
        if (uid == null) throw StateError('Sessão expirada');
        batch
          ..set(docRef.collection('dono').doc('info'), {'usuarioId': uid})
          ..set(
            _firestore
                .collection('usuarios')
                .doc(uid)
                .collection('minhas_denuncias_anonimas')
                .doc(id),
            <String, dynamic>{},
          );
      }

      var confirmado = true;
      try {
        await batch.commit().timeout(prazoConfirmacaoEnvio);
      } on TimeoutException {
        confirmado = false;
      }
      // Registra só depois de gravar: uma falha não deve bloquear o reenvio.
      _rateLimiter.registrar(_chaveLimiteDenuncia);

      unawaited(
        _analytics.denunciaCriada(categoria: ocorrencia.tipoLixo),
      );
      return confirmado;
    });
  }

  // ── READ ──────────────────────────────────────────────────────────────────

  Stream<List<OcorrenciaModel>> listarOcorrenciasLimitadas(int limit) {
    final uid = _currentUserId;
    return _visiveis
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
        recentesSub = _visiveis
            .orderBy('dataCriacao', descending: true)
            .limit(limit)
            .snapshots()
            .listen((snapshot) {
          recentes
            ..clear()
            ..addAll(parse(snapshot));
          emitir();
        }, onError: controller.addError);

        fixadasSub = _visiveis
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

  /// Total de denúncias visíveis, por agregação `count()` (uma leitura, sem
  /// baixar documentos). Usado para rotular as visões limitadas a
  /// [tetoAgregado].
  Future<int> contarVisiveis() async {
    final snap = await _visiveis.count().get();
    return snap.count ?? 0;
  }

  /// Página seguinte do feed: até [limite] denúncias visíveis criadas antes
  /// de [antesDe], lidas uma vez com `get()`.
  ///
  /// Antes cada "carregar mais" recriava o listener com `limit(N+10)` e relia
  /// o feed inteiro (custo quadrático na rolagem). Agora só a primeira página
  /// é um listener ([listarFeedComFixadas]); as demais são leituras pontuais.
  ///
  /// [doCache] indica que a resposta veio do cache local (sem rede): uma
  /// página vazia nesse caso não significa fim do feed.
  Future<({List<OcorrenciaModel> itens, bool doCache})> buscarPaginaFeed({
    required DateTime antesDe,
    required int limite,
  }) async {
    final uid = _currentUserId;
    // Mesmo índice composto do feed (oculto + dataCriacao desc).
    final snap = await _visiveis
        .where('dataCriacao', isLessThan: Timestamp.fromDate(antesDe))
        .orderBy('dataCriacao', descending: true)
        .limit(limite)
        .get();
    return (
      itens: [
        for (final doc in snap.docs)
          OcorrenciaModel.fromMap(doc.data(), doc.id, currentUserId: uid),
      ],
      doCache: snap.metadata.isFromCache,
    );
  }

  static int _ordenarFeed(OcorrenciaModel a, OcorrenciaModel b) {
    if (a.fixada != b.fixada) return a.fixada ? -1 : 1;
    final dataA = a.dataCriacao ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dataB = b.dataCriacao ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dataB.compareTo(dataA);
  }

  /// Denúncias não-anônimas de [usuarioId]. O próprio dono vê também as
  /// ocultadas pela moderação; para outra pessoa (perfil público) só as
  /// visíveis — é o que as regras permitem listar.
  Stream<List<OcorrenciaModel>> listarPorUsuario(String usuarioId) {
    final uid = _currentUserId;
    final base = usuarioId == uid ? _ocorrenciasRef : _visiveis;
    return base.where('usuarioId', isEqualTo: usuarioId).snapshots().map(
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

    // Erros (ex.: permission-denied logo após o logout) vão para o
    // StreamController em vez de estourar como exceção não tratada — antes
    // viravam crash "fatal" no Crashlytics.
    void repassarErro(Object e, StackTrace s) {
      if (!controller.isClosed) controller.addError(e, s);
    }

    void emitirAnonimas(Set<String> ids) {
      subAnonimas?.cancel();
      subAnonimas = observarPorIds(ids).listen((anonimas) {
        final merged = <String, OcorrenciaModel>{
          for (final o in ultimasNaoAnonimas) o.id: o,
          for (final o in anonimas) o.id: o,
        };
        final lista = merged.values.toList()..sort(_ordenarFeed);
        controller.add(lista);
      }, onError: repassarErro);
    }

    controller = StreamController<List<OcorrenciaModel>>(
      onListen: () {
        subNaoAnonimas = naoAnonimas.listen((lista) {
          ultimasNaoAnonimas = lista;
          emitirAnonimas(ultimosIdsAnonimos);
        }, onError: repassarErro);
        subIds = anonimasIds.listen((ids) {
          ultimosIdsAnonimos = ids;
          emitirAnonimas(ids);
        }, onError: repassarErro);
      },
      onCancel: () async {
        await subNaoAnonimas?.cancel();
        await subIds?.cancel();
        await subAnonimas?.cancel();
      },
    );

    return controller.stream;
  }

  /// Todas as denúncias do usuário, anônimas incluídas, lidas uma vez direto
  /// do servidor. Para a exportação de dados (LGPD art. 18): a versão
  /// anterior usava [listarPorUsuario], que não acha as anônimas (sem
  /// usuarioId no documento), e `.first` da stream podia vir do cache local
  /// incompleto.
  Future<List<OcorrenciaModel>> buscarMinhasDenunciasNoServidor(
      String uid) async {
    const servidor = GetOptions(source: Source.server);
    final naoAnonimas =
        await _ocorrenciasRef.where('usuarioId', isEqualTo: uid).get(servidor);
    final ponteiros = await _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('minhas_denuncias_anonimas')
        .get(servidor);
    final anonimas = await Future.wait(
      ponteiros.docs.map((p) => _ocorrenciasRef.doc(p.id).get(servidor)),
    );
    final lista = [
      for (final doc in naoAnonimas.docs)
        OcorrenciaModel.fromMap(doc.data(), doc.id, currentUserId: uid),
      for (final doc in anonimas)
        if (doc.exists)
          OcorrenciaModel.fromMap(doc.data()!, doc.id, currentUserId: uid),
    ]..sort(_ordenarFeed);
    return lista;
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
      lotes
          .add(lista.sublist(i, i + 30 > lista.length ? lista.length : i + 30));
    }

    final streams = lotes.map(
      // Anônimas: o documento não tem usuarioId, então a listagem só passa
      // nas regras com o filtro de visíveis (as ocultadas somem da lista).
      (lote) =>
          _visiveis.where(FieldPath.documentId, whereIn: lote).snapshots().map(
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
  /// A denúncia [id], ou `null` se não existe ou foi ocultada pela moderação
  /// (as regras negam a leitura a quem não é dono nem autoridade).
  Future<OcorrenciaModel?> buscarPorId(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _ocorrenciasRef.doc(id).get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
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
    final snapshot =
        await _ocorrenciasRef.where('usuarioId', isEqualTo: uid).get();
    // Denúncia anônima nunca recebe nome/foto, mesmo após edição de perfil.
    final docs =
        snapshot.docs.where((d) => d.data()['anonima'] != true).toList();
    // WriteBatch aceita no máximo 500 escritas; quem tem mais denúncias que
    // isso fazia o commit único falhar.
    for (var i = 0; i < docs.length; i += 450) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(450)) {
        batch.update(doc.reference, {
          'usuarioNome': nome,
          'usuarioFotoUrl': fotoUrl,
        });
      }
      await batch.commit();
    }
  }

  // Anexa um evento imutável à linha do tempo de auditoria da ocorrência,
  // no MESMO batch da mudança que ele descreve, e devolve o ID do evento —
  // gravado em `ultimoEventoId` no documento. As regras exigem esse evento
  // (getAfter) em toda ação oficial: antes a auditoria era opcional e o
  // campo `por` era texto livre.
  String _registrarHistorico(
    WriteBatch batch,
    String id,
    String statusChave, {
    required String por,
  }) {
    final ref = _ocorrenciasRef.doc(id).collection('historico').doc();
    batch.set(ref, {
      'status': statusChave,
      'por': por,
      'data': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Nome do perfil da autoridade logada — as regras exigem que `por` e
  /// `verificadaPorNome` sejam exatamente esse nome (antes a fila gravava o
  /// texto fixo 'Autoridade').
  Future<String> _nomeDaAutoridade() async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('Sessão expirada');
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    final nome = doc.data()?['nome'] as String?;
    if (nome == null || nome.trim().isEmpty) {
      throw StateError('Perfil da autoridade sem nome');
    }
    return nome;
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

  /// Marca/desmarca uma denúncia como verificada pela autoridade logada e
  /// devolve o nome gravado no selo. Ao confirmar, limpa qualquer
  /// statusOficial intermediário; ao desmarcar, zera o ciclo oficial e
  /// registra o evento "revertida".
  Future<String> definirVerificacao(String id, {required bool verificar}) {
    return comLogDeErro('definir verificação', () async {
      final nome = await _nomeDaAutoridade();
      final batch = _firestore.batch();
      if (verificar) {
        final evento = _registrarHistorico(batch, id, 'verificada', por: nome);
        batch.update(_ocorrenciasRef.doc(id), {
          'verificada': true,
          'verificadaPor': _currentUserId,
          'verificadaPorNome': nome,
          'verificadaEm': FieldValue.serverTimestamp(),
          'statusOficial': null,
          'ultimoEventoId': evento,
        });
      } else {
        final evento = _registrarHistorico(batch, id, 'revertida', por: nome);
        batch.update(_ocorrenciasRef.doc(id), {
          'verificada': false,
          'statusOficial': null,
          'ultimoEventoId': evento,
        });
      }
      await batch.commit();
      return nome;
    });
  }

  /// Avança o ciclo oficial para [status], com o carimbo de tempo de
  /// auditoria ao encaminhar/resolver. Para desfazer use [reverterStatusOficial].
  Future<void> definirStatusOficial(String id, StatusOficial status) {
    return comLogDeErro('definir status oficial', () async {
      final nome = await _nomeDaAutoridade();
      final batch = _firestore.batch();
      final evento = _registrarHistorico(batch, id, status.valor, por: nome);
      final data = <String, dynamic>{
        'statusOficial': status.valor,
        'ultimoEventoId': evento,
      };
      if (status == StatusOficial.encaminhada) {
        data['encaminhadaEm'] = FieldValue.serverTimestamp();
      } else if (status == StatusOficial.resolvida) {
        data['resolvidaEm'] = FieldValue.serverTimestamp();
      }
      batch.update(_ocorrenciasRef.doc(id), data);
      await batch.commit();
      unawaited(_analytics.statusAvancado(statusOficial: status.valor));
    });
  }

  /// Desfaz o último passo do ciclo oficial a partir de [atual]: resolvida
  /// volta a encaminhada (limpando `resolvidaEm`); os demais voltam ao
  /// estágio base (pendente ou confirmada, conforme `verificada`).
  ///
  /// Ação própria, com evento "revertida" e sem notificar o cidadão. Antes
  /// "Reverter para encaminhada" chamava o fluxo de encaminhar: gravava novo
  /// `encaminhadaEm`, um evento "encaminhada" falso, notificava o cidadão e
  /// mantinha `resolvidaEm` contando nas métricas.
  Future<void> reverterStatusOficial(String id,
      {required StatusOficial atual}) {
    return comLogDeErro('reverter status oficial', () async {
      final nome = await _nomeDaAutoridade();
      final batch = _firestore.batch();
      final evento = _registrarHistorico(batch, id, 'revertida', por: nome);
      batch.update(
        _ocorrenciasRef.doc(id),
        atual == StatusOficial.resolvida
            ? {
                'statusOficial': StatusOficial.encaminhada.valor,
                'resolvidaEm': null,
                'ultimoEventoId': evento,
              }
            : {'statusOficial': null, 'ultimoEventoId': evento},
      );
      await batch.commit();
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
              final dataA =
                  a.dataCriacao ?? DateTime.fromMillisecondsSinceEpoch(0);
              final dataB =
                  b.dataCriacao ?? DateTime.fromMillisecondsSinceEpoch(0);
              return dataA.compareTo(dataB); // mais antigas primeiro
            }),
        );
  }

  // ── COMPARTILHAMENTO ──────────────────────────────────────────────────────

  /// Soma 1 ao contador de compartilhamentos, uma vez por usuário: o +1 vai
  /// no mesmo batch que cria `compartilhamentos/{uid}`, e as regras negam se
  /// esse registro já existir. Retorna `false` quando o usuário já tinha
  /// compartilhado (o contador não muda).
  Future<bool> incrementarCompartilhamento(String ocorrenciaId) {
    return comLogDeErro('registrar compartilhamento', () async {
      final uid = _currentUserId;
      if (uid == null) return false;
      final ref = _ocorrenciasRef.doc(ocorrenciaId);
      final registro = ref.collection('compartilhamentos').doc(uid);
      if ((await registro.get()).exists) return false;
      final batch = _firestore.batch()
        ..update(ref, {'shares': FieldValue.increment(1)})
        ..set(registro, {'uid': uid, 'criadoEm': FieldValue.serverTimestamp()});
      await batch.commit();
      return true;
    });
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
        // Carimbo exigido pelas regras (intervalo mínimo entre reações).
        txn.set(
          _firestore
              .collection('usuarios')
              .doc(userId)
              .collection('meta')
              .doc('reacao'),
          {'ultima': FieldValue.serverTimestamp()},
        );
      });
    });
  }
}
