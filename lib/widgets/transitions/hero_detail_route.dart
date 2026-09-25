import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

class HeroDetailRoute<T> extends PageRouteBuilder<T> {
  HeroDetailRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: AppMotion.slow,
          reverseTransitionDuration: AppMotion.base,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.curveEnter,
              reverseCurve: AppMotion.curveExit,
            );
            return FadeTransition(opacity: curved, child: child);
          },
        );
}
