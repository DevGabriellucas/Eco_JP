import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/comentario_model.dart';
import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';
import '../services/ocorrencia_service.dart';
import '../services/usuario_service.dart';
import '../models/occurrence_types.dart';

// ─────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────

class _C {
  static const bg = Color(0xFFF2F2F2);
  static const white = Colors.white;
  static const border = Color(0xFFD8D8D8);
  static const text = Color(0xFF1A1A1A);
  static const hint = Color(0xFF8A8A8A);
  static const orange = Color(0xFFFF8A1F);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
}

// ─────────────────────────────────────────
//  DETALHE OCORRÊNCIA PAGE
// ─────────────────────────────────────────

class DetalheOcorrenciaPage extends StatefulWidget {
  final OcorrenciaModel occurrence;

  const DetalheOcorrenciaPage({super.key, required this.occurrence});

  @override
  State<DetalheOcorrenciaPage> createState() => _DetalheOcorrenciaPageState();
}

class _DetalheOcorrenciaPageState extends State<DetalheOcorrenciaPage> {
  final _authService = AuthService();
  final _service = OcorrenciaService();
  final _usuarioService = UsuarioService();
  final _notificacaoService = NotificacaoService();

  late int _likes;
  late int _dislikes;
  late bool _userLiked;
  late bool _userDisliked;
  late List<String> _likedBy;
  late List<String> _dislikedBy;
  String? _authorName;
  String? _authorPhoto;

  @override
  void initState() {
    super.initState();
    final o = widget.occurrence;
    _likes = o.likes;
    _dislikes = o.dislikes;
    _userLiked = o.userLiked;
    _userDisliked = o.userDisliked;
    _likedBy = List<String>.from(o.likedBy);
    _dislikedBy = List<String>.from(o.dislikedBy);
    _fetchAuthorData();
  }

