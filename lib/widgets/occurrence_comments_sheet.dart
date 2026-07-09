import 'package:flutter/material.dart';

import '../models/comentario_model.dart';
import '../models/ocorrencia_model.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/moderacao_service.dart';
import '../services/notificacao_service.dart';
import '../services/ocorrencia_service.dart';
import '../services/usuario_service.dart';
import '../utils/tempo_relativo.dart';
import 'report_content_sheet.dart';

class OccurrenceCommentsSheet extends StatefulWidget {
  final OcorrenciaModel occurrence;
  final OcorrenciaService ocorrenciaService;
  final AuthService authService;
  final UsuarioService usuarioService;
  final NotificacaoService notificacaoService;

  const OccurrenceCommentsSheet({
    super.key,
    required this.occurrence,
    required this.ocorrenciaService,
    required this.authService,
    required this.usuarioService,
    required this.notificacaoService,
  });

  @override
  State<OccurrenceCommentsSheet> createState() =>
      _OccurrenceCommentsSheetState();
}

class _OccurrenceCommentsSheetState extends State<OccurrenceCommentsSheet> {
  static const _emojis = ['❤️', '👏', '🔥', '🙌', '😮', '😢', '👍', '🌱'];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ModeracaoService _moderacaoService = ModeracaoService();

