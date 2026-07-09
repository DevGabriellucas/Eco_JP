import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/comentario_model.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../utils/compartilhamento.dart';
import '../utils/tempo_relativo.dart';

class OccurrenceCard extends StatelessWidget {
  final OcorrenciaModel occurrence;
  final String? nomeAutor;
  final String? fotoAutor;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback? onComment;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReport;
  final VoidCallback? onTogglePin;
  final VoidCallback? onManage;
  final VoidCallback? onHide;
  final VoidCallback? onSave;
  final bool saved;

  // Contador de comentarios em tempo real. Quando nulo, usa occurrence.comments.
  final Stream<int>? commentCountStream;
  final Stream<ComentarioModel?>? latestCommentStream;

  const OccurrenceCard({
    super.key,
    required this.occurrence,
    this.nomeAutor,
    this.fotoAutor,
    required this.onLike,
    required this.onDislike,
    this.onComment,
    this.onAuthorTap,
    this.onReport,
    this.onTogglePin,
    this.onManage,
    this.onHide,
    this.onSave,
    this.saved = false,
    this.commentCountStream,
    this.latestCommentStream,
  });

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final tempoStr = tempoRelativo(o.dataCriacao);
    final statusEnum = OccurrenceStatusParser.fromString(o.status);
    final typeEnum = OccurrenceTypeParser.fromString(o.tipoLixo);
    final estagio = EstagioOficialInfo.calcular(o.verificada, o.statusOficial);
    final autor = _authorName;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (o.fixada) const _PinnedNotice(),
          _CardHeader(
            authorName: autor,
            authorPhoto: fotoAutor,
            location: o.localizacao,
            onMenuSelected: (action) => _handleMenuAction(context, action),
            canManage: onManage != null,
            canPin: onTogglePin != null,
            pinned: o.fixada,
            onAuthorTap: onAuthorTap,
            canReport: onReport != null,
          ),
          if (o.videoUrl != null && o.videoUrl!.trim().isNotEmpty)
            _FeedVideoPlayer(url: o.videoUrl!.trim(), type: typeEnum)
          else
            _ImageSlider(
              urls: o.imagensUrls,
              fallbackUrl: o.imagemUrl,
              type: typeEnum,
            ),
          _OfficialStatusStrip(estagio: estagio),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.favorite_border,
                  iconFilled: Icons.favorite,
                  count: o.likes,
                  active: o.userLiked,
                  activeColor: const Color(0xFFEF4444),
                  onTap: onLike,
                ),
                StreamBuilder<int>(
                  stream: commentCountStream,
                  initialData: o.comments,
                  builder: (context, snap) => _ActionButton(
                    icon: Icons.mode_comment_outlined,
                    iconFilled: Icons.mode_comment,
                    count: snap.data ?? o.comments,
                    active: false,
                    activeColor: const Color(0xFF2563EB),
                    onTap: onComment ?? () {},
                  ),
                ),
                _IconAction(
                  tooltip: 'Compartilhar',
                  icon: Icons.send_outlined,
                  onTap: () => compartilharOcorrencia(o),
                ),
                const Spacer(),
                _IconAction(
                  tooltip: saved ? 'Remover dos salvos' : 'Salvar',
                  icon: saved ? Icons.bookmark : Icons.bookmark_border,
                  active: saved,
                  onTap: onSave,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13,
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(
                        text: o.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (o.descricao.trim().isNotEmpty)
                        TextSpan(text: ' ${o.descricao.trim()}'),
                    ],
                  ),
                ),
                _CommentPreview(
                  countStream: commentCountStream,
                  initialCount: o.comments,
                  latestCommentStream: latestCommentStream,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        o.localizacao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TypeChip(type: typeEnum),
                    _StatusBadge(status: statusEnum),
                    if (estagio.temAcaoOficial) _EstagioChip(estagio: estagio),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tempoStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _authorName {
    final name = nomeAutor?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Usuário';
  }

  void _handleMenuAction(BuildContext context, _CardMenuAction action) {
    switch (action) {
      case _CardMenuAction.share:
        compartilharOcorrencia(occurrence);
        break;
      case _CardMenuAction.about:
        _showAccountSheet(context);
        break;
      case _CardMenuAction.hide:
        onHide?.call();
        break;
      case _CardMenuAction.report:
        onReport?.call();
        break;
      case _CardMenuAction.togglePin:
        onTogglePin?.call();
        break;
      case _CardMenuAction.manage:
        onManage?.call();
        break;
    }
  }

  void _showAccountSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _AccountSheet(
        authorName: _authorName,
        authorPhoto: fotoAutor,
        anonymous: occurrence.anonima,
        occurrence: occurrence,
      ),
    );
  }
}

