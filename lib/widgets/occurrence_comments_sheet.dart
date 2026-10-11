import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories/comentario_repository.dart';
import '../models/comentario_model.dart';
import '../models/ocorrencia_model.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/moderacao_service.dart';
import '../services/notificacao_service.dart';
import '../services/rate_limiter.dart';
import '../services/role_service.dart';
import '../services/usuario_service.dart';
import '../utils/cloudinary_image.dart';
import '../utils/imagem_cacheada.dart';
import '../utils/mensagem_erro.dart';
import '../utils/tempo_relativo.dart';
import 'report_content_sheet.dart';
import '../theme/app_theme.dart';

class OccurrenceCommentsSheet extends StatefulWidget {
  final OcorrenciaModel occurrence;
  final ComentarioRepository comentarioRepository;
  final AuthService authService;
  final UsuarioService usuarioService;
  final NotificacaoService notificacaoService;
  final String? comentarioIdEmFoco;

  const OccurrenceCommentsSheet({
    super.key,
    required this.occurrence,
    required this.comentarioRepository,
    required this.authService,
    required this.usuarioService,
    required this.notificacaoService,
    this.comentarioIdEmFoco,
  });

  @override
  State<OccurrenceCommentsSheet> createState() =>
      _OccurrenceCommentsSheetState();
}

class _OccurrenceCommentsSheetState extends State<OccurrenceCommentsSheet> {
  static const _emojis = [
    '❤️',
    '👍',
    '👏',
    '🔥',
    '🙌',
    '😮',
    '😢',
    '😡',
    '🤔',
    '🌱',
    '🌍',
    '🚀',
  ];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ModeracaoService _moderacaoService = ModeracaoService();

  UsuarioModel? _perfilAtual;
  ComentarioModel? _replyTo;
  String? _replyParentId;
  bool _sending = false;
  // Usuário logado é autoridade/órgão: o comentário sai com o selo.
  bool _ehAutoridade = false;
  // Comentário em foco (vindo da fila de moderação): destaque por alguns segundos.
  String? _comentarioEmFoco;
  bool _mostraDestaque = false;
  Timer? _focoTimer;
  // Autor de denúncia anônima comentando nela: avisa uma vez por sessão do
  // painel que o comentário mostra nome e foto (revelaria a autoria).
  bool _souAutorAnonimo = false;
  bool _avisoAnonimoAceito = false;

  // Criada uma vez: uma stream nova a cada build fazia o StreamBuilder voltar
  // a "waiting" e a lista pular para o topo a cada interação.
  late final Stream<List<ComentarioModel>> _comentariosStream =
      widget.comentarioRepository.listarComentarios(widget.occurrence.id);