  UsuarioModel? _perfilAtual;
  ComentarioModel? _replyTo;
  String? _replyParentId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _carregarPerfilAtual();
  }

  @override
  void dispose() {
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
      // Perfil ausente nao bloqueia comentario; usamos dados do Firebase Auth.
    }
  }

  Future<void> _send([String? forcedText]) async {
    if (_sending) return;
    final user = widget.authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre na sua conta para comentar.')),
      );
      return;
    }

    final text = (forcedText ?? _controller.text).trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    final nome = _displayName(user.displayName, user.email);
    final foto = _perfilAtual?.fotoUrl ?? user.photoURL;
    final parentId = _replyParentId ?? _replyTo?.id;

    try {
      await widget.ocorrenciaService.adicionarComentario(
        widget.occurrence.id,
        ComentarioModel(
          id: '',
          userId: user.uid,
          userName: nome,
          userPhotoUrl: foto,
          texto: text,
          parentId: parentId,
        ),
      );

      final dono = widget.occurrence.usuarioId;
      if (dono != null && dono != user.uid) {
        await widget.notificacaoService.notificar(
          donoId: dono,
          tipo: 'comentario',
          deUsuarioNome: nome,
          ocorrenciaId: widget.occurrence.id,
          ocorrenciaTitulo: widget.occurrence.titulo,
        );
      }

      if (!mounted) return;
      _controller.clear();
      setState(() {
        _replyTo = null;
        _replyParentId = null;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível comentar agora.')),
      );
    }
  }

  String _displayName(String? authName, String? email) {
    final perfilNome = _perfilAtual?.nome.trim();
    if (perfilNome != null && perfilNome.isNotEmpty) return perfilNome;
    final firebaseName = authName?.trim();
    if (firebaseName != null && firebaseName.isNotEmpty) return firebaseName;
    final userEmail = email?.trim();
    if (userEmail != null && userEmail.isNotEmpty) {
      return userEmail.split('@').first;
    }
    return 'Usuário';
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
      await widget.ocorrenciaService.toggleLikeComentario(
        widget.occurrence.id,
        comentario.id,
        user.uid,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível curtir agora.')),
      );
    }
  }

  Future<void> _editComment(ComentarioModel comentario) async {
    final controller = TextEditingController(text: comentario.texto);
    var saving = false;

    final updatedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Editar comentário',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escreva seu comentário',
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
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
                  backgroundColor: const Color(0xFF16A34A),
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
    controller.dispose();

    if (updatedText == null || updatedText == comentario.texto.trim()) return;

    try {
      await widget.ocorrenciaService.editarComentario(
        widget.occurrence.id,
        comentario.id,
        updatedText,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível editar o comentário.')),
      );
    }
  }

  Future<void> _deleteComment(ComentarioModel comentario) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir comentário',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: const Text('Tem certeza que deseja excluir este comentário?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
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
      await widget.ocorrenciaService.deletarComentario(
        widget.occurrence.id,
        comentario.id,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir o comentário.')),
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível denunciar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final user = widget.authService.currentUser;
    final currentName = _displayName(user?.displayName, user?.email);
    final currentPhoto = _perfilAtual?.fotoUrl ?? user?.photoURL;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: FractionallySizedBox(
        heightFactor: viewInsets > 0 ? 0.94 : 0.86,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Comentários',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Expanded(
                child: StreamBuilder<List<ComentarioModel>>(
                  stream: widget.ocorrenciaService.listarComentarios(
                    widget.occurrence.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    final comentarios = snapshot.data ?? const [];
                    if (comentarios.isEmpty) {
                      return const _EmptyComments();
                    }

                    final roots = comentarios
                        .where((c) => c.parentId == null)
                        .toList();
                    final repliesByParent = <String, List<ComentarioModel>>{};
                    for (final comentario in comentarios) {
                      final parentId = comentario.parentId;
                      if (parentId == null) continue;
                      repliesByParent
                          .putIfAbsent(parentId, () => <ComentarioModel>[])
                          .add(comentario);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      itemCount: roots.length,
                      itemBuilder: (context, index) {
                        final root = roots[index];
                        final replies =
                            repliesByParent[root.id] ??
                            const <ComentarioModel>[];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CommentTile(
                              comentario: root,
                              isOwn: root.userId == user?.uid,
                              onLike: () => _toggleLike(root),
                              onReply: () => _replyToComment(root),
                              onEdit: () => _editComment(root),
                              onDelete: () => _deleteComment(root),
                              onReport: () => _reportComment(root),
                            ),
                            for (final reply in replies)
                              Padding(
                                padding: const EdgeInsets.only(left: 42),
                                child: _CommentTile(
                                  comentario: reply,
                                  isOwn: reply.userId == user?.uid,
                                  compact: true,
                                  onLike: () => _toggleLike(reply),
                                  onReply: () => _replyToComment(
                                    reply,
                                    parentRootId: root.id,
                                  ),
                                  onEdit: () => _editComment(reply),
                                  onDelete: () => _deleteComment(reply),
                                  onReport: () => _reportComment(reply),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              if (_replyTo != null)
                _ReplyBanner(
                  name: _replyTo!.userName,
                  onCancel: () => setState(() {
                    _replyTo = null;
                    _replyParentId = null;
                  }),
                ),
              _EmojiBar(emojis: _emojis, onEmojiTap: _send),
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

  const _CommentTile({
    required this.comentario,
    required this.isOwn,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = comentario;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 14 : 18),
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
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 13,
                      color: const Color(0xFF111827),
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(
                        text: c.userName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(text: c.texto),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      tempoRelativo(c.dataCriacao),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onReply,
                      child: const Text(
                        'Responder',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (c.likes > 0) ...[
                      const SizedBox(width: 14),
                      Text(
                        '${c.likes} curtida${c.likes == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: c.userLiked ? 'Remover curtida' : 'Curtir comentário',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  c.userLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: c.userLiked
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF9CA3AF),
                ),
                onPressed: onLike,
              ),
              PopupMenuButton<_CommentOwnerAction>(
                tooltip: 'Opções do comentário',
                icon: const Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
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
            ],
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
    final color = danger ? const Color(0xFFEF4444) : const Color(0xFF111827);
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Respondendo a $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B7280),
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
        separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Comentar como $userName',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
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
                : const Icon(Icons.send, color: Color(0xFF16A34A), size: 22),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mode_comment_outlined,
              size: 52,
              color: Color(0xFFD1D5DB),
            ),
            SizedBox(height: 12),
            Text(
              'Nenhum comentário ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Seja a primeira pessoa a comentar esta denúncia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                height: 1.35,
              ),
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
      backgroundColor: const Color(0xFFE8F5E9),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: const Color(0xFF16A34A),
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
