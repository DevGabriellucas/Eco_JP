import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usuario_model.dart';
import '../utils/log_erros.dart';
import '../utils/texto.dart';

class UsuarioService {
  static final UsuarioService instance = UsuarioService();

  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('usuarios');

  // Índice de unicidade de nome de exibição: um documento por nome, tendo o
  // slug do nome como ID. Ver [nomeEmUso] para o motivo de existir.
  final CollectionReference<Map<String, dynamic>> _nomesRef = FirebaseFirestore
      .instance
      .collection('nomes_reservados');

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

  /// Máximo de operações aceitas por um WriteBatch do Firestore.
  static const int _maxOpsPorLote = 500;

  /// Apaga todos os dados pessoais do usuário do Firestore: perfil,
  /// consentimento, denúncias (anônimas incluídas), notificações e vínculos
  /// de seguir/ser seguido.
  ///
  /// PRECISA rodar com a sessão do usuário ainda ATIVA. Todas as regras de
  /// exclusão exigem `request.auth.uid` (ver firestore.rules:601, 621, 630,
  /// 635, 681): chamar esta função depois de `user.delete()` faz cada escrita
  /// falhar com permission-denied, porque o SDK já descartou o token. Por isso
  /// o chamador apaga os dados ANTES de excluir a conta do Auth.
  ///
  /// Comentários feitos em denúncias de outras pessoas não são removidos —
  /// exigiriam varrer todas as ocorrências. Ficam sem vínculo visível com o
  /// perfil apagado (anonimização, LGPD art. 18, IV), como declara a Política
  /// de Privacidade, item 6.
  ///
  /// A exclusão NÃO é atômica: acima de 500 documentos ela é dividida em
  /// vários commits. Se um lote falhar, os anteriores já foram aplicados — uma
  /// exclusão parcial é preferível a nenhuma, e o chamador reporta a falha.
  Future<void> excluirTodosDados(String uid) async {
    final db = FirebaseFirestore.instance;
    final lotes = _LotesDeExclusao(db);

    // 1. Denúncias anônimas. O documento público NÃO guarda usuarioId (ver
    //    OcorrenciaRepository.cadastrarOcorrencia), então a query do passo 2
    //    não as encontra. Só os ponteiros do próprio perfil sabem quais são —
    //    sem este passo, as denúncias anônimas sobreviveriam à exclusão.
    final ponteiros = await _ref
        .doc(uid)
        .collection('minhas_denuncias_anonimas')
        .get();
    for (final ponteiro in ponteiros.docs) {
      final ocorrencia = db.collection('ocorrencias').doc(ponteiro.id);
      // As Rules avaliam get() contra o estado já commitado, então apagar a
      // ocorrência e o dono/info que comprova a titularidade no mesmo lote é
      // seguro: isOwner() ainda enxerga dono/info na hora da avaliação.
      lotes.deletar(ocorrencia);
      lotes.deletar(ocorrencia.collection('dono').doc('info'));
      lotes.deletar(ponteiro.reference);
    }

    // 2. Denúncias não-anônimas.
    final ocorrencias = await db
        .collection('ocorrencias')
        .where('usuarioId', isEqualTo: uid)
        .get();
    for (final doc in ocorrencias.docs) {
      lotes.deletar(doc.reference);
    }

    // 3. Notificações recebidas.
    final notifs = await db
        .collection('notificacoes')
        .doc(uid)
        .collection('items')
        .get();
    for (final doc in notifs.docs) {
      lotes.deletar(doc.reference);
    }

    // 4. Grafo social pelos dois lados: cada vínculo existe duplicado (o
    //    `seguindo` de quem segue e o `seguidores` de quem é seguido). Apagar
    //    só o lado deste usuário deixaria o outro perfil apontando para uma
    //    conta inexistente.
    final seguindo = await _seguindoRef(uid).get();
    for (final doc in seguindo.docs) {
      lotes.deletar(doc.reference);
      lotes.deletar(_seguidoresRef(doc.id).doc(uid));
    }
    final seguidores = await _seguidoresRef(uid).get();
    for (final doc in seguidores.docs) {
      lotes.deletar(doc.reference);
      lotes.deletar(_seguindoRef(doc.id).doc(uid));
    }

    // 5. Reserva do nome. Sem isto o nome ficaria permanentemente bloqueado
    //    por uma conta que não existe mais.
    final perfil = await _ref.doc(uid).get();
    final nome = perfil.data()?['nome'] as String?;
    final slug = nome == null ? null : idDoNome(nome);
    if (slug != null) lotes.deletar(_nomesRef.doc(slug));

    // 6. Consentimento e perfil por último: nada mais depende deles.
    lotes.deletar(db.collection('consentimentos').doc(uid));
    lotes.deletar(_ref.doc(uid));

    await lotes.commit();
  }

