import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_jp/data/repositories/ocorrencia_repository.dart';
import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/services/analytics_service.dart';
import 'package:eco_jp/services/rate_limiter.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Analytics de teste: registra os eventos em vez de enviá-los. Implementa
/// os métodos de verdade — o `noSuchMethod` genérico de antes aceitava
/// qualquer assinatura e escondia erros como o parâmetro `bool` que o
/// Firebase Analytics rejeita.
class _FakeAnalytics implements AnalyticsService {
  final eventos = <String>[];

  @override
  Future<void> denunciaCriada({required String categoria}) async =>
      eventos.add('denuncia_criada:$categoria');

  @override
  Future<void> statusAvancado({required String statusOficial}) async =>
      eventos.add('status_avancado:$statusOficial');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'Evento não esperado no teste: ${invocation.memberName}');
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

Future<String> _cadastrar(
  FakeFirebaseFirestore db,
  String uid,
  OcorrenciaModel modelo,
) async {
  final repo = _repo(db, uid: uid);
  final id = repo.novoIdOcorrencia();
  await repo.cadastrarOcorrencia(modelo, id: id);
  return id;
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

  group('incrementarCompartilhamento', () {
    test('cada usuário conta uma vez (não infla em loop)', () async {
      final db = FakeFirebaseFirestore();
      final ref = await db.collection('ocorrencias').add({'shares': 0});

      expect(await _repo(db, uid: 'a').incrementarCompartilhamento(ref.id),
          isTrue);
      expect(await _repo(db, uid: 'a').incrementarCompartilhamento(ref.id),
          isFalse);
      expect((await ref.get()).data()!['shares'], 1);

      await _repo(db, uid: 'b').incrementarCompartilhamento(ref.id);
      expect((await ref.get()).data()!['shares'], 2);

      final registro = await ref.collection('compartilhamentos').doc('a').get();
      expect(registro.data()!['uid'], 'a');
    });

    test('documento sem o campo passa a contar a partir de 1', () async {
      final db = FakeFirebaseFirestore();
      final repo = _repo(db);
      // Denúncia criada antes de 'shares' existir: o increment do Firestore
      // trata campo ausente como zero.
      final ref = await db.collection('ocorrencias').add({'titulo': 'Antiga'});

      await repo.incrementarCompartilhamento(ref.id);

      expect((await ref.get()).data()!['shares'], 1);
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
          'oculto': false,
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

    test('ocultadas pela moderação ficam de fora', () async {
      final db = FakeFirebaseFirestore();
      final visivel = await db.collection('ocorrencias').add({
        'titulo': 'Visível',
        'dataCriacao': Timestamp.now(),
        'oculto': false,
      });
      final oculta = await db.collection('ocorrencias').add({
        'titulo': 'Oculta',
        'dataCriacao': Timestamp.now(),
        'oculto': true,
      });

      final lista =
          await _repo(db).observarPorIds({visivel.id, oculta.id}).first;

      expect(lista.map((o) => o.id), [visivel.id]);
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
      await _cadastrar(db, 'autor-a', _modelo(usuarioId: 'autor-a'));

      final snap = await db.collection('ocorrencias').get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.first.data()['titulo'], 'Lixo acumulado');
    });

    test(
      'denúncia anônima esconde o UID e guarda ponteiros privados (S2)',
      () async {
        final db = FakeFirebaseFirestore();
        await _cadastrar(
            db, 'autor-b', _modelo(usuarioId: 'autor-b', anonima: true));

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

  group('ciclo oficial (auditoria)', () {
    // A autoridade 'user-1' precisa de perfil: o nome dela vai no evento.
    Future<FakeFirebaseFirestore> dbComAutoridade() async {
      final db = FakeFirebaseFirestore();
      await db.collection('usuarios').doc('user-1').set({'nome': 'Semam'});
      return db;
    }

    test('encaminhar grava status, carimbo e evento com o nome do perfil',
        () async {
      final db = await dbComAutoridade();
      final ref = await db.collection('ocorrencias').add({'titulo': 'X'});

      await _repo(db).definirStatusOficial(ref.id, StatusOficial.encaminhada);

      final d = (await ref.get()).data()!;
      expect(d['statusOficial'], 'encaminhada'); // wire string via .valor
      expect(d['encaminhadaEm'], isNotNull);
      final evento = await ref
          .collection('historico')
          .doc(d['ultimoEventoId'] as String)
          .get();
      expect(evento.data()!['status'], 'encaminhada');
      expect(evento.data()!['por'], 'Semam');
    });

    test(
        'reverter resolvida volta a encaminhada, limpa resolvidaEm e registra "revertida"',
        () async {
      final db = await dbComAutoridade();
      final ref = await db.collection('ocorrencias').add({
        'titulo': 'X',
        'verificada': true,
        'statusOficial': 'resolvida',
        'resolvidaEm': Timestamp.now(),
      });

      await _repo(db)
          .reverterStatusOficial(ref.id, atual: StatusOficial.resolvida);

      final d = (await ref.get()).data()!;
      expect(d['statusOficial'], 'encaminhada');
      expect(d['resolvidaEm'], isNull);
      final eventos = await ref.collection('historico').get();
      expect(eventos.docs.map((e) => e.data()['status']), ['revertida']);
    });

    test('verificar usa o nome do perfil no selo, não um texto fixo', () async {
      final db = await dbComAutoridade();
      final ref = await db.collection('ocorrencias').add({'titulo': 'X'});

      final nome = await _repo(db).definirVerificacao(ref.id, verificar: true);

      expect(nome, 'Semam');
      expect((await ref.get()).data()!['verificadaPorNome'], 'Semam');
    });
  });

  group('deletarOcorrencia', () {
    test('remove os documentos auxiliares de uma denúncia anônima', () async {
      final db = FakeFirebaseFirestore();
      await _cadastrar(
          db, 'autor-c', _modelo(usuarioId: 'autor-c', anonima: true));
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

  group('buscarPaginaFeed', () {
    test('traz as visíveis mais antigas que o cursor, em ordem', () async {
      final db = FakeFirebaseFirestore();
      final base = DateTime(2026, 9, 1);
      for (var i = 0; i < 5; i++) {
        await db.collection('ocorrencias').doc('o$i').set({
          'titulo': 'O$i',
          'oculto': i == 1, // o1 oculta: não pode aparecer
          'dataCriacao': Timestamp.fromDate(base.add(Duration(days: i))),
        });
      }

      final pagina = await _repo(db).buscarPaginaFeed(
        antesDe: base.add(const Duration(days: 4)),
        limite: 10,
      );

      expect(pagina.itens.map((o) => o.id), ['o3', 'o2', 'o0']);
    });
  });
}
