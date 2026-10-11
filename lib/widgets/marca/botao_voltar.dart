import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_icons.dart';
import '../../theme/marca_cores.dart';
import 'icone_svg.dart';

/// Seta de voltar das telas claras. Volta para a tela anterior (preserva o
/// estado dela, como o slide da inicial); sem tela anterior (link externo,
/// redirect do router), vai para [rotaSemAnterior].
class BotaoVoltar extends StatelessWidget {
  const BotaoVoltar({super.key, required this.rotaSemAnterior});

  final String rotaSemAnterior;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Voltar',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(rotaSemAnterior);
        }
      },
      icon: IconeSvg(
        AppIcons.arrowBack,
        cor: context.marca.texto,
        tamanho: 24,
      ),
    );
  }
}
