import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/brand_fonts.dart';

/// Mensagem de erro de formulário, logo abaixo do campo ou acima do botão.
/// Aparece uma vez só (antes as telas repetiam o erro num snackbar).
class TextoErro extends StatelessWidget {
  const TextoErro(this.mensagem, {super.key});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        mensagem,
        style: BrandFonts.body.copyWith(
          fontSize: 13,
          height: 1.4,
          color: AppColors.danger,
        ),
      ),
    );
  }
}
