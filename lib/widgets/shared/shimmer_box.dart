import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';

class ShimmerBox extends StatefulWidget {
  final BorderRadius? borderRadius;

  const ShimmerBox({super.key, this.borderRadius});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.shimmerLoop,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.8 + progress * 3.6, 0),
              end: Alignment(-0.8 + progress * 3.6, 0),
              colors: const [
                AppColors.primarySoft,
                Color(0xFFF0FAF5),
                AppColors.primarySoft,
              ],
            ),
          ),
        );
      },
    );
  }
}
