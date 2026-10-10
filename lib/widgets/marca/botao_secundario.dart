import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';
import '../../theme/brand_fonts.dart';
import 'indicador_carregando.dart';
import 'medidas_marca.dart';

/// Botão contornado de ação secundária (Google, reenviar e-mail): fundo
/// branco, borda clara, largura total.
class BotaoSecundario extends StatelessWidget {
  const BotaoSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.carregando = false,
    this.icone,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;
  final Widget? icone;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: BrandColors.surfaceLight,
        foregroundColor: BrandColors.textOnLight,
        disabledForegroundColor: BrandColors.textOnLightMuted,
        side: const BorderSide(color: BrandColors.neutralSoft),
        minimumSize: const Size.fromHeight(MedidasMarca.alturaBotao),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MedidasMarca.raio),
        ),
        textStyle: BrandFonts.label.copyWith(fontSize: 15),
      ),
      child: carregando
          ? const IndicadorCarregando(cor: BrandColors.textOnLight)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icone != null) ...[icone!, const SizedBox(width: 12)],
                Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}