  Future<void> _fetchAuthorData() async {
    final o = widget.occurrence;

    final hasSavedName =
        o.usuarioNome != null && o.usuarioNome!.trim().isNotEmpty;
    final hasSavedPhoto =
        o.usuarioFotoUrl != null && o.usuarioFotoUrl!.isNotEmpty;

    if (hasSavedName && hasSavedPhoto) {
      setState(() {
        _authorName = o.usuarioNome;
        _authorPhoto = o.usuarioFotoUrl;
      });
      return;
    }

    if (o.usuarioId == null) {
      if (hasSavedName) setState(() => _authorName = o.usuarioNome);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(o.usuarioId)
        .get();

    if (!mounted) return;

    final data = doc.data();
    final nome = (data?['nome'] as String?)?.trim();
    final foto = data?['fotoUrl'] as String?;

    String? resolvedName;
    if (hasSavedName) {
      resolvedName = o.usuarioNome;
    } else if (nome != null && nome.isNotEmpty) {
      resolvedName = nome;
    } else if (o.usuarioId == _authService.currentUser?.uid) {
      final email = _authService.currentUser?.email;
      resolvedName = email != null ? email.split('@').first : 'Usuário';
    } else {
      resolvedName = 'Usuário';
    }

    setState(() {
      _authorName = resolvedName;
      _authorPhoto = hasSavedPhoto
          ? o.usuarioFotoUrl
          : (foto?.isNotEmpty == true ? foto : null);
    });
  }

  String get _uid => _authService.currentUser?.uid ?? '';

  void _handleLike() {
    if (_uid.isEmpty) return;
    final vaiCurtir = !_userLiked;
    setState(() {
      if (_userLiked) {
        _userLiked = false;
        _likes--;
        _likedBy.remove(_uid);
      } else {
        if (_userDisliked) {
          _userDisliked = false;
          _dislikes--;
          _dislikedBy.remove(_uid);
        }
        _userLiked = true;
        _likes++;
        _likedBy.add(_uid);
      }
    });
    _service.toggleLike(widget.occurrence.id, _uid);
    if (vaiCurtir) _notificarCurtida();
  }

  void _notificarCurtida() {
    final dono = widget.occurrence.usuarioId;
    final eu = _authService.currentUser;
    if (dono == null || eu == null || dono == eu.uid) return;
    final nome = eu.displayName ?? eu.email?.split('@').first ?? 'Alguém';
    _notificacaoService.notificar(
      donoId: dono,
      tipo: 'curtida',
      deUsuarioNome: nome,
      ocorrenciaId: widget.occurrence.id,
      ocorrenciaTitulo: widget.occurrence.titulo,
    );
  }

  void _handleDislike() {
    if (_uid.isEmpty) return;
    setState(() {
      if (_userDisliked) {
        _userDisliked = false;
        _dislikes--;
        _dislikedBy.remove(_uid);
      } else {
        if (_userLiked) {
          _userLiked = false;
          _likes--;
          _likedBy.remove(_uid);
        }
        _userDisliked = true;
        _dislikes++;
        _dislikedBy.add(_uid);
      }
    });
    _service.toggleDislike(widget.occurrence.id, _uid);
  }

  void _openCommentSheet() {
    final authUser = _authService.currentUser;
    if (authUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentInputSheet(
        onSubmit: (text) async {
          final perfil = await _usuarioService.carregarPerfil(authUser.uid);
          final nome = perfil?.nome.trim().isNotEmpty == true
              ? perfil!.nome
              : (authUser.displayName ?? 'Usuário');
          final foto = perfil?.fotoUrl ?? authUser.photoURL;

          final comentario = ComentarioModel(
            id: '',
            userId: authUser.uid,
            userName: nome,
            userPhotoUrl: foto,
            texto: text,
          );
          await _service.adicionarComentario(widget.occurrence.id, comentario);
          // Notifica o dono da denúncia (se não for o próprio autor).
          final dono = widget.occurrence.usuarioId;
          if (dono != null && dono != authUser.uid) {
            await _notificacaoService.notificar(
              donoId: dono,
              tipo: 'comentario',
              deUsuarioNome: nome,
              ocorrenciaId: widget.occurrence.id,
              ocorrenciaTitulo: widget.occurrence.titulo,
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteComment(ComentarioModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir comentário'),
        content: const Text('Tem certeza que deseja excluir este comentário?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _C.hint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.red,
              foregroundColor: _C.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deletarComentario(widget.occurrence.id, c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.occurrence;
    final typeEnum = OccurrenceTypeParser.fromString(o.tipoLixo);
    final statusEnum = OccurrenceStatusParser.fromString(o.status);

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header
            _buildHeader(o, statusEnum),

            // ── Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Área da imagem com badge de tipo
                    Stack(
                      children: [
                        _ImageArea(occurrence: o, type: typeEnum),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _TypeBadge(type: typeEnum),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Título
                          _FieldCard(
                            child: Text(
                              o.titulo.isEmpty ? 'Sem título' : o.titulo,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _C.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Descrição
                          _FieldCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Descrição',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _C.hint,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  o.descricao.isEmpty
                                      ? 'Sem descrição'
                                      : o.descricao,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF374151),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botões de ação
                          Row(
                            children: [
                              _ReactionChip(
                                icon: _userLiked
                                    ? Icons.thumb_up_alt
                                    : Icons.thumb_up_alt_outlined,
                                count: _likes,
                                active: _userLiked,
                                activeColor: _C.green,
                                onTap: _handleLike,
                              ),
                              const SizedBox(width: 8),
                              _ReactionChip(
                                icon: _userDisliked
                                    ? Icons.thumb_down_alt
                                    : Icons.thumb_down_alt_outlined,
                                count: _dislikes,
                                active: _userDisliked,
                                activeColor: _C.red,
                                onTap: _handleDislike,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _AddCommentButton(
                                  onTap: _openCommentSheet,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Seção de acompanhamento (linha do tempo de status)
                          const Text(
                            'Acompanhamento',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _C.text,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _StatusTimeline(occurrence: o, service: _service),
                          const SizedBox(height: 28),

                          // Seção de comentários
                          const Text(
                            'Comentários',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _C.text,
                            ),
                          ),
                          const SizedBox(height: 16),

                          StreamBuilder<List<ComentarioModel>>(
                            stream: _service.listarComentarios(o.id),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              final comentarios = snap.data ?? [];
                              if (comentarios.isEmpty) {
                                return const _EmptyComments();
                              }
                              return Column(
                                children: comentarios
                                    .map(
                                      (c) => _CommentItem(
                                        comentario: c,
                                        isOwn: c.userId == _uid,
                                        onDelete: () => _deleteComment(c),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(OcorrenciaModel o, OccurrenceStatus statusEnum) {
    final authorLabel = _authorName ?? 'Usuário';

    return Container(
      color: _C.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _C.text),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      authorLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _C.text,
                      ),
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE8F5E9),
                  backgroundImage: _authorPhoto != null
                      ? NetworkImage(_authorPhoto!) as ImageProvider
                      : null,
                  child: _authorPhoto == null
                      ? Text(
                          (_authorName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: _C.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    o.localizacao.isEmpty
                        ? 'Localização não informada'
                        : o.localizacao,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _C.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: statusEnum),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ÁREA DE IMAGEM
// ─────────────────────────────────────────

class _ImageArea extends StatefulWidget {
  final OcorrenciaModel occurrence;
  final OccurrenceType type;

  const _ImageArea({required this.occurrence, required this.type});

  @override
  State<_ImageArea> createState() => _ImageAreaState();
}

class _ImageAreaState extends State<_ImageArea> {
  final _pageCtrl = PageController();
  int _current = 0;

  List<String> get _images {
    if (widget.occurrence.imagensUrls.isNotEmpty) {
      return widget.occurrence.imagensUrls;
    }
    if (widget.occurrence.imagemUrl != null) {
      return [widget.occurrence.imagemUrl!];
    }
    return [];
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images.isEmpty) {
      return _Placeholder(type: widget.type);
    }
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Container(
              width: double.infinity,
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: Image.network(
                images[i],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => _Placeholder(type: widget.type),
              ),
            ),
          ),
          if (images.length > 1) ...[
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(images.length, (i) {
                        final active = i == _current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1}/${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final OccurrenceType type;
  const _Placeholder({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      color: const Color(0xFFD1D5DB),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(type.icon, size: 48, color: Colors.white54),
          const SizedBox(height: 8),
          const Text(
            'Sem imagem',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TYPE BADGE  (sobre a imagem)
// ─────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final OccurrenceType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STATUS BADGE
// ─────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OccurrenceStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(status.icon, color: Colors.white, size: 14),
    );
  }
}

// ─────────────────────────────────────────
//  FIELD CARD (título / descrição)
// ─────────────────────────────────────────

class _FieldCard extends StatelessWidget {
  final Widget child;
  const _FieldCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────
//  REACTION CHIP  (like / dislike)
// ─────────────────────────────────────────

class _ReactionChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.icon,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.08) : _C.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? activeColor : _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? activeColor : _C.hint),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : _C.hint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ADD COMMENT BUTTON
// ─────────────────────────────────────────

class _AddCommentButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCommentButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.chat_bubble_outline, size: 16, color: _C.hint),
            SizedBox(width: 6),
            Text(
              'Adicionar comentário',
              style: TextStyle(
                fontSize: 13,
                color: _C.hint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  EMPTY COMMENTS
// ─────────────────────────────────────────

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text(
            'Sem comentários',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFFD1D5DB),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  COMMENT ITEM
// ─────────────────────────────────────────

class _CommentItem extends StatelessWidget {
  final ComentarioModel comentario;
  final bool isOwn;
  final VoidCallback onDelete;

  const _CommentItem({
    required this.comentario,
    required this.isOwn,
    required this.onDelete,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = comentario;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage:
                c.userPhotoUrl != null && c.userPhotoUrl!.isNotEmpty
                ? NetworkImage(c.userPhotoUrl!)
                : null,
            child: c.userPhotoUrl == null || c.userPhotoUrl!.isEmpty
                ? Text(
                    _initials(c.userName),
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Conteúdo do comentário
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        c.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _C.text,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(c.dataCriacao),
                      style: const TextStyle(fontSize: 11, color: _C.hint),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: _C.red,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  c.texto,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STATUS TIMELINE (linha do tempo)
// ─────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final OcorrenciaModel occurrence;
  final OcorrenciaService service;
  const _StatusTimeline({required this.occurrence, required this.service});

  String _fmt(DateTime? d) =>
      d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<({String status, DateTime? data})>>(
      stream: service.listarHistorico(occurrence.id),
      builder: (context, snap) {
        final eventos = snap.data ?? [];
        final linhas =
            <({IconData icone, Color cor, String label, DateTime? data})>[
              (
                icone: Icons.add_location_alt_outlined,
                cor: const Color(0xFF6B7280),
                label: 'Registrada',
                data: occurrence.dataCriacao,
              ),
            ];
        for (final e in eventos) {
          final s = OccurrenceStatusParser.fromString(e.status);
          linhas.add((
            icone: s.icon,
            cor: s.color,
            label: s.label,
            data: e.data,
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < linhas.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: linhas[i].cor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            linhas[i].icone,
                            size: 15,
                            color: linhas[i].cor,
                          ),
                        ),
                        if (i != linhas.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: i == linhas.length - 1 ? 0 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            linhas[i].label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: linhas[i].cor,
                            ),
                          ),
                          if (linhas[i].data != null)
                            Text(
                              _fmt(linhas[i].data),
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.hint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  COMMENT INPUT SHEET
// ─────────────────────────────────────────

class _CommentInputSheet extends StatefulWidget {
  final Future<void> Function(String text) onSubmit;

  const _CommentInputSheet({required this.onSubmit});

  @override
  State<_CommentInputSheet> createState() => _CommentInputSheetState();
}

class _CommentInputSheetState extends State<_CommentInputSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSubmit(text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Adicionar comentário',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Escreva um comentário...',
                      hintStyle: TextStyle(color: _C.hint, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
