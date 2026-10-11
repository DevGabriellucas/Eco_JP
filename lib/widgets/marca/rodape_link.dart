import 'package:flutter/material.dart';

import '../../theme/marca_cores.dart';
import '../../theme/brand_fonts.dart';

/// Rodapé "Pergunta? Ação", como "Não tem conta? Cadastre-se". A ação é um
/// botão de texto com área de toque de 48 dp.
class RodapeLink extends StatelessWidget {
  const RodapeLink({
    super.key,
    required this.pergunta,
    required this.acao,
    required this.onPressed,
  });

  final String pergunta;
  final String acao;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          pergunta,
          style: BrandFonts.body.copyWith(
            fontSize: 15,
            color: marca.textoApoio,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: marca.destaque,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle: BrandFonts.label.copyWith(fontSize: 15),
          ),
          child: Text(acao),
        ),
      ],
    );
  }
}
