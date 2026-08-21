import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_jp/data/repositories/ocorrencia_repository.dart';
import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/services/analytics_service.dart';
import 'package:eco_jp/services/rate_limiter.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Analytics no-op: evita depender do Firebase real nos testes.
class _FakeAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// RateLimiter que nunca bloqueia: os testes de cadastro não dependem do
/// tempo real entre chamadas.
class _NoRateLimit implements RateLimiter {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

OcorrenciaRepository _repo(
  FakeFirebaseFirestore db, {
  String uid = 'user-1',
}) {
  return OcorrenciaRepository(
    firestore: db,
    auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
    rateLimiter: _NoRateLimit(),
    analytics: _FakeAnalytics(),
  );
}

OcorrenciaModel _modelo({
  String titulo = 'Lixo acumulado',
  String? usuarioId = 'user-1',
  bool anonima = false,
}) {
  return OcorrenciaModel(
    id: '',
    titulo: titulo,
    descricao: 'Descrição suficientemente longa',
    localizacao: 'Bessa, João Pessoa',
    latitude: -7.09,
    longitude: -34.84,
    tipoLixo: 'Lixo',
    usuarioId: usuarioId,
    usuarioNome: anonima ? null : 'Fulano',
    anonima: anonima,
  );
}

void main() {
  group('reações (toggleLike / toggleDislike)', () {
    late FakeFirebaseFirestore db;
    late OcorrenciaRepository repo;
    late DocumentReference<Map<String, dynamic>> ref;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = _repo(db);
      ref = await db.collection('ocorrencias').add({
        'likedBy': <String>[],
        'dislikedBy': <String>[],
      });
    });

    Future<Map<String, dynamic>> dados() async => (await ref.get()).data()!;

    test('like é toggle: adiciona e depois remove o próprio usuário', () async {
      await repo.toggleLike(ref.id, 'user-1');
      expect((await dados())['likedBy'], ['user-1']);
      expect((await dados())['likes'], 1);

      await repo.toggleLike(ref.id, 'user-1');
      expect((await dados())['likedBy'], isEmpty);
      expect((await dados())['likes'], 0);
    });

    test('like e dislike são mutuamente exclusivos', () async {
      await repo.toggleLike(ref.id, 'user-1');
      await repo.toggleDislike(ref.id, 'user-1');

      final d = await dados();
      expect(d['likedBy'], isEmpty, reason: 'like some ao dar dislike');
      expect(d['dislikedBy'], ['user-1']);
      expect(d['likes'], 0);
      expect(d['dislikes'], 1);
    });

    test('contadores acompanham as listas com vários usuários', () async {
      await repo.toggleLike(ref.id, 'user-1');
      await repo.toggleLike(ref.id, 'user-2');
      await repo.toggleDislike(ref.id, 'user-3');

      final d = await dados();
      expect((d['likedBy'] as List).toSet(), {'user-1', 'user-2'});
      expect(d['likes'], 2);
      expect(d['dislikes'], 1);
    });
  });

  group('observarPorIds (particionamento do whereIn)', () {
    test('conjunto vazio emite lista vazia', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.observarPorIds({}).first, isEmpty);
    });

    test('mais de 30 ids são buscados em lotes e reunidos', () async {
      final db = FakeFirebaseFirestore();
      final ids = <String>{};
      for (var i = 0; i < 35; i++) {
        final ref = await db.collection('ocorrencias').add({
          'titulo': 'Ocorrência $i',
          'dataCriacao': Timestamp.now(),
        });
        ids.add(ref.id);
      }
      final repo = _repo(db);

      // O whereIn do Firestore limita a 30 valores; observarPorIds particiona.
      // A stream emite parcial por lote, então esperamos o total (35).
      final lista = await repo
          .observarPorIds(ids)
          .firstWhere((l) => l.length == 35)
          .timeout(const Duration(seconds: 5));

      expect(lista.map((o) => o.id).toSet(), ids);
    });
  });

  group('listarParaVerificacao (filtro de pendência no cliente)', () {
    test('exclui verificadas e não-confirmadas, mantém pendentes', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('ocorrencias').add({
        'titulo': 'Pendente',
        'dataCriacao': Timestamp.now(),
      });
      await db.collection('ocorrencias').add({
        'titulo': 'Já verificada',
        'verificada': true,
        'dataCriacao': Timestamp.now(),
      });
      await db.collection('ocorrencias').add({
        'titulo': 'Não confirmada',
        'statusOficial': 'nao_confirmada',
        'dataCriacao': Timestamp.now(),
      });
      final repo = _repo(db);

      final lista = await repo.listarParaVerificacao().first;

      expect(lista.map((o) => o.titulo), ['Pendente']);
    });
  });

  group('cadastrarOcorrencia', () {
    test('grava a denúncia na coleção ocorrencias', () async {
      final db = FakeFirebaseFirestore();
      await _repo(db, uid: 'autor-a').cadastrarOcorrencia(
        _modelo(usuarioId: 'autor-a'),
      );

      final snap = await db.collection('ocorrencias').get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.first.data()['titulo'], 'Lixo acumulado');
    });

    test(
      'denúncia anônima esconde o UID e guarda ponteiros privados (S2)',
      () async {
        final db = FakeFirebaseFirestore();
        await _repo(db, uid: 'autor-b').cadastrarOcorrencia(
          _modelo(usuarioId: 'autor-b', anonima: true),
        );

        final doc = (await db.collection('ocorrencias').get()).docs.first;
        // O documento público não expõe o autor.
        expect(doc.data()['usuarioId'], isNull);
        expect(doc.data()['anonima'], true);

        // Ponteiro privado no dono e no perfil do autor.
        final dono = await db
            .collection('ocorrencias')
            .doc(doc.id)
            .collection('dono')
            .doc('info')
            .get();
        expect(dono.data()!['usuarioId'], 'autor-b');

        final ponteiro = await db
            .collection('usuarios')
            .doc('autor-b')
            .collection('minhas_denuncias_anonimas')
            .doc(doc.id)
            .get();
        expect(ponteiro.exists, isTrue);
      },
    );
  });

  group('definirStatusOficial', () {
    test('grava o valor do enum e o carimbo ao encaminhar', () async {
      final db = FakeFirebaseFirestore();
      final ref = await db.collection('ocorrencias').add({'titulo': 'X'});
      final repo = _repo(db);

      await repo.definirStatusOficial(ref.id, StatusOficial.encaminhada);

      final d = (await ref.get()).data()!;
      expect(d['statusOficial'], 'encaminhada'); // wire string via .valor
      expect(d['encaminhadaEm'], isNotNull);
    });

    test('reverter (null) limpa o status sem gerar evento de histórico', () async {
      final db = FakeFirebaseFirestore();
      final ref = await db.collection('ocorrencias').add({
        'titulo': 'X',
        'statusOficial': 'encaminhada',
      });
      final repo = _repo(db);

      await repo.definirStatusOficial(ref.id, null);

      expect((await ref.get()).data()!['statusOficial'], isNull);
      final historico = await ref.collection('historico').get();
      expect(historico.docs, isEmpty);
    });
  });

  group('deletarOcorrencia', () {
    test('remove os documentos auxiliares de uma denúncia anônima', () async {
      final db = FakeFirebaseFirestore();
      await _repo(db, uid: 'autor-c').cadastrarOcorrencia(
        _modelo(usuarioId: 'autor-c', anonima: true),
      );
      final doc = (await db.collection('ocorrencias').get()).docs.first;
      final repo = _repo(db, uid: 'autor-c');

      await repo.deletarOcorrencia(doc.id);

      expect((await db.collection('ocorrencias').get()).docs, isEmpty);
      final ponteiro = await db
          .collection('usuarios')
          .doc('autor-c')
          .collection('minhas_denuncias_anonimas')
          .doc(doc.id)
          .get();
      expect(ponteiro.exists, isFalse, reason: 'ponteiro órfão foi limpo');
    });
  });
}
