import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uma sessão ativa por conta: o último aparelho a entrar fica com a conta e
/// os outros são desconectados.
///
/// Cada login gera um id aleatório, guardado no aparelho e em
/// `usuarios/{uid}/meta/sessao`. O aparelho cujo id não bate mais com o do
/// servidor perdeu a sessão para outro login. O documento guarda só o id —
/// nem data, nem aparelho — para não virar registro de acesso (dado pessoal
/// que a política de privacidade não prevê).
///
/// Falha aberta: se não der para gravar o id (sem rede, regras antigas), o
/// aparelho segue logado sem a checagem, em vez de derrubar quem não deve.
class SessaoService {
  SessaoService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  static final SessaoService instance = SessaoService();

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore
      .collection('usuarios')
      .doc(uid)
      .collection('meta')
      .doc('sessao');

  static String _chaveLocal(String uid) => 'sessao_ativa_$uid';

  /// Id da sessão deste aparelho para [uid]. Na primeira vez após o login
  /// cria um id novo e o registra no servidor — o que derruba a sessão de
  /// qualquer outro aparelho. Devolve `null` se não conseguiu registrar.
  Future<String?> garantirSessaoLocal(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final atual = prefs.getString(_chaveLocal(uid));
    if (atual != null) return atual;

    final id = gerarIdSessao();
    try {
      await _doc(uid).set({'id': id});
    } catch (e) {
      debugPrint('Erro ao registrar a sessão: $e');
      return null;
    }
    await prefs.setString(_chaveLocal(uid), id);
    return id;
  }

  /// Emite quando outro aparelho assumiu a conta de [uid].
  ///
  /// Só confia em leitura confirmada pelo servidor: o cache local pode trazer
  /// o id de uma sessão anterior deste mesmo aparelho. Documento ausente
  /// (conta sendo excluída) não derruba ninguém.
  Stream<void> observarSessaoSubstituida(String uid, String idLocal) {
    return _doc(uid)
        .snapshots(includeMetadataChanges: true)
        .where(
          (s) =>
              s.exists &&
              !s.metadata.isFromCache &&
              !s.metadata.hasPendingWrites,
        )
        .where((s) {
      final id = s.data()?['id'];
      return id is String && id != idLocal;
    }).map((_) {});
  }

  /// Esquece o id local de [uid] (logout). O próximo login cria outro.
  Future<void> esquecerSessaoLocal(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveLocal(uid));
  }

  /// 128 bits aleatórios em hexadecimal (32 caracteres).
  @visibleForTesting
  static String gerarIdSessao() {
    final rnd = Random.secure();
    return List.generate(
      16,
      (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
