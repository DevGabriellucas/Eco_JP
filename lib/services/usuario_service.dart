import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/usuario_model.dart';
import '../utils/log_erros.dart';
import '../utils/texto.dart';

class UsuarioService {
  static final UsuarioService instance = UsuarioService();

  final CollectionReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('usuarios');

  // Índice de unicidade de nome de exibição: um documento por nome, tendo o
  // slug do nome como ID. Ver [nomeEmUso] para o motivo de existir.
  final CollectionReference<Map<String, dynamic>> _nomesRef =
      FirebaseFirestore.instance.collection('nomes_reservados');

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

  /// Garante que a conta [uid] tenha perfil em `usuarios/{uid}` com nome
  /// reservado, criando-o se faltar. Devolve o perfil.
  ///
  /// O login Google não passa pelo cadastro, então antes não criava perfil
  /// nem reserva: a tela usava um perfil provisório com o prefixo do e-mail
  /// como nome, que virava público ao salvar a bio. Aqui o nome sai do
  /// [nomeSugerido] (displayName do Google) — nunca do e-mail — e ganha um
  /// sufixo numérico se já estiver reservado por outra conta.
  ///
  /// Se um cadastro anterior reservou o nome mas caiu antes de salvar o
  /// perfil, reaproveita essa reserva.
  Future<UsuarioModel> garantirPerfil(
    String uid, {
    String? nomeSugerido,
    String? fotoUrl,
  }) async {
    final existente = await carregarPerfil(uid);
    if (existente != null) return existente;

    final reservas =
        await _nomesRef.where('uid', isEqualTo: uid).limit(1).get();
    var nome = reservas.docs.isEmpty
        ? null
        : reservas.docs.first.data()['nome'] as String?;

    if (nome == null) {
      var base = sanitizarLinhaUnica(nomeSugerido ?? '');
      if (idDoNome(base) == null) base = 'Usuário';
      // Deixa espaço para o sufixo dentro do limite de 40 das regras.
      if (base.length > 34) base = base.substring(0, 34).trim();
      final candidatos = [
        base,
        for (var i = 2; i <= 9; i++) '$base $i',
        for (var i = 0; i < 5; i++)
          '$base ${1000 + DateTime.now().microsecondsSinceEpoch % 9000 + i}',
      ];
      for (final candidato in candidatos) {
        if (await reservarNome(candidato, uid)) {
          nome = candidato;
          break;
        }
      }
      if (nome == null) throw StateError('Nenhum nome disponível para $uid');
    }

    final perfil = UsuarioModel(uid: uid, nome: nome, fotoUrl: fotoUrl);
    await salvarPerfil(perfil);
    return perfil;
  }

  DocumentReference<Map<String, dynamic>> _conquistasNotificadasRef(
          String uid) =>
      _ref.doc(uid).collection('meta').doc('conquistasNotificadas');

  /// Títulos das conquistas que já geraram notificação para [uid].
  Future<Set<String>> conquistasNotificadas(String uid) async {
    final doc = await _conquistasNotificadasRef(uid).get();
    return Set<String>.from(doc.data()?['items'] ?? const []);
  }

