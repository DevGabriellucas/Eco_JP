import 'package:eco_jp/services/sessao_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore db;
  late SessaoService sessao;

  Future<String?> idRemoto(String uid) async => (await db
          .collection('usuarios')
          .doc(uid)
          .collection('meta')
          .doc('sessao')
          .get())
      .data()?['id'] as String?;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    sessao = SessaoService(firestore: db);
  });

  test('primeiro login registra um id novo no aparelho e no servidor',
      () async {
    final id = await sessao.garantirSessaoLocal('alice');

    expect(id, isNotNull);
    expect(id, hasLength(32));
    expect(await idRemoto('alice'), id);
  });

  test('reabrir o app reaproveita o id e não derruba outro aparelho', () async {
    final primeiro = await sessao.garantirSessaoLocal('alice');
    final depois = await sessao.garantirSessaoLocal('alice');

    expect(depois, primeiro);
  });

  test('login em outro aparelho avisa a sessão antiga', () async {
    final idA = (await sessao.garantirSessaoLocal('alice'))!;
    final avisos = <void>[];
    final sub =
        sessao.observarSessaoSubstituida('alice', idA).listen(avisos.add);
    await pumpEventQueue();
    expect(avisos, isEmpty);

    // Outro aparelho: id próprio gravado no mesmo documento.
    await db
        .collection('usuarios')
        .doc('alice')
        .collection('meta')
        .doc('sessao')
        .set({'id': SessaoService.gerarIdSessao()});
    await pumpEventQueue();

    expect(avisos, hasLength(1));
    await sub.cancel();
  });

  test('documento apagado (exclusão de conta) não derruba ninguém', () async {
    final idA = (await sessao.garantirSessaoLocal('alice'))!;
    final avisos = <void>[];
    final sub =
        sessao.observarSessaoSubstituida('alice', idA).listen(avisos.add);

    await db
        .collection('usuarios')
        .doc('alice')
        .collection('meta')
        .doc('sessao')
        .delete();
    await pumpEventQueue();

    expect(avisos, isEmpty);
    await sub.cancel();
  });

  test('logout esquece o id: o próximo login cria outro', () async {
    final antes = await sessao.garantirSessaoLocal('alice');
    await sessao.esquecerSessaoLocal('alice');
    final depois = await sessao.garantirSessaoLocal('alice');

    expect(depois, isNot(antes));
    expect(await idRemoto('alice'), depois);
  });
}