  /// ID do nome no índice de unicidade, ou null quando [nome] não tem nenhuma
  /// letra ou dígito — aí não existe identificador estável e o nome é recusado.
  ///
  /// Usa [slugify], então a comparação ignora maiúsculas, acentos e pontuação:
  /// "José Silva", "jose silva" e "JOSE-SILVA" disputam o mesmo documento. Isso
  /// é intencional — em app de denúncia, dois perfis com nomes visualmente
  /// confundíveis são um vetor de personificação, não uma conveniência.
  static String? idDoNome(String nome) {
    final slug = slugify(nome);
    return slug.isEmpty ? null : slug;
  }

  /// Verifica se o nome já pertence a outra conta. [ignorarUid] permite que o
  /// próprio usuário mantenha o nome ao editar o perfil.
  ///
  /// Leitura de um único documento. A versão anterior varria a coleção
  /// `usuarios` inteira a cada cadastro — custo O(n) em leituras, ou seja,
  /// 30 mil leituras por cadastro numa base de 30 mil contas.
  ///
  /// Serve para dar mensagem de erro antecipada na UI; a garantia real é
  /// [reservarNome], porque entre esta leitura e a criação do perfil outra
  /// conta pode levar o nome.
  Future<bool> nomeEmUso(String nome, {String? ignorarUid}) async {
    final slug = idDoNome(nome);
    if (slug == null) return false;
    final doc = await _nomesRef.doc(slug).get();
    if (!doc.exists) return false;
    return doc.data()?['uid'] != ignorarUid;
  }

  /// Reserva [nome] para [uid]. True se a reserva ficou com esta conta.
  ///
  /// A atomicidade vem das Rules, não de transação: `nomes_reservados` permite
  /// create e nega update, então um set() sobre um slug já tomado é avaliado
  /// como update e recebe permission-denied. Dois cadastros simultâneos com o
  /// mesmo nome não passam mais os dois — quem escreve primeiro fica com ele.
  Future<bool> reservarNome(String nome, String uid) async {
    final slug = idDoNome(nome);
    if (slug == null) return false;
    final ref = _nomesRef.doc(slug);
    try {
      await ref.set({
        'uid': uid,
        'nome': sanitizarLinhaUnica(nome.trim()),
        'criadoEm': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // Slug já reservado. Só é sucesso se a reserva existente já for desta
      // conta — caso de cadastro interrompido e retomado.
      final atual = await ref.get();
      return atual.exists && atual.data()?['uid'] == uid;
    }
  }

  /// Libera a reserva de [nome] se ela pertencer a [uid]. Best-effort: não
  /// falha quando a reserva não existe ou é de outra conta.
  Future<void> liberarNome(String nome, String uid) async {
    final slug = idDoNome(nome);
    if (slug == null) return;
    final ref = _nomesRef.doc(slug);
    final doc = await ref.get();
    if (doc.exists && doc.data()?['uid'] == uid) await ref.delete();
  }

  /// Move a reserva de [nomeAntigo] para [nomeNovo] ao renomear o perfil.
  /// Retorna false, sem alterar nada, se o nome novo já for de outra conta.
  ///
  /// Reserva antes de liberar: se a ordem fosse inversa e a reserva falhasse,
  /// o usuário ficaria sem nenhum nome reservado e outra conta poderia tomar
  /// o que ele ainda usa.
  Future<bool> trocarNome({
    required String uid,
    required String nomeAntigo,
    required String nomeNovo,
  }) async {
    final slugNovo = idDoNome(nomeNovo);
    if (slugNovo == null) return false;
    if (idDoNome(nomeAntigo) == slugNovo) return true;
    if (!await reservarNome(nomeNovo, uid)) return false;
    await liberarNome(nomeAntigo, uid);
    return true;
  }
}

/// Acumula exclusões e faz commit em blocos de [UsuarioService._maxOpsPorLote].
///
/// O WriteBatch do Firestore rejeita mais de 500 escritas por commit, e um
/// usuário ativo passa desse número só em notificações — a versão anterior
/// desta exclusão usava um único batch e falhava de forma determinística para
/// esses usuários.
class _LotesDeExclusao {
  _LotesDeExclusao(this._db);

  final FirebaseFirestore _db;
  final List<DocumentReference<Object?>> _refs = [];

  void deletar(DocumentReference<Object?> ref) => _refs.add(ref);

  /// Aplica as exclusões acumuladas, um lote por vez e em ordem.
  Future<void> commit() async {
    const tamanho = UsuarioService._maxOpsPorLote;
    for (var inicio = 0; inicio < _refs.length; inicio += tamanho) {
      final fim = (inicio + tamanho).clamp(0, _refs.length);
      final lote = _db.batch();
      for (final ref in _refs.sublist(inicio, fim)) {
        lote.delete(ref);
      }
      await lote.commit();
    }
  }
}