  Future<void> salvarConquistasNotificadas(
    String uid,
    Iterable<String> titulos,
  ) {
    return _conquistasNotificadasRef(uid).set({'items': titulos.toList()});
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

  /// Nome exibido nos comentários de contas excluídas.
  static const String nomeAnonimizado = 'Usuário removido';

  /// Denúncias anônimas por commit na exclusão de conta. Cada uma custa até
  /// 2 acessos a dono/info nas regras (exists + get em isOwner); 6 por lote
  /// fica em 12, abaixo do teto de 20 por requisição com folga.
  static const int _denunciasAnonimasPorLote = 6;

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
  /// Comentários feitos em denúncias de outras pessoas não são removidos, para
  /// não quebrar as conversas: nome e foto viram [nomeAnonimizado] e null
  /// (anonimização, LGPD art. 18, IV), como declara a Política de
  /// Privacidade, item 6.
  ///
  /// A exclusão NÃO é atômica: acima de 500 documentos ela é dividida em
  /// vários commits. Se um lote falhar, os anteriores já foram aplicados — uma
  /// exclusão parcial é preferível a nenhuma, e o chamador reporta a falha.
  Future<void> excluirTodosDados(String uid) async {
    final db = FirebaseFirestore.instance;
    final lotes = _LotesDeExclusao(db);
    // Cada exclusão de denúncia anônima faz as regras lerem dono/info
    // (isOwner), e um commit aceita no máximo 20 exists()/get(). Num lote
    // único, quem tinha 21+ anônimas nunca conseguia excluir a conta.
    final lotesAnonimas = _LotesDeExclusao(
      db,
      tamanho: _denunciasAnonimasPorLote * 3,
    );

    // 0. Comentários em qualquer denúncia: anonimizados, não apagados. O
    //    valor exato é exigido pelas Rules (isAnonimizacaoDoAutor).
    final comentarios = await db
        .collectionGroup('comentarios')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in comentarios.docs) {
      lotes.atualizar(doc.reference, {
        'userName': nomeAnonimizado,
        'userPhotoUrl': null,
      });
    }

    // 1. Denúncias anônimas. O documento público NÃO guarda usuarioId (ver
    //    OcorrenciaRepository.cadastrarOcorrencia), então a query do passo 2
    //    não as encontra. Só os ponteiros do próprio perfil sabem quais são —
    //    sem este passo, as denúncias anônimas sobreviveriam à exclusão.
    final ponteiros =
        await _ref.doc(uid).collection('minhas_denuncias_anonimas').get();
    for (final ponteiro in ponteiros.docs) {
      final ocorrencia = db.collection('ocorrencias').doc(ponteiro.id);
      // As Rules avaliam get() contra o estado já commitado, então apagar a
      // ocorrência e o dono/info que comprova a titularidade no mesmo lote é
      // seguro: isOwner() ainda enxerga dono/info na hora da avaliação.
      // As três exclusões de uma denúncia ficam sempre no mesmo lote
      // (o tamanho do lote é múltiplo de 3).
      lotesAnonimas.deletar(ocorrencia);
      lotesAnonimas.deletar(ocorrencia.collection('dono').doc('info'));
      lotesAnonimas.deletar(ponteiro.reference);
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
    final notifs =
        await db.collection('notificacoes').doc(uid).collection('items').get();
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
    //    por uma conta que não existe mais. Só entra no lote se existir e for
    //    desta conta: contas criadas antes de nomes_reservados não têm
    //    reserva, e a regra nega apagar a de outra conta — num delete negado
    //    o lote inteiro (com perfil e consentimento) falhava. O delete em si
    //    vai no passo 7, depois do perfil.
    final perfil = await _ref.doc(uid).get();
    final nome = perfil.data()?['nome'] as String?;
    final slug = nome == null ? null : idDoNome(nome);
    DocumentReference<Map<String, dynamic>>? reservaDoNome;
    if (slug != null) {
      final reserva = await _nomesRef.doc(slug).get();
      if (reserva.exists && reserva.data()?['uid'] == uid) {
        reservaDoNome = reserva.reference;
      }
    }

    // 6. Registros de compartilhamento (um por denúncia compartilhada).
    final compartilhamentos = await db
        .collectionGroup('compartilhamentos')
        .where('uid', isEqualTo: uid)
        .get();
    for (final doc in compartilhamentos.docs) {
      lotes.deletar(doc.reference);
    }

    // 7. Estado privado (conquistas já notificadas, id da sessão ativa),
    //    consentimento e perfil por último: nada mais depende deles.
    final meta = _ref.doc(uid).collection('meta');
    lotes.deletar(meta.doc('conquistasNotificadas'));
    lotes.deletar(meta.doc('sessao'));
    lotes.deletar(db.collection('consentimentos').doc(uid));
    lotes.deletar(_ref.doc(uid));
    // Carimbos de limite e reserva do nome DEPOIS do perfil: as Rules só
    // deixam apagá-los quando o perfil não existe mais (no mesmo lote ou num
    // anterior).
    lotes.deletar(meta.doc('reacao'));
    lotes.deletar(meta.doc('denuncia'));
    if (reservaDoNome != null) lotes.deletar(reservaDoNome);

    await lotesAnonimas.commit();
    await lotes.commit();
  }

  /// ID do nome no índice de unicidade, ou null quando [nome] não tem nenhuma
  /// letra ou dígito — aí não existe identificador estável e o nome é recusado.
  ///
  /// Usa [slugify], então a comparação ignora maiúsculas, acentos e pontuação:
  /// "José Silva", "jose silva" e "JOSE-SILVA" disputam o mesmo documento. Isso
  /// é intencional — em app de denúncia, dois perfis com nomes visualmente
  /// confundíveis são um vetor de personificação, não uma conveniência.
  ///
  /// O slug sai do nome já higienizado — o mesmo texto que salvarPerfil
  /// grava. Gerado do texto cru, um caractere invisível no meio ("Jo​ão")
  /// virava hífen no slug, escapava da reserva de "João Silva" e, depois da
  /// higienização, exibia um nome idêntico ao da outra conta.
  static String? idDoNome(String nome) {
    final slug = slugify(sanitizarLinhaUnica(nome));
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
}

/// Acumula exclusões e faz commit em blocos de [tamanho] (padrão
/// [UsuarioService._maxOpsPorLote]).
///
/// O WriteBatch do Firestore rejeita mais de 500 escritas por commit, e um
/// usuário ativo passa desse número só em notificações — a versão anterior
/// desta exclusão usava um único batch e falhava de forma determinística para
/// esses usuários.
class _LotesDeExclusao {
  _LotesDeExclusao(this._db, {this.tamanho = UsuarioService._maxOpsPorLote});

  final FirebaseFirestore _db;
  final int tamanho;
  final List<void Function(WriteBatch)> _ops = [];

  void deletar(DocumentReference<Object?> ref) =>
      _ops.add((lote) => lote.delete(ref));

  void atualizar(DocumentReference<Object?> ref, Map<String, Object?> dados) =>
      _ops.add((lote) => lote.update(ref, dados));

  /// Aplica as operações acumuladas, um lote por vez e em ordem.
  Future<void> commit() async {
    for (var inicio = 0; inicio < _ops.length; inicio += tamanho) {
      final fim = (inicio + tamanho).clamp(0, _ops.length);
      final lote = _db.batch();
      for (final op in _ops.sublist(inicio, fim)) {
        op(lote);
      }
      await lote.commit();
    }
  }
}
