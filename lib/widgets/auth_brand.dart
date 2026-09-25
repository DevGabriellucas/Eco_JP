import 'package:flutter/material.dart';

abstract final class AuthBrand {
  static const background = Color(0xFF091E13);
  static const green = Color(0xFF22C55E);
  static const ink = Colors.white;
  static const muted = Color(0xCCFFFFFF);
  static const hint = Color(0xBFFFFFFF);
  static const border = Color(0x33FFFFFF);
  static const surface = Color(0x1AFFFFFF);
}

class AuthBackground extends StatelessWidget {
  final bool onboarding;
  const AuthBackground({super.key, this.onboarding = false});

  @override
  Widget build(BuildContext context) => Image.asset(
        onboarding
            ? 'assets/images/onboarding_background.png'
            : 'assets/images/auth_background.png',
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
        excludeFromSemantics: true,
      );
}

class EcoHubWordmark extends StatelessWidget {
  final bool trimPadding;
  const EcoHubWordmark({super.key, this.trimPadding = false});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/ecohub_wordmark.png',
      fit: BoxFit.contain,
      semanticLabel: 'Eco Hub',
    );
    if (!trimPadding) return image;

    // The supplied 805x310 PNG contains large transparent margins.
    // Frame the artwork without modifying pixels or stretching the wordmark.
    return AspectRatio(
      aspectRatio: 611 / 124,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 611,
          height: 124,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                  left: -100, top: -88, width: 805, height: 310, child: image),
            ],
          ),
        ),
      ),
    );
  }
}
