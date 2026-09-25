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
import '../theme/app_motion.dart';
import 'feed/like_button.dart';
import 'shared/app_icons.dart';
import 'shared/shimmer_box.dart';

class OccurrenceCard extends StatelessWidget {
  final OcorrenciaModel occurrence;
  final String? nomeAutor;
  final String? fotoAutor;
  final Future<bool> Function() onLike;
  final VoidCallback onDislike;
  final VoidCallback? onComment;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onReport;
  final VoidCallback? onTogglePin;
  final VoidCallback? onManage;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenDetail;

  // Contagem de comentários já resolvida (via .count() pontual). Quando nula
  // (ainda carregando), usa occurrence.comments como fallback.
  final int? commentCount;
  final Stream<ComentarioModel?>? latestCommentStream;
  // Último valor já emitido por [latestCommentStream]. Usado como initialData
  // para o preview não sumir quando o card sai e volta à tela (broadcast não
  // reentrega o último valor a quem assina depois).
  final ComentarioModel? latestCommentInitial;

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
    this.onOpenMap,
    this.onOpenDetail,
    this.commentCount,
    this.latestCommentStream,
    this.latestCommentInitial,
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

    return Material(
      color: pal.surface,
      borderRadius: BorderRadius.circular(AppRadius.cardLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.cardLarge),
            border: Border.all(color: pal.border.withValues(alpha: 0.65)),
            boxShadow:
                Theme.of(context).brightness == Brightness.light
                    ? AppShadows.card
                    : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (o.fixada) const _PinnedNotice(),
              _CardHeader(
                authorName: autor,
                authorPhoto: fotoAutor,
                location: o.localizacao,
                timeLabel: tempoStr,
                status: statusEnum,
                onMenuSelected: (action) => _handleMenuAction(context, action),
                canManage: onManage != null,
                canPin: onTogglePin != null,
                pinned: o.fixada,
                onAuthorTap: onAuthorTap,
                canReport: onReport != null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: o.videoUrl != null && o.videoUrl!.trim().isNotEmpty
                      ? _FeedVideoPlayer(
                          url: o.videoUrl!.trim(),
                          type: typeEnum,
                          title: o.titulo,
                          location: o.localizacao,
                          heroTag: 'occurrence-image-${o.id}',
                          onOpenDetail: onOpenDetail,
                        )
                      : _ImageSlider(
                          urls: o.imagensUrls,
                          fallbackUrl: o.imagemUrl,
                          type: typeEnum,
                          title: o.titulo,
                          location: o.localizacao,
                          onDoubleTapLike: onLike,
                          alreadyLiked: o.userLiked,
                          heroTag: 'occurrence-image-${o.id}',
                          onOpenDetail: onOpenDetail,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CompactCategoryBadge(type: typeEnum),
                    if (estagio.temAcaoOficial)
                      _CompactOfficialBadge(stage: estagio),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  o.titulo.trim().isEmpty
                      ? 'Denúncia ambiental'
                      : o.titulo.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: pal.ink,
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: _PostText(description: o.descricao),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    LikeButton(
                      count: o.likes,
                      isLiked: o.userLiked,
                      onToggle: onLike,
                    ),
                    _CommentButton(
                      count: commentCount ?? o.comments,
                      onTap: onComment ?? () {},
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Compartilhar',
                      onPressed: () => compartilharOcorrencia(o),
                      icon: Icon(AppIcons.share, color: pal.muted, size: 24),
                    ),
                  ],
                ),
              ),
              if (latestCommentStream != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: InkWell(
                    onTap: onComment,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: _CommentPreview(
                      count: commentCount,
                      initialCount: o.comments,
                      latestCommentStream: latestCommentStream,
                      latestCommentInitial: latestCommentInitial,
                    ),
                  ),
                ),
              if ((commentCount ?? o.comments) > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton(
                    onPressed: onComment,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      foregroundColor: pal.muted,
                    ),
                    child: Text(
                      (commentCount ?? o.comments) == 1
                          ? 'Ver comentário'
                          : 'Ver mais ${commentCount ?? o.comments} comentários',
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenMap,
                    style: FilledButton.styleFrom(
                      backgroundColor: pal.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    icon: const Icon(AppIcons.map, size: 19),
                    label: const Text('Ver no mapa'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mantido como fallback de layout para integrações antigas do card.
  // ignore: unused_element
  Widget _buildCompact(
    BuildContext context, {
    required OcorrenciaModel occurrence,
    required String author,
    required String timeLabel,
    required OccurrenceStatus status,
    required OccurrenceType type,
    required EstagioOficial officialStage,
  }) {
    final pal = context.pal;
    final images = <String>{
      ...occurrence.imagensUrls.map((url) => url.trim()),
      if (occurrence.imagemUrl != null) occurrence.imagemUrl!.trim(),
    }.where((url) => url.isNotEmpty).toList(growable: false);
    const String? referenceAsset = null;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: SizedBox(
        height: 198,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 142,
              child: _CompactMedia(
                images: images,
                hasVideo: occurrence.videoUrl?.trim().isNotEmpty == true,
                type: type,
                status: status,
                referenceAsset: referenceAsset,
                heroTag: 'occurrence-image-${occurrence.id}',
                alreadyLiked: occurrence.userLiked,
                onDoubleTapLike: onLike,
                onOpenDetail: onOpenDetail,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 5, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            occurrence.titulo.trim().isEmpty
                                ? 'Denúncia ambiental'
                                : occurrence.titulo.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                            ),
                          ),
                        ),
                        PopupMenuButton<_CardMenuAction>(
                          tooltip: 'Mais opções',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          icon: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF23324D), size: 22),
                          onSelected: (action) =>
                              _handleMenuAction(context, action),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: _CardMenuAction.share,
                              child: Text('Compartilhar'),
                            ),
                            if (onReport != null)
                              const PopupMenuItem(
                                value: _CardMenuAction.report,
                                child: Text('Denunciar'),
                              ),
                            if (onTogglePin != null)
                              PopupMenuItem(
                                value: _CardMenuAction.togglePin,
                                child: Text(occurrence.fixada
                                    ? 'Remover destaque'
                                    : 'Fixar no feed'),
                              ),
                            if (onManage != null)
                              const PopupMenuItem(
                                value: _CardMenuAction.manage,
                                child: Text('Gerenciar denúncia'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Text(
                          ' · $timeLabel',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.locationPin,
                            size: 13, color: Color(0xFF536078)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            occurrence.localizacao,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF657087),
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      occurrence.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF657087),
                        fontSize: 10.5,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Flexible(child: _CompactCategoryBadge(type: type)),
                        if (officialStage.temAcaoOficial) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: _CompactOfficialBadge(stage: officialStage),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        LikeButton(
                          count: occurrence.likes,
                          isLiked: occurrence.userLiked,
                          onToggle: onLike,
                        ),
                        _CompactAction(
                          icon: AppIcons.comment,
                          label: '${commentCount ?? occurrence.comments}',
                          tooltip: 'Comentários',
                          onTap: onComment ?? () {},
                        ),
                        _CompactAction(
                          icon: AppIcons.share,
                          tooltip: 'Compartilhar',
                          onTap: () => compartilharOcorrencia(occurrence),
                        ),
                      ],
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

class _CompactMedia extends StatefulWidget {
  final List<String> images;
  final bool hasVideo;
  final OccurrenceType type;
  final OccurrenceStatus status;
  final String? referenceAsset;
  final String heroTag;
  final bool alreadyLiked;
  final Future<bool> Function() onDoubleTapLike;
  final VoidCallback? onOpenDetail;

  const _CompactMedia({
    required this.images,
    required this.hasVideo,
    required this.type,
    required this.status,
    required this.referenceAsset,
    required this.heroTag,
    required this.alreadyLiked,
    required this.onDoubleTapLike,
    required this.onOpenDetail,
  });

  @override
  State<_CompactMedia> createState() => _CompactMediaState();
}

class _CompactMediaState extends State<_CompactMedia> {
  late final PageController _pageController;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _like() {
    if (!widget.alreadyLiked) widget.onDoubleTapLike();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.images.isNotEmpty;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      onTap: widget.onOpenDetail,
      onDoubleTap: _like,
      child: Hero(
        tag: widget.heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) =>
                      setState(() => _currentImage = index),
                  itemBuilder: (_, index) => Image(
                    image: imagemCacheada(
                      cloudinaryOtimizada(
                        widget.images[index],
                        larguraLogica: 128,
                        alturaLogica: 188,
                        devicePixelRatio: dpr,
                      ),
                      cacheWidth: cacheLarguraPx(128, dpr),
                    ),
                    fit: BoxFit.cover,
                    semanticLabel:
                        'Imagem ${index + 1} de ${widget.images.length} da denúncia de ${widget.type.label}',
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : const ShimmerBox(),
                    errorBuilder: (_, error, stack) => _ImagePlaceholder(
                      type: widget.type,
                      label: 'Imagem indisponível',
                    ),
                  ),
                )
              else if (widget.referenceAsset != null)
                Image.asset(widget.referenceAsset!, fit: BoxFit.cover)
              else
                _ImagePlaceholder(
                  type: widget.type,
                  label: widget.hasVideo ? 'Vídeo' : 'Sem imagem',
                ),
              if (widget.hasVideo)
                Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(AppIcons.play,
                        color: Colors.white, size: 21),
                  ),
                ),
              if (widget.images.length > 1)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .58),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.camera,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${_currentImage + 1}/${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.referenceAsset == null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: _HeaderStatusBadge(status: widget.status),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactCategoryBadge extends StatelessWidget {
  final OccurrenceType type;

  const _CompactCategoryBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: type.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: type.color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactOfficialBadge extends StatelessWidget {
  final EstagioOficial stage;

  const _CompactOfficialBadge({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: stage.color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        stage.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: stage.color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  const _CompactAction({
    required this.icon,
    this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: context.pal.muted),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label!,
                  style: TextStyle(
                    color: context.pal.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
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
  final int? count;
  final int initialCount;
  final Stream<ComentarioModel?>? latestCommentStream;
  final ComentarioModel? latestCommentInitial;

  const _CommentPreview({
    required this.count,
    required this.initialCount,
    required this.latestCommentStream,
    required this.latestCommentInitial,
  });

  @override
  Widget build(BuildContext context) {
    if (latestCommentStream == null) return const SizedBox.shrink();

    return StreamBuilder<ComentarioModel?>(
      stream: latestCommentStream,
      initialData: latestCommentInitial,
      builder: (context, latestSnap) {
        final latest = latestSnap.data;
        if (latest == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: RichText(
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
        );
      },
    );
  }
}

enum _CardMenuAction { share, about, report, togglePin, manage }

class _PostText extends StatefulWidget {
  final String description;

  const _PostText({required this.description});

  @override
  State<_PostText> createState() => _PostTextState();
}

class _PostTextState extends State<_PostText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final descricao = widget.description.trim();
    if (descricao.isEmpty) return const SizedBox.shrink();
    final bodyStyle = AppTextStyles.body.copyWith(
      color: context.pal.ink.withValues(alpha: 0.88),
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.45,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = _exceedsCollapsedLines(
          context: context,
          text: descricao,
          style: bodyStyle,
          maxWidth: constraints.maxWidth,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (descricao.isNotEmpty) ...[
              AnimatedSize(
                duration: AppMotion.base,
                curve: AppMotion.curveEnter,
                alignment: Alignment.topCenter,
                child: Text(
                  descricao,
                  maxLines: _expanded ? null : 2,
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: bodyStyle,
                ),
              ),
              if (canExpand)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Semantics(
                    button: true,
                    label: _expanded
                        ? 'Recolher descrição da denúncia'
                        : 'Ver descrição completa da denúncia',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: Text(
                          _expanded ? 'ver menos' : 'ver mais',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  bool _exceedsCollapsedLines({
    required BuildContext context,
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    if (text.isEmpty || maxWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 2,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}

class _CardHeader extends StatelessWidget {
  final String authorName;
  final String? authorPhoto;
  final String location;
  final String timeLabel;
  final OccurrenceStatus status;
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
    required this.timeLabel,
    required this.status,
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
      padding: const EdgeInsets.fromLTRB(16, 13, 6, 12),
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
                  radius: 21,
                ),
                const SizedBox(width: 12),
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
                    style: AppTextStyles.cardTitle.copyWith(
                      color: context.pal.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        AppIcons.locationPin,
                        size: 13,
                        color: context.pal.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location.trim().isEmpty
                              ? timeLabel
                              : '${location.trim()} · $timeLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.metadata.copyWith(
                            color: context.pal.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _HeaderStatusBadge(status: status),
          PopupMenuButton<_CardMenuAction>(
            tooltip: 'Mais opções',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(AppIcons.more, color: pal.hint, size: 22),
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

class _HeaderStatusBadge extends StatelessWidget {
  final OccurrenceStatus status;

  const _HeaderStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = switch (status) {
      OccurrenceStatus.resolved => (
          AppColors.statusResolved,
          AppColors.statusResolved.withValues(alpha: 0.12),
          AppIcons.verified,
        ),
      OccurrenceStatus.inProgress => (
          AppColors.statusPending,
          AppColors.statusPending.withValues(alpha: 0.14),
          AppIcons.pending,
        ),
      OccurrenceStatus.unresolved => (
          AppColors.statusUnresolved,
          AppColors.statusUnresolved.withValues(alpha: 0.12),
          AppIcons.unresolved,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
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
  final String title;
  final String location;
  final String heroTag;
  final VoidCallback? onOpenDetail;

  const _FeedVideoPlayer({
    required this.url,
    required this.type,
    required this.title,
    required this.location,
    required this.heroTag,
    this.onOpenDetail,
  });

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
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((_) {
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
        final height =
            (constraints.maxWidth * 0.75).clamp(220.0, 420.0).toDouble();

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
            child: const ShimmerBox(),
          );
        }

        final size = _controller.value.size;

        return GestureDetector(
          onTap: widget.onOpenDetail ?? _togglePlay,
          child: Hero(
            tag: widget.heroTag,
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
          ),
        );
      },
    );
  }
}

class _ImageSlider extends StatefulWidget {
  final List<String> urls;
  final String? fallbackUrl;
  final OccurrenceType type;
  final String title;
  final String location;

  /// Curtir por toque duplo na foto (estilo Instagram). Só curte — nunca
  /// descurte — por isso recebe também [alreadyLiked] para não desfazer.
  final VoidCallback? onDoubleTapLike;
  final bool alreadyLiked;
  final String heroTag;
  final VoidCallback? onOpenDetail;

  const _ImageSlider({
    required this.urls,
    required this.fallbackUrl,
    required this.type,
    required this.title,
    required this.location,
    this.onDoubleTapLike,
    this.alreadyLiked = false,
    required this.heroTag,
    this.onOpenDetail,
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
    final urls = widget.urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (urls.isNotEmpty) return urls;
    final fallback = widget.fallbackUrl?.trim();
    if (fallback != null && fallback.isNotEmpty) return [fallback];
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
        final height =
            (constraints.maxWidth * 0.75).clamp(220.0, 420.0).toDouble();
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
                onTap: widget.onOpenDetail,
                onDoubleTap:
                    widget.onDoubleTapLike == null ? null : _handleDoubleTap,
                child: Hero(
                  tag: widget.heroTag,
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
                          return const ShimmerBox();
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _ImagePlaceholder(type: widget.type),
                      ),
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

// Mantido para compatibilidade com apresentações antigas da mídia.
// ignore: unused_element
class _ImageTitleOverlay extends StatelessWidget {
  final String title;
  final String location;
  final OccurrenceType type;

  const _ImageTitleOverlay({
    required this.title,
    required this.location,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final cleanTitle =
        title.trim().isEmpty ? 'Denúncia ambiental' : title.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.68),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cleanTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (location.trim().isNotEmpty)
                _OverlayPill(
                  icon: type.icon,
                  label: '${type.label} · ${location.trim()}',
                  maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                  allowWrap: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? maxWidth;
  final bool allowWrap;

  const _OverlayPill({
    required this.icon,
    required this.label,
    this.maxWidth,
    this.allowWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 15,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: allowWrap ? 2 : 1,
                overflow:
                    allowWrap ? TextOverflow.visible : TextOverflow.ellipsis,
                softWrap: allowWrap,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mantido para compatibilidade com cards que exibem o estágio em bloco.
// ignore: unused_element
class _EstagioChip extends StatelessWidget {
  final EstagioOficial estagio;

  const _EstagioChip({required this.estagio});

  @override
  Widget build(BuildContext context) {
    final cor = estagio.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1,
        ),
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

class _CommentButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _CommentButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Comentar, $count',
      child: Tooltip(
        message: 'Comentar',
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  AppIcons.comment,
                  size: 27,
                  color: AppColors.iconMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.iconMuted,
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
      backgroundColor: AppColors.primarySoft,
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
                color: AppColors.primaryDarkText,
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
                            : 'Conta da comunidade Eco Hub',
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
