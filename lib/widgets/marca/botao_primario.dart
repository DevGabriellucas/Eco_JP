import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';
import '../../theme/brand_fonts.dart';
import 'indicador_carregando.dart';
import 'medidas_marca.dart';

/// Botão principal da tela: verde de marca, largura total. Com [carregando]
/// troca o texto pelo indicador; com [onPressed] nulo fica desabilitado.
class BotaoPrimario extends StatelessWidget {
  const BotaoPrimario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.carregando = false,
    this.icone,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;

  /// Ícone antes do texto (já pintado em [BrandColors.onPrimary]).
  final Widget? icone;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.primary,
        foregroundColor: BrandColors.onPrimary,
        disabledBackgroundColor: BrandColors.primary.withValues(alpha: 0.5),
        disabledForegroundColor: BrandColors.onPrimary,
        minimumSize: const Size.fromHeight(MedidasMarca.alturaBotao),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MedidasMarca.raio),
        ),
        textStyle: BrandFonts.label,
      ),
      child: carregando
          ? const IndicadorCarregando(cor: BrandColors.onPrimary)
          : _ConteudoBotao(texto: texto, icone: icone),
    );
  }
}

class _ConteudoBotao extends StatelessWidget {
  const _ConteudoBotao({required this.texto, this.icone});

  final String texto;
  final Widget? icone;

  @override
  Widget build(BuildContext context) {
    final rotulo = Text(texto, overflow: TextOverflow.ellipsis);
    if (icone == null) return rotulo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [icone!, const SizedBox(width: 10), Flexible(child: rotulo)],
    );
  }
}
