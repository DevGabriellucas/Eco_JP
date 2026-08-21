import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/comentario_model.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../utils/cloudinary_image.dart';
import '../utils/imagem_cacheada.dart';
import '../utils/compartilhamento.dart';
import '../utils/tempo_relativo.dart';
import '../theme/app_theme.dart';

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
    final pal = context.pal;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pal.border),
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
              onDoubleTapLike: onLike,
              alreadyLiked: o.userLiked,
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
                  activeColor: AppColors.danger,
                  onTap: onLike,
                  semanticLabel: o.userLiked ? 'Descurtir' : 'Curtir',
                  animateOnActivate: true,
                ),
                StreamBuilder<int>(
                  stream: commentCountStream,
                  initialData: o.comments,
                  builder: (context, snap) => _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    iconFilled: Icons.chat_bubble,
                    count: snap.data ?? o.comments,
                    active: false,
                    activeColor: AppColors.info,
                    onTap: onComment ?? () {},
                    semanticLabel: 'Comentar',
                  ),
                ),
                _IconAction(
                  tooltip: 'Compartilhar',
                  icon: Icons.share_outlined,
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
                    style: TextStyle(
                      color: pal.ink,
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
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: pal.muted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        o.localizacao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: pal.muted,
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
                  style: TextStyle(
                    fontSize: 11,
                    color: pal.muted,
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
      backgroundColor: context.pal.surface,
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
      color: AppColors.warning.withValues(alpha: 0.12),
      child: const Row(
        children: [
          Icon(Icons.push_pin, size: 15, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Denuncia fixada pela autoridade',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.warning,
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
                    style: TextStyle(
                      color: context.pal.muted,
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
                  style: TextStyle(
                    color: context.pal.ink,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                  children: [
                    TextSpan(
                      text: latest.userName,
                      style: TextStyle(
                        color: context.pal.ink,
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
    final pal = context.pal;
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: pal.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: pal.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<_CardMenuAction>(
            tooltip: 'Mais opções',
            icon: Icon(Icons.more_horiz, color: pal.ink, size: 24),
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
    final color = danger ? AppColors.danger : context.pal.ink;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color,
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
    final pal = context.pal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.09) : pal.surfaceAlt,
        border: Border(bottom: BorderSide(color: pal.border)),
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
                    color: active ? color : pal.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: pal.muted,
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

  /// Curtir por toque duplo na foto (estilo Instagram). Só curte — nunca
  /// descurte — por isso recebe também [alreadyLiked] para não desfazer.
  final VoidCallback? onDoubleTapLike;
  final bool alreadyLiked;

  const _ImageSlider({
    required this.urls,
    required this.fallbackUrl,
    required this.type,
    this.onDoubleTapLike,
    this.alreadyLiked = false,
  });

  @override
  State<_ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<_ImageSlider>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  int _current = 0;
  late final AnimationController _burstController;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  List<String> get _images {
    if (widget.urls.isNotEmpty) return widget.urls;
    if (widget.fallbackUrl != null) return [widget.fallbackUrl!];
    return [];
  }

  void _handleDoubleTap() {
    if (widget.onDoubleTapLike == null) return;
    _burstController.forward(from: 0);
    // Toque duplo sempre "curte": se já estava curtido, apenas repete o coração
    // sem alternar (não descurte, igual ao Instagram).
    if (!widget.alreadyLiked) widget.onDoubleTapLike!.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth.clamp(220.0, 420.0).toDouble();
        final images = _images;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final larguraImg = constraints.maxWidth;

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
              GestureDetector(
                onDoubleTap: widget.onDoubleTapLike == null
                    ? null
                    : _handleDoubleTap,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (_, i) => Container(
                    width: double.infinity,
                    color: context.pal.surfaceAlt,
                    alignment: Alignment.center,
                    child: Image(
                      image: imagemCacheada(
                        cloudinaryOtimizada(
                          images[i],
                          larguraLogica: larguraImg,
                          devicePixelRatio: dpr,
                        ),
                        cacheWidth: cacheLarguraPx(larguraImg, dpr),
                      ),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      // Descrição para leitores de tela: sem isto o Image.network
                      // é anunciado apenas como "imagem", sem contexto.
                      semanticLabel: images.length > 1
                          ? 'Foto ${i + 1} de ${images.length} da denúncia: ${widget.type.label}'
                          : 'Foto da denúncia: ${widget.type.label}',
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
                      errorBuilder: (context, error, stackTrace) =>
                          _ImagePlaceholder(type: widget.type),
                    ),
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
              // Coração que aparece com o duplo-toque (estilo Instagram).
              if (widget.onDoubleTapLike != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _HeartBurst(controller: _burstController),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Coração grande que "estoura" no centro da foto ao curtir por duplo-toque:
/// aparece com um leve overshoot e some subindo. Some por completo em repouso.
class _HeartBurst extends StatelessWidget {
  final AnimationController controller;

  const _HeartBurst({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.isDismissed) return const SizedBox.shrink();
        final t = controller.value;
        // Cresce rápido (0→0.35) e depois some suave (0.5→1.0).
        final scale = t < 0.35 ? Curves.easeOutBack.transform(t / 0.35) : 1.0;
        final opacity = t < 0.5 ? 1.0 : (1.0 - (t - 0.5) / 0.5).clamp(0.0, 1.0);
        return Center(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: const Icon(
        Icons.favorite,
        color: Colors.white,
        size: 96,
        shadows: [
          Shadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 3)),
        ],
      ),
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
    final pal = context.pal;
    return Container(
      width: double.infinity,
      color: pal.surfaceAlt,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(type.icon, size: 40, color: pal.hint),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: pal.hint, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final IconData iconFilled;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final String semanticLabel;

  /// Quando true, o ícone dá um "pop" (bounce) e um "+1" sobe ao passar de
  /// inativo para ativo. Usado no botão de curtir.
  final bool animateOnActivate;

  const _ActionButton({
    required this.icon,
    required this.iconFilled,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.onTap,
    required this.semanticLabel,
    this.animateOnActivate = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with TickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _scale;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Escala com overshoot: cresce até 1.35 e volta a 1.0.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_popController);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(covariant _ActionButton old) {
    super.didUpdateWidget(old);
    // Dispara as animações só na transição inativo → ativo (curtir), nunca ao
    // descurtir nem quando o count muda por outro caminho.
    if (widget.animateOnActivate && widget.active && !old.active) {
      _popController.forward(from: 0);
      _floatController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final color = widget.active ? widget.activeColor : pal.ink;
    return Semantics(
      button: true,
      label: '${widget.semanticLabel}, ${widget.count}',
      selected: widget.active,
      child: Tooltip(
        message: widget.semanticLabel,
        child: InkResponse(
          onTap: widget.onTap,
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          widget.active ? widget.iconFilled : widget.icon,
                          key: ValueKey(widget.active),
                          size: 24,
                          color: color,
                        ),
                      ),
                    ),
                    if (widget.animateOnActivate)
                      _FloatingPlusOne(
                        controller: _floatController,
                        color: widget.activeColor,
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "+1" que sobe e some ao curtir. Fica escondido enquanto o controlador
/// estiver zerado (estado de repouso).
class _FloatingPlusOne extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _FloatingPlusOne({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.isDismissed) return const SizedBox.shrink();
        final t = controller.value;
        return Positioned(
          top: -6 - (t * 18),
          child: Opacity(opacity: (1.0 - t).clamp(0.0, 1.0), child: child),
        );
      },
      child: Text(
        '+1',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
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
      icon: Icon(icon, size: 24, color: context.pal.ink),
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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.14),
      backgroundImage: hasPhoto
          ? imagemCacheada(
              cloudinaryOtimizada(
                photoUrl!,
                larguraLogica: radius * 2,
                alturaLogica: radius * 2,
                devicePixelRatio: dpr,
                crop: 'fill',
              ),
            )
          : null,
      child: hasPhoto
          ? null
          : Text(
              _initial,
              style: TextStyle(
                color: AppColors.successStrong,
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
                        style: TextStyle(
                          fontSize: 17,
                          color: context.pal.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        anonymous
                            ? 'Publicação anônima'
                            : 'Conta da comunidade EcoJP',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.pal.muted,
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
              Text(
                'O autor escolheu publicar sem expor nome ou foto.',
                style: TextStyle(
                  color: context.pal.muted,
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
        Icon(icon, size: 18, color: AppColors.successStrong),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.pal.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.pal.ink,
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
