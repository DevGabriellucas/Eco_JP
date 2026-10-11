import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/marca_cores.dart';
import '../../theme/brand_fonts.dart';
import 'icone_svg.dart';
import 'medidas_marca.dart';

/// Rótulo em caixa alta (IBM Plex Mono) sobre um campo de texto, como nos
/// formulários do Figma. O campo em si é o [child] (normalmente um
/// [TextField] com [decoracaoCampoMarca] e [estiloCampoMarca]).
class CampoMarca extends StatelessWidget {
  const CampoMarca({super.key, required this.rotulo, required this.child});

  final String rotulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // O leitor de tela anuncia o campo com o rótulo ("Email, campo de
    // texto"); sem isso ele só lia o hint, que some quando há texto. Não é
    // MergeSemantics: ele engoliria o botão do olho que fica dentro do campo
    // de senha.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            rotulo,
            style: BrandFonts.caption.copyWith(
              letterSpacing: 1.5,
              color: context.marca.rotulo,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(label: _rotuloFalado, child: child),
      ],
    );
  }

  /// "REPETIR SENHA" → "Repetir senha": em caixa alta alguns leitores
  /// soletram a palavra.
  String get _rotuloFalado {
    final minusculo = rotulo.toLowerCase();
    return minusculo.isEmpty
        ? minusculo
        : minusculo[0].toUpperCase() + minusculo.substring(1);
  }
}

/// Texto digitado nos campos de marca (cor da paleta do tema).
TextStyle estiloCampoMarca(BuildContext context) => BrandFonts.body.copyWith(
      fontSize: 16,
      height: 1.25,
      color: context.marca.texto,
    );

/// Decoração dos campos de marca: fundo da tela, borda discreta, foco na
/// cor de destaque e borda vermelha com [erro]. [prefixo] é o caminho de um
/// ícone de `assets/icons/`. As cores vêm de `context.marca` (claro/escuro).
InputDecoration decoracaoCampoMarca(
  BuildContext context, {
  required String hint,
  String? prefixo,
  Widget? sufixo,
  bool erro = false,
}) {
  final marca = context.marca;
  OutlineInputBorder borda(Color cor, double largura) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(MedidasMarca.raio),
        borderSide: BorderSide(color: cor, width: largura),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: estiloCampoMarca(context).copyWith(color: marca.textoApoio),
    filled: true,
    fillColor: marca.fundo,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: prefixo == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: IconeSvg(prefixo),
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    suffixIcon: sufixo,
    enabledBorder: borda(erro ? AppColors.danger : marca.borda, 1),
    focusedBorder: borda(erro ? AppColors.danger : marca.destaque, 1.5),
  );
}
