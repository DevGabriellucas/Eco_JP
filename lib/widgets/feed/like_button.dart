import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../shared/app_icons.dart';

class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int count;
  final Future<bool> Function() onToggle;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.count,
    required this.onToggle,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  late bool _liked;
  late int _count;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.isLiked;
    _count = widget.count;
  }

  @override
  void didUpdateWidget(covariant LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy) {
      _liked = widget.isLiked;
      _count = widget.count;
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final previousLiked = _liked;
    final previousCount = _count;
    setState(() {
      _busy = true;
      _liked = !_liked;
      _count += _liked ? 1 : -1;
    });
    HapticFeedback.lightImpact();
    try {
      final success = await widget.onToggle();
      if (!success && mounted) {
        setState(() {
          _liked = previousLiked;
          _count = previousCount;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _count = previousCount;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _liked ? AppColors.likeActive : context.pal.muted;
    return Semantics(
      button: true,
      selected: _liked,
      label: '${_liked ? 'Descurtir' : 'Curtir'}, $_count curtidas',
      child: InkResponse(
        onTap: _toggle,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _liked ? AppIcons.likeActive : AppIcons.like,
                size: 23,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                '${_count.clamp(0, 1 << 30)}',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
