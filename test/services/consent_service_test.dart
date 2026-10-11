import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_jp/pages/legal/documentos_legais.dart';
import 'package:eco_jp/services/consent_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ConsentService servico;

  setUp(() {
    db = FakeFirebaseFirestore();
    servico = ConsentService(firestore: db);
  });

  DocumentReference<Map<String, dynamic>> doc(String uid) =>
      db.collection('consentimentos').doc(uid);

  test('sem registro precisa consentir', () async {
    expect(await servico.precisaConsentir('u1'), isTrue);
  });

  test('aceite da versão atual não precisa de novo', () async {
    await servico.registrar('u1');
    expect(await servico.precisaConsentir('u1'), isFalse);
  });

  test('aceite de versão antiga precisa de novo', () async {
    await doc('u1').set({
      'versao': '2000-01-01',
      'aceiteTermos': true,
      'aceitePrivacidade': true,
      'aceitoEm': Timestamp.fromDate(DateTime(2000)),
    });
    expect(await servico.precisaConsentir('u1'), isTrue);
  });

  test('aceitar de novo a mesma versão preserva a data original', () async {
    final original = Timestamp.fromDate(DateTime(2026, 10, 2, 9));
    await doc('u1').set({
      'versao': kVersaoDocumentosLegais,
      'aceiteTermos': true,
      'aceitePrivacidade': true,
      'aceitoEm': original,
    });

    // Ex.: a tela reabriu por lentidão e a pessoa aceitou outra vez.
    expect(await servico.registrar('u1'), isTrue);

    final dados = (await doc('u1').get()).data()!;
    expect(dados['aceitoEm'], original);
    expect(dados['versao'], kVersaoDocumentosLegais);
  });

  test('aceite de versão antiga é atualizado para a atual', () async {
    await doc('u1').set({
      'versao': '2000-01-01',
      'aceiteTermos': true,
      'aceitePrivacidade': true,
      'aceitoEm': Timestamp.fromDate(DateTime(2000)),
    });

    expect(await servico.registrar('u1'), isTrue);

    final dados = (await doc('u1').get()).data()!;
    expect(dados['versao'], kVersaoDocumentosLegais);
    expect(dados['aceitoEm'], isNot(Timestamp.fromDate(DateTime(2000))));
  });
}