  @override
  void initState() {
    super.initState();
    _carregarPerfilAtual();
    _carregarPapel();
    if (widget.occurrence.anonima) {
      widget.comentarioRepository
          .souAutorDaDenunciaAnonima(widget.occurrence.id)
          .then((sou) {
        if (mounted) setState(() => _souAutorAnonimo = sou);
      });
    }
    // Com comentário em foco, liga o destaque.
    if (widget.comentarioIdEmFoco != null) {
      _comentarioEmFoco = widget.comentarioIdEmFoco;
      _mostraDestaque = true;
      _focoTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _mostraDestaque = false);
      });
    }
  }

  Future<void> _carregarPapel() async {
    final user = widget.authService.currentUser;
    if (user == null) return;
    try {
      final ehAutoridade = await RoleService.instance.isAutoridade(user.uid);
      if (!mounted) return;
      setState(() => _ehAutoridade = ehAutoridade);
    } catch (_) {
      // Sem papel confirmado → comentário comum (sem selo).
    }
  }

  @override
  void dispose() {
    _focoTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _carregarPerfilAtual() async {
    final user = widget.authService.currentUser;
    if (user == null) return;
    try {
      final perfil = await widget.usuarioService.carregarPerfil(user.uid);
      if (!mounted) return;
      setState(() => _perfilAtual = perfil);
    } catch (_) {
      // Perfil ausente não bloqueia: o envio recarrega e avisa se faltar.
    }
  }

  /// Coloca o emoji no ponto do cursor em vez de enviá-lo: antes cada toque
  /// na barra publicava um comentário só com o emoji.
  void _inserirEmoji(String emoji) {
    final valor = _controller.value;
    final texto = valor.text;
    final sel = valor.selection;
    final inicio = sel.isValid ? sel.start : texto.length;
    final fim = sel.isValid ? sel.end : texto.length;
    _controller.value = TextEditingValue(
      text: texto.replaceRange(inicio, fim, emoji),
      selection: TextSelection.collapsed(offset: inicio + emoji.length),
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    final user = widget.authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre na sua conta para comentar.')),
      );
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_souAutorAnonimo && !_avisoAnonimoAceito) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sua denúncia é anônima'),
          content: const Text(
            'Comentários mostram seu nome e sua foto. Ao comentar aqui, as '
            'outras pessoas vão saber que você é o autor desta denúncia.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Comentar mesmo assim'),
            ),
          ],
        ),
      );
      if (continuar != true || !mounted) return;
      _avisoAnonimoAceito = true;
    }

    setState(() => _sending = true);

    // As regras exigem que o nome do comentário seja o `nome` do perfil
    // (usuarios/{uid}); sem perfil carregado não há nome válido para usar.
    if (_perfilAtual == null) await _carregarPerfilAtual();
    if (!mounted) return;
    final nome = _perfilAtual?.nome ?? '';
    if (nome.trim().isEmpty) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Não foi possível carregar seu perfil. Tente novamente.'),
        ),
      );
      return;
    }
    final foto = fotoPublicaPermitida(_perfilAtual?.fotoUrl ?? user.photoURL);
    final parentId = _replyParentId ?? _replyTo?.id;

    try {
      final comentarioId =
          await widget.comentarioRepository.adicionarComentario(
        widget.occurrence.id,
        ComentarioModel(
          id: '',
          userId: user.uid,
          userName: nome,
          userPhotoUrl: foto,
          texto: text,
          parentId: parentId,
          autorAutoridade: _ehAutoridade,
        ),
      );

      // Denúncia anônima nunca notifica o dono: o UID real não chega a quem
      // comenta, o que impede correlacionar denúncias do mesmo autor.
      final dono = widget.occurrence.usuarioId;
      if (!widget.occurrence.anonima && dono != null && dono != user.uid) {
        await widget.notificacaoService.notificar(
          donoId: dono,
          tipo: 'comentario',
          deUsuarioNome: nome,
          ocorrenciaId: widget.occurrence.id,
          ocorrenciaTitulo: widget.occurrence.titulo,
          notifId: NotificacaoService.idComentario(comentarioId),
        );
      }

      if (!mounted) return;
      _controller.clear();
      setState(() {
        _replyTo = null;
        _replyParentId = null;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final msg = e is RateLimitException
          ? 'Aguarde ${e.segundosRestantes}s para comentar de novo.'
          : 'Não foi possível comentar agora.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _replyToComment(ComentarioModel comentario, {String? parentRootId}) {
    setState(() {
      _replyTo = comentario;
      _replyParentId = parentRootId ?? comentario.id;
    });
    _focusNode.requestFocus();
  }

  Future<void> _toggleLike(ComentarioModel comentario) async {
    final user = widget.authService.currentUser;
    if (user == null) return;
    try {
      await widget.comentarioRepository.toggleLikeComentario(
        widget.occurrence.id,
        comentario.id,
        user.uid,
        ehAutoridade: _ehAutoridade,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível curtir agora.')),
      );
    }
  }

  Future<void> _editComment(ComentarioModel comentario) async {
    final pal = context.pal;
    final controller = TextEditingController(text: comentario.texto);
    var saving = false;

    final updatedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: pal.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Editar comentário',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: pal.ink,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: pal.ink),
              decoration: InputDecoration(
                hintText: 'Escreva seu comentário',
                hintStyle: TextStyle(color: pal.hint),
                filled: true,
                fillColor: pal.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        setDialogState(() => saving = true);
                        Navigator.pop(dialogContext, text);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successStrong,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );
    // O TextField ainda é reconstruído durante a animação de saída do
    // diálogo; descartar na hora gerava "used after being disposed".
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);

    if (updatedText == null || updatedText == comentario.texto.trim()) return;

    try {
      await widget.comentarioRepository.editarComentario(
        widget.occurrence.id,
        comentario.id,
        updatedText,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro(e, acao: 'editar o comentário'))),
      );
    }
  }

  Future<void> _deleteComment(ComentarioModel comentario) async {
    final pal = context.pal;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir comentário',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: pal.ink,
          ),
        ),
        content: Text(
          'Tem certeza que deseja excluir este comentário?',
          style: TextStyle(color: pal.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.comentarioRepository.deletarComentario(
        widget.occurrence.id,
        comentario.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro(e, acao: 'excluir o comentário'))),
      );
    }
  }

  Future<void> _reportComment(ComentarioModel comentario) async {
    final user = widget.authService.currentUser;
    if (user == null) return;
    final result = await showReportContentSheet(
      context,
      title: 'Denunciar comentário',
    );
    if (result == null) return;

    try {
      await _moderacaoService.denunciarComentario(
        ocorrenciaId: widget.occurrence.id,
        comentarioId: comentario.id,
        denuncianteId: user.uid,
        motivo: result.motivo,
        detalhe: result.detalhe,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comentário enviado para moderação.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(mensagemErro(e, acao: 'denunciar o comentário'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final user = widget.authService.currentUser;
    // Só para o avatar do campo de digitação; o nome gravado vem do perfil.
    final nomePerfil = _perfilAtual?.nome.trim() ?? '';
    final currentName = nomePerfil.isNotEmpty ? nomePerfil : 'Você';
    final currentPhoto = _perfilAtual?.fotoUrl ?? user?.photoURL;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: FractionallySizedBox(
        heightFactor: viewInsets > 0 ? 0.94 : 0.86,
        child: Container(
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          // Material transparente sobre a cor do painel: sem ele o efeito de
          // toque (ripple) era desenhado no Material de trás e ficava escondido.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pal.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Comentários',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: pal.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        icon: Icon(Icons.close, size: 22, color: pal.ink),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: pal.border),
                Expanded(
                  child: StreamBuilder<List<ComentarioModel>>(
                    stream: _comentariosStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData &&
                          snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      // Comentários ocultados pela autoridade (moderação) não
                      // aparecem para o público.
                      final comentarios = (snapshot.data ?? const [])
                          .where((c) => !c.oculto)
                          .toList();
                      if (comentarios.isEmpty) {
                        return const _EmptyComments();
                      }

                      final roots =
                          comentarios.where((c) => c.parentId == null).toList();
                      final repliesByParent = <String, List<ComentarioModel>>{};
                      for (final comentario in comentarios) {
                        final parentId = comentario.parentId;
                        if (parentId == null) continue;
                        repliesByParent
                            .putIfAbsent(parentId, () => <ComentarioModel>[])
                            .add(comentario);
                      }

                      // Respostas de outras pessoas sobrevivem quando o autor
                      // exclui o comentário raiz (cada um só apaga o que é
                      // seu). Elas aparecem sob um marcador "Comentário
                      // removido" em vez de sumir.
                      final idsRaiz = {for (final r in roots) r.id};
                      final raizesRemovidas = repliesByParent.keys
                          .where((id) => !idsRaiz.contains(id))
                          .toList();

                      Widget tile(
                        ComentarioModel c, {
                        required String raizId,
                        bool resposta = false,
                      }) =>
                          _CommentTile(
                            comentario: c,
                            isOwn: c.userId == user?.uid,
                            isEmFoco:
                                _comentarioEmFoco == c.id && _mostraDestaque,
                            compact: resposta,
                            onLike: () => _toggleLike(c),
                            onReply: () => _replyToComment(
                              c,
                              parentRootId: resposta ? raizId : null,
                            ),
                            onEdit: () => _editComment(c),
                            onDelete: () => _deleteComment(c),
                            onReport: () => _reportComment(c),
                          );

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        itemCount: roots.length + raizesRemovidas.length,
                        itemBuilder: (context, index) {
                          if (index >= roots.length) {
                            final idRemovido =
                                raizesRemovidas[index - roots.length];
                            return _ThreadRaizRemovida(
                              key: ValueKey('removida_$idRemovido'),
                              respostas: repliesByParent[idRemovido]!,
                              construirResposta: (reply) => tile(
                                reply,
                                raizId: idRemovido,
                                resposta: true,
                              ),
                            );
                          }
                          final root = roots[index];
                          final replies = repliesByParent[root.id] ??
                              const <ComentarioModel>[];
                          return _FioComentario(
                            key: ValueKey(root.id),
                            raiz: tile(root, raizId: root.id),
                            respostas: [
                              for (final reply in replies)
                                tile(reply, raizId: root.id, resposta: true),
                            ],
                            // Resposta em foco (fila de moderação) já abre o
                            // fio; antes ela ficava escondida.
                            expandidoInicial: _comentarioEmFoco != null &&
                                replies.any((r) => r.id == _comentarioEmFoco),
                          );
                        },
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: pal.border),
                if (_replyTo != null)
                  _ReplyBanner(
                    name: _replyTo!.userName,
                    onCancel: () => setState(() {
                      _replyTo = null;
                      _replyParentId = null;
                    }),
                  ),
                _EmojiBar(emojis: _emojis, onEmojiTap: _inserirEmoji),
                _CommentComposer(
                  controller: _controller,
                  focusNode: _focusNode,
                  sending: _sending,
                  userName: currentName,
                  userPhotoUrl: currentPhoto,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final ComentarioModel comentario;
  final bool isOwn;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final bool compact;
  final bool isEmFoco;

  const _CommentTile({
    required this.comentario,
    required this.isOwn,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    this.compact = false,
    this.isEmFoco = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = comentario;
    return Container(
      decoration: isEmFoco
          ? BoxDecoration(
              border: Border.all(
                color: pal.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: isEmFoco ? const EdgeInsets.all(8) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserAvatar(
            name: c.userName,
            photoUrl: c.userPhotoUrl,
            radius: compact ? 14 : 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho: nome + selo + tempo + (❤️ pela autoridade).
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: c.userName),
                            if (c.autorAutoridade)
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 3),
                                  child: Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12.5 : 13,
                          color: pal.ink,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tempoRelativo(c.dataCriacao),
                      style: TextStyle(
                        fontSize: 11,
                        color: pal.hint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // ❤️ pela autoridade: visível a todos quando uma conta de
                    // autoridade curtiu.
                    if (c.curtidoPorAutoridade) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.favorite,
                        size: 12,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'pela autoridade',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                // Texto + coração. O coração tem largura fixa e o número de
                // curtidas fica na linha de baixo: antes o número aparecia ao
                // lado do coração ao curtir, roubava largura do texto e o
                // comentário quebrava as linhas de outro jeito.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          c.texto,
                          style: TextStyle(
                            fontSize: compact ? 12.5 : 13,
                            color: pal.ink,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: c.userLiked
                          ? 'Descurtir comentário'
                          : 'Curtir comentário',
                      onPressed: onLike,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        c.userLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: c.userLiked ? AppColors.danger : pal.hint,
                      ),
                    ),
                  ],
                ),
                // Ações: curtidas + responder + menu.
                Row(
                  children: [
                    if (c.likes > 0) ...[
                      Text(
                        c.likes == 1 ? '1 curtida' : '${c.likes} curtidas',
                        style: TextStyle(
                          fontSize: 11,
                          color: pal.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Semantics(
                      button: true,
                      label: 'Responder comentário',
                      child: InkWell(
                        onTap: onReply,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Responder',
                            style: TextStyle(
                              fontSize: 11,
                              color: pal.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 48 dp: com 24×24 o menu "…" era difícil de acertar.
                    SizedBox(
                      width: 48,
                      height: 40,
                      child: PopupMenuButton<_CommentOwnerAction>(
                        tooltip: 'Opções do comentário',
                        icon: Icon(Icons.more_horiz, size: 16, color: pal.hint),
                        padding: EdgeInsets.zero,
                        onSelected: (action) {
                          switch (action) {
                            case _CommentOwnerAction.edit:
                              onEdit();
                              break;
                            case _CommentOwnerAction.delete:
                              onDelete();
                              break;
                            case _CommentOwnerAction.report:
                              onReport();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (isOwn) ...const [
                            PopupMenuItem(
                              value: _CommentOwnerAction.edit,
                              child: _CommentMenuItem(
                                icon: Icons.edit_outlined,
                                label: 'Editar',
                              ),
                            ),
                            PopupMenuItem(
                              value: _CommentOwnerAction.delete,
                              child: _CommentMenuItem(
                                icon: Icons.delete_outline,
                                label: 'Excluir',
                                danger: true,
                              ),
                            ),
                          ],
                          if (!isOwn)
                            const PopupMenuItem(
                              value: _CommentOwnerAction.report,
                              child: _CommentMenuItem(
                                icon: Icons.flag_outlined,
                                label: 'Denunciar',
                                danger: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Comentário raiz com as respostas. O aberto/fechado das respostas é estado
/// deste fio: antes ficava no painel, e cada toque em "Ver respostas"
/// reconstruía a lista inteira de comentários.
class _FioComentario extends StatefulWidget {
  const _FioComentario({
    super.key,
    required this.raiz,
    required this.respostas,
    this.expandidoInicial = false,
  });

  final Widget raiz;
  final List<Widget> respostas;
  final bool expandidoInicial;

  @override
  State<_FioComentario> createState() => _FioComentarioState();
}

class _FioComentarioState extends State<_FioComentario> {
  late bool _expandido = widget.expandidoInicial;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final total = widget.respostas.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.raiz,
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: InkWell(
                onTap: () => setState(() => _expandido = !_expandido),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 24, height: 1, color: pal.border),
                      const SizedBox(width: 8),
                      Text(
                        _expandido
                            ? 'Ocultar respostas'
                            : (total == 1
                                ? 'Ver 1 resposta'
                                : 'Ver $total respostas'),
                        style: TextStyle(
                          fontSize: 11,
                          color: pal.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_expandido)
            for (final resposta in widget.respostas)
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 4),
                child: resposta,
              ),
        ],
      ),
    );
  }
}

enum _CommentOwnerAction { edit, delete, report }

class _CommentMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _CommentMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : context.pal.ink;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  final String name;
  final VoidCallback onCancel;

  const _ReplyBanner({required this.name, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      color: pal.surfaceAlt,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Respondendo a $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: pal.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cancelar resposta',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _EmojiBar extends StatelessWidget {
  final List<String> emojis;
  final ValueChanged<String> onEmojiTap;

  const _EmojiBar({required this.emojis, required this.onEmojiTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: emojis.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final emoji = emojis[index];
          return InkResponse(
            onTap: () => onEmojiTap(emoji),
            radius: 22,
            child: SizedBox(
              width: 28,
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final String userName;
  final String? userPhotoUrl;
  final VoidCallback onSend;

  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.userName,
    required this.userPhotoUrl,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _UserAvatar(
              name: userName,
              photoUrl: userPhotoUrl,
              radius: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42, maxHeight: 110),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: pal.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: pal.border),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: pal.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Comentar como $userName',
                  hintStyle: TextStyle(color: pal.hint, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Enviar comentário',
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send,
                    color: AppColors.successStrong, size: 22),
            onPressed: sending ? null : onSend,
          ),
        ],
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mode_comment_outlined, size: 52, color: pal.hint),
            const SizedBox(height: 12),
            Text(
              'Nenhum comentário ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: pal.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Seja a primeira pessoa a comentar esta denúncia.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: pal.hint, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;

  const _UserAvatar({
    required this.name,
    required this.photoUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.14),
      backgroundImage: hasPhoto ? imagemCacheada(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: AppColors.successStrong,
                fontSize: radius * 0.72,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

/// Fio cujo comentário raiz foi excluído pelo autor: mostra um marcador no
/// lugar da raiz e mantém as respostas das outras pessoas visíveis.
class _ThreadRaizRemovida extends StatelessWidget {
  const _ThreadRaizRemovida({
    super.key,
    required this.respostas,
    required this.construirResposta,
  });

  final List<ComentarioModel> respostas;
  final Widget Function(ComentarioModel) construirResposta;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Comentário removido',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: pal.hint,
            ),
          ),
        ),
        for (final reply in respostas)
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: construirResposta(reply),
          ),
      ],
    );
  }
}
