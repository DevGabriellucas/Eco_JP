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
  static final ConsentService instance = ConsentService();

  final CollectionReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('consentimentos');

  /// Verifica se o usuário precisa consentir (nunca consentiu ou consentiu
  /// uma versão antiga dos documentos). Em caso de erro de rede, assume que
  /// NÃO precisa, para não travar o acesso por falha transitória.
  Future<bool> precisaConsentir(String uid) async {
    try {
      final doc = await _ref.doc(uid).get();
      if (!doc.exists) return true;
      return doc.data()?['versao'] != kVersaoDocumentosLegais;
    } catch (e) {
      debugPrint('Erro ao verificar consentimento: $e');
      return false;
    }
  }

  /// Grava (ou atualiza) o consentimento do usuário na versão atual.
  Future<void> registrar(String uid) async {
    await _ref.doc(uid).set({
      'versao': kVersaoDocumentosLegais,
      'aceiteTermos': true,
      'aceitePrivacidade': true,
      'aceitoEm': FieldValue.serverTimestamp(),
    });
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
