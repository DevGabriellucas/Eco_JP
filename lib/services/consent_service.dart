import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../pages/legal/documentos_legais.dart';

/// Registro comprovável de consentimento (LGPD art. 8 §1).
///
/// Cada usuário tem um documento em `consentimentos/{uid}` com a versão dos
/// documentos legais aceitos e o carimbo de tempo. Isso permite demonstrar
/// quando e a qual versão da política o usuário consentiu. Quando a versão
/// muda, o app pede um novo consentimento.
class ConsentService {
  ConsentService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  static final ConsentService instance = ConsentService();

  final FirebaseFirestore? _firestoreOverride;

  /// Espera máxima pelo servidor antes de cair no cache local (leitura) ou
  /// deixar a escrita na fila offline (gravação).
  static const _limiteServidor = Duration(seconds: 6);

  CollectionReference<Map<String, dynamic>> get _ref =>
      (_firestoreOverride ?? FirebaseFirestore.instance)
          .collection('consentimentos');

  /// Verifica se o usuário precisa consentir (nunca consentiu ou consentiu
  /// uma versão antiga dos documentos).
  ///
  /// Servidor primeiro; se falhar ou demorar, o cache local (a persistência
  /// offline está ligada). Antes, rede lenta reabria a tela para quem já
  /// tinha consentido. Sem confirmação nem no cache, assume que PRECISA
  /// (falha fechada): quem nunca consentiu não entra sem aceite.
  Future<bool> precisaConsentir(String uid) async {
    final doc = _ref.doc(uid);
    try {
      return _precisa(await doc.get().timeout(_limiteServidor));
    } catch (e) {
      debugPrint('Consentimento: servidor indisponível ($e); usando cache.');
    }
    try {
      return _precisa(
        await doc.get(const GetOptions(source: Source.cache)),
      );
    } catch (e) {
      debugPrint('Consentimento: sem registro no cache ($e).');
      return true;
    }
  }

  bool _precisa(DocumentSnapshot<Map<String, dynamic>> doc) =>
      !doc.exists || doc.data()?['versao'] != kVersaoDocumentosLegais;

  /// Grava o consentimento do usuário na versão atual.
  ///
  /// - Já existe aceite DESTA versão: não regrava, para preservar o
  ///   `aceitoEm` original (é a prova de quando a pessoa consentiu). Antes,
  ///   reabrir a tela por lentidão e aceitar de novo apagava a data.
  /// - Devolve `true` quando o servidor confirmou e `false` quando a escrita
  ///   ficou na fila offline do Firestore (vai sozinha quando a conexão
  ///   voltar). Antes, sem internet, isto não terminava nunca.
  Future<bool> registrar(String uid) async {
    final doc = _ref.doc(uid);
    try {
      final atual = await doc.get().timeout(_limiteServidor);
      if (atual.exists && !_precisa(atual)) return true;
    } catch (_) {
      // Sem como conferir: grava (no pior caso, refaz o aceite da versão).
    }
    final escrita = doc.set({
      'versao': kVersaoDocumentosLegais,
      'aceiteTermos': true,
      'aceitePrivacidade': true,
      'aceitoEm': FieldValue.serverTimestamp(),
    });
    try {
      await escrita.timeout(_limiteServidor);
      return true;
    } on TimeoutException {
      // A escrita continua na fila local; erros que chegarem depois só são
      // registrados (não há mais tela esperando por ela).
      unawaited(escrita.catchError(
        (Object e) => debugPrint('Consentimento pendente falhou: $e'),
      ));
      return false;
    }
  }

  /// Data em que o consentimento atual foi registrado (para exibir no perfil).
  Future<DateTime?> dataConsentimento(String uid) async {
    try {
      final doc = await _ref.doc(uid).get();
      final ts = doc.data()?['aceitoEm'];
      return ts is Timestamp ? ts.toDate() : null;
    } catch (_) {
      return null;
    }
  }
}