class _PinnedNotice extends StatelessWidget {
  const _PinnedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFFFFBEB),
      child: const Row(
        children: [
          Icon(Icons.push_pin, size: 15, color: Color(0xFFD97706)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Denuncia fixada pela autoridade',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentPreview extends StatelessWidget {
  final Stream<int>? countStream;
  final int initialCount;
  final Stream<ComentarioModel?>? latestCommentStream;

  const _CommentPreview({
    required this.countStream,
    required this.initialCount,
    required this.latestCommentStream,
  });

  @override
  Widget build(BuildContext context) {
    if (latestCommentStream == null) return const SizedBox.shrink();

    return StreamBuilder<ComentarioModel?>(
      stream: latestCommentStream,
      builder: (context, latestSnap) {
        final latest = latestSnap.data;
        if (latest == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<int>(
                stream: countStream,
                initialData: initialCount,
                builder: (context, countSnap) {
                  final count = countSnap.data ?? initialCount;
                  return Text(
                    count <= 1
                        ? 'Ver comentário'
                        : 'Ver todos os $count comentários',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                  children: [
                    TextSpan(
                      text: latest.userName,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(text: latest.texto),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _CardMenuAction { share, about, hide, report, togglePin, manage }

class _CardHeader extends StatelessWidget {
  final String authorName;
  final String? authorPhoto;
  final String location;
  final bool canManage;
  final bool canReport;
  final bool canPin;
  final bool pinned;
  final VoidCallback? onAuthorTap;
  final ValueChanged<_CardMenuAction> onMenuSelected;

  const _CardHeader({
    required this.authorName,
    required this.authorPhoto,
    required this.location,
    required this.canManage,
    required this.canReport,
    required this.canPin,
    required this.pinned,
    this.onAuthorTap,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAuthorTap,
            child: Row(
              children: [
                _AuthorAvatar(
                  name: authorName,
                  photoUrl: authorPhoto,
                  radius: 18,
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAuthorTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<_CardMenuAction>(
            tooltip: 'Mais opções',
            icon: const Icon(
              Icons.more_horiz,
              color: Color(0xFF111827),
              size: 24,
            ),
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onSelected: onMenuSelected,
            itemBuilder: (context) {
              final items = <PopupMenuEntry<_CardMenuAction>>[
                const PopupMenuItem(
                  value: _CardMenuAction.share,
                  child: _MenuItem(
                    icon: Icons.ios_share_outlined,
                    label: 'Compartilhar',
                  ),
                ),
                const PopupMenuItem(
                  value: _CardMenuAction.about,
                  child: _MenuItem(
                    icon: Icons.person_outline,
                    label: 'Sobre esta conta',
                  ),
                ),
                const PopupMenuItem(
                  value: _CardMenuAction.hide,
                  child: _MenuItem(
                    icon: Icons.visibility_off_outlined,
                    label: 'Ocultar',
                  ),
                ),
              ];
              if (canReport) {
                items.add(
                  const PopupMenuItem(
                    value: _CardMenuAction.report,
                    child: _MenuItem(
                      icon: Icons.flag_outlined,
                      label: 'Denunciar',
                      danger: true,
                    ),
                  ),
                );
              }
              if (canPin) {
                items.add(
                  PopupMenuItem(
                    value: _CardMenuAction.togglePin,
                    child: _MenuItem(
                      icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      label: pinned ? 'Remover destaque' : 'Fixar no feed',
                    ),
                  ),
                );
              }
              if (canManage) {
                items
                  ..add(const PopupMenuDivider(height: 8))
                  ..add(
                    const PopupMenuItem(
                      value: _CardMenuAction.manage,
                      child: _MenuItem(
                        icon: Icons.tune,
                        label: 'Gerenciar denúncia',
                      ),
                    ),
                  );
              }
              return items;
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : const Color(0xFF374151);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: danger ? color : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FeedVideoPlayer extends StatefulWidget {
  final String url;
  final OccurrenceType type;

  const _FeedVideoPlayer({required this.url, required this.type});

  @override
  State<_FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<_FeedVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _error = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() {});
            _controller.play();
          })
          .catchError((_) {
            if (mounted) setState(() => _error = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleAudio() {
    setState(() {
      _muted = !_muted;
      _controller.setVolume(_muted ? 0 : 1);
    });
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth.clamp(220.0, 420.0).toDouble();

        if (_error) {
          return SizedBox(
            height: height,
            width: double.infinity,
            child: _ImagePlaceholder(
              type: widget.type,
              label: 'Video indisponivel',
            ),
          );
        }

        if (!_controller.value.isInitialized) {
          return SizedBox(
            height: height,
            width: double.infinity,
            child: const ColoredBox(
              color: Color(0xFF111827),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }

        final size = _controller.value.size;

        return GestureDetector(
          onTap: _togglePlay,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _controller.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.48),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: _muted ? 'Ativar som' : 'Silenciar',
                      onPressed: _toggleAudio,
                      icon: Icon(
                        _muted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OfficialStatusStrip extends StatelessWidget {
  final EstagioOficial estagio;

  const _OfficialStatusStrip({required this.estagio});

  @override
  Widget build(BuildContext context) {
    final color = estagio.color;
    final active = estagio.temAcaoOficial;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.09) : const Color(0xFFF9FAFB),
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 0.16 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(estagio.icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status oficial: ${estagio.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? color : const Color(0xFF4B5563),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _description {
    switch (estagio) {
      case EstagioOficial.pendente:
        return 'Aguardando analise do orgao responsavel.';
      case EstagioOficial.emAnalise:
        return 'O orgao responsavel esta avaliando esta denuncia.';
      case EstagioOficial.naoConfirmada:
        return 'Problema nao confirmado no local.';
      case EstagioOficial.confirmada:
        return 'Denuncia verificada pela autoridade.';
      case EstagioOficial.encaminhada:
        return 'Encaminhada ao orgao responsavel.';
      case EstagioOficial.resolvida:
        return 'Tratada e marcada como resolvida.';
    }
  }
}

class _ImageSlider extends StatefulWidget {
  final List<String> urls;
  final String? fallbackUrl;
  final OccurrenceType type;

  const _ImageSlider({
    required this.urls,
    required this.fallbackUrl,
    required this.type,
  });

  @override
  State<_ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<_ImageSlider> {
  final PageController _controller = PageController();
  int _current = 0;

  List<String> get _images {
    if (widget.urls.isNotEmpty) return widget.urls;
    if (widget.fallbackUrl != null) return [widget.fallbackUrl!];
    return [];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth.clamp(220.0, 420.0).toDouble();
        final images = _images;

        if (images.isEmpty) {
          return SizedBox(
            height: height,
            width: double.infinity,
            child: _ImagePlaceholder(type: widget.type),
          );
        }

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => Container(
                  width: double.infinity,
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: Image.network(
                    images[i],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
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
                    errorBuilder: (_, _, _) =>
                        _ImagePlaceholder(type: widget.type),
                  ),
                ),
              ),
              if (images.length > 1)
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
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              if (images.length > 1)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_current + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EstagioChip extends StatelessWidget {
  final EstagioOficial estagio;

  const _EstagioChip({required this.estagio});

  @override
  Widget build(BuildContext context) {
    final cor = estagio.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estagio.icon, size: 12, color: cor),
          const SizedBox(width: 4),
          Text(
            estagio.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OccurrenceStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 12),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final OccurrenceType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final badgeColor = type.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final OccurrenceType type;
  final String label;

  const _ImagePlaceholder({required this.type, this.label = 'Sem imagem'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F4F6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(type.icon, size: 40, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final IconData iconFilled;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.iconFilled,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                active ? iconFilled : icon,
                key: ValueKey(active),
                size: 24,
                color: active ? activeColor : const Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? activeColor : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  const _IconAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 24,
        color: active ? const Color(0xFF111827) : const Color(0xFF111827),
      ),
      onPressed: onTap,
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;

  const _AuthorAvatar({
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
              _initial,
              style: TextStyle(
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.82,
              ),
            ),
    );
  }

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed.characters.first.toUpperCase();
  }
}

class _AccountSheet extends StatelessWidget {
  final String authorName;
  final String? authorPhoto;
  final bool anonymous;
  final OcorrenciaModel occurrence;

  const _AccountSheet({
    required this.authorName,
    required this.authorPhoto,
    required this.anonymous,
    required this.occurrence,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 2, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AuthorAvatar(
                  name: authorName,
                  photoUrl: authorPhoto,
                  radius: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        anonymous
                            ? 'Publicação anônima'
                            : 'Conta da comunidade EcoJP',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _AccountInfoRow(
              icon: Icons.report_problem_outlined,
              label: 'Última denúncia',
              value: occurrence.titulo,
            ),
            const SizedBox(height: 12),
            _AccountInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Localização',
              value: occurrence.localizacao,
            ),
            if (anonymous) ...[
              const SizedBox(height: 14),
              const Text(
                'O autor escolheu publicar sem expor nome ou foto.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF16A34A)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
