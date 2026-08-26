import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usuario_model.dart';
import '../utils/log_erros.dart';
import '../utils/texto.dart';

class UsuarioService {
  static final UsuarioService instance = UsuarioService();

  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('usuarios');

  // Observa o perfil em tempo real
  Stream<UsuarioModel?> observarPerfil(String uid) {
    return _ref.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return UsuarioModel.fromMap(data, uid);
    });
  }

  // Carrega o perfil uma vez
  Future<UsuarioModel?> carregarPerfil(String uid) async {
    final doc = await _ref.doc(uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return UsuarioModel.fromMap(data, uid);
  }

  // Cria ou atualiza o perfil
  Future<void> salvarPerfil(UsuarioModel usuario) {
    return comLogDeErro('salvar perfil', () async {
      // Nome/bio/bairro são exibidos publicamente — higieniza no choke point
      // (nome e bairro em linha única; bio pode ter quebras). Remove
      // zero-width/bidi usados para spoofing de nome.
      final dados = usuario.toMap();
      if (dados['nome'] is String) {
        dados['nome'] = sanitizarLinhaUnica(dados['nome'] as String);
      }
      if (dados['bairro'] is String) {
        dados['bairro'] = sanitizarLinhaUnica(dados['bairro'] as String);
      }
      if (dados['bio'] is String) {
        dados['bio'] = sanitizarTexto(dados['bio'] as String);
      }
      await _ref.doc(usuario.uid).set(dados);
    });
  }

  CollectionReference<Map<String, dynamic>> _seguindoRef(String uid) =>
      _ref.doc(uid).collection('seguindo');

  CollectionReference<Map<String, dynamic>> _seguidoresRef(String uid) =>
      _ref.doc(uid).collection('seguidores');

  Stream<bool> observarSeguindo(String uid, String alvoUid) {
    return _seguindoRef(uid).doc(alvoUid).snapshots().map((doc) => doc.exists);
  }

  Stream<int> contarSeguindo(String uid) {
    return _seguindoRef(uid).snapshots().map((snap) => snap.size);
  }

  Stream<int> contarSeguidores(String uid) {
    return _seguidoresRef(uid).snapshots().map((snap) => snap.size);
  }

  Future<void> seguirUsuario(String uid, String alvoUid) async {
    if (uid == alvoUid) return;
    return comLogDeErro('seguir usuário', () async {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(_seguindoRef(uid).doc(alvoUid), {
        'uid': alvoUid,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      batch.set(_seguidoresRef(alvoUid).doc(uid), {
        'uid': uid,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    });
  }

  Future<void> deixarDeSeguir(String uid, String alvoUid) {
    return comLogDeErro('deixar de seguir', () async {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(_seguindoRef(uid).doc(alvoUid));
      batch.delete(_seguidoresRef(alvoUid).doc(uid));
      await batch.commit();
    });
  }

  Future<void> definirSeguindo({
    required String uid,
    required String alvoUid,
    required bool seguir,
  }) {
    return seguir ? seguirUsuario(uid, alvoUid) : deixarDeSeguir(uid, alvoUid);
  }

  // ── Exclusão de dados (LGPD art. 18) ────────────────────────────────────

  /// Apaga todos os dados pessoais do usuário do Firestore:
  /// perfil, ocorrências e notificações recebidas.
  /// Comentários dentro de ocorrências alheias não são removidos aqui pois
  /// exigem Cloud Functions — eles ficam sem vínculo visível ao perfil deletado.
  Future<void> excluirTodosDados(String uid) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1. Perfil do usuário.
    batch.delete(_ref.doc(uid));

    // 1b. Registro de consentimento (LGPD art. 18 — exclusão completa).
    batch.delete(db.collection('consentimentos').doc(uid));

    // 2. Ocorrências publicadas pelo usuário.
    final ocorrencias = await db
        .collection('ocorrencias')
        .where('usuarioId', isEqualTo: uid)
        .get();
    for (final doc in ocorrencias.docs) {
      batch.delete(doc.reference);
    }

    // 3. Notificações recebidas pelo usuário.
    final notifs = await db
        .collection('notificacoes')
        .doc(uid)
        .collection('items')
        .get();
    for (final doc in notifs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Verifica se já existe outro usuário com o mesmo nome (ignora maiúsculas/
  // minúsculas e espaços nas pontas). [ignorarUid] permite que o próprio
  // usuário mantenha o nome ao editar o perfil.
  Future<bool> nomeEmUso(String nome, {String? ignorarUid}) async {
    final alvo = nome.trim().toLowerCase();
    if (alvo.isEmpty) return false;
    final snapshot = await _ref.get();
    for (final doc in snapshot.docs) {
      if (doc.id == ignorarUid) continue;
      final outro = (doc.data()['nome'] as String?)?.trim().toLowerCase();
      if (outro == alvo) return true;
    }
    return false;
  }
}
