import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/marca_cores.dart';

/// Ícone SVG de `assets/icons/` pintado com uma cor de marca. Os SVGs vêm do
/// Figma em cores pensadas para um fundo só (claro ou escuro); o
/// [ColorFilter] adapta sem mexer no arquivo. Decorativo: sem semântica,
/// quem descreve a ação é o botão em volta.
class IconeSvg extends StatelessWidget {
  const IconeSvg(
    this.asset, {
    super.key,
    this.cor,
    this.tamanho = 20,
  });

  final String asset;

  /// Nula = cor de apoio da paleta (`context.marca.textoApoio`).
  final Color? cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: tamanho,
      height: tamanho,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(
        cor ?? context.marca.textoApoio,
        BlendMode.srcIn,
      ),
    );
  }
}
