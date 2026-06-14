import 'package:flutter/material.dart';

import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../utils/tempo_relativo.dart';

// ─────────────────────────────────────────
//  OCCURRENCE CARD
// ─────────────────────────────────────────

class OccurrenceCard extends StatelessWidget {
  final OcorrenciaModel occurrence;
  final String? nomeAutor;
  final String? fotoAutor;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onTap;
  final VoidCallback? onManage;

  // Contador de comentários em tempo real. Quando nulo, usa occurrence.comments.
  final Stream<int>? commentCountStream;

  const OccurrenceCard({
    super.key,
    required this.occurrence,
    this.nomeAutor,
    this.fotoAutor,
    required this.onLike,
    required this.onDislike,
    required this.onTap,
    this.onManage,
    this.commentCountStream,
  });

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final tempoStr = tempoRelativo(o.dataCriacao);
    final statusEnum = OccurrenceStatusParser.fromString(o.status);
    final typeEnum = OccurrenceTypeParser.fromString(o.tipoLixo);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE8F5E9),
                    backgroundImage: fotoAutor != null
                        ? NetworkImage(fotoAutor!) as ImageProvider
                        : null,
                    child: fotoAutor == null
                        ? Text(
                            (nomeAutor ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomeAutor ?? 'Usuário',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          tempoStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: statusEnum),
                  if (onManage != null)
                    GestureDetector(
                      onTap: onManage,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Location row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 13,
                    color: Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      o.localizacao,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(type: typeEnum),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Images slideshow
            _ImageSlider(
              urls: o.imagensUrls,
              fallbackUrl: o.imagemUrl,
              type: typeEnum,
            ),

            const SizedBox(height: 12),

            // ── Title & description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    o.descricao,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Actions row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.thumb_up_alt_outlined,
                    iconFilled: Icons.thumb_up_alt,
                    count: o.likes,
                    active: o.userLiked,
                    activeColor: const Color(0xFF4CAF50),
                    onTap: onLike,
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    icon: Icons.thumb_down_alt_outlined,
                    iconFilled: Icons.thumb_down_alt,
                    count: o.dislikes,
                    active: o.userDisliked,
                    activeColor: const Color(0xFFEF4444),
                    onTap: onDislike,
                  ),
                  const SizedBox(width: 16),
                  StreamBuilder<int>(
                    stream: commentCountStream,
                    initialData: o.comments,
                    builder: (context, snap) => _ActionButton(
                      icon: Icons.chat_bubble_outline,
                      iconFilled: Icons.chat_bubble,
                      count: snap.data ?? o.comments,
                      active: false,
                      activeColor: const Color(0xFF3B82F6),
                      onTap: onTap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  IMAGE SLIDER
// ─────────────────────────────────────────

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
    final images = _images;

    if (images.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: _ImagePlaceholder(type: widget.type),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          // ── Page view — mostra a foto inteira (sem cortar)
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
                errorBuilder: (_, _, _) => _ImagePlaceholder(type: widget.type),
              ),
            ),
          ),

          // ── Dots (só aparece se tiver mais de 1 imagem)
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
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

          // ── Contador (ex: 1/3)
          if (images.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
//  TYPE CHIP
// ─────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final OccurrenceType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final badgeColor = type.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  IMAGE PLACEHOLDER
// ─────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  final OccurrenceType type;

  const _ImagePlaceholder({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(type.icon, size: 40, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 8),
          const Text(
            'Sem imagem',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ACTION BUTTON
// ─────────────────────────────────────────

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
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              active ? iconFilled : icon,
              key: ValueKey(active),
              size: 18,
              color: active ? activeColor : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? activeColor : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
