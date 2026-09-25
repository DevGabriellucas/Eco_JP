import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const AnimatedCounter({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.curveEnter,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.55),
          end: Offset.zero,
        ).animate(animation);
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          ),
        );
      },
      child: Text('$value', key: ValueKey(value), style: style),
    );
  }
}
