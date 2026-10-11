import 'package:flutter/material.dart';

import '../../theme/marca_cores.dart';
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

  /// Ícone antes do texto (já pintado em `context.marca.sobreDestaque`).
  final Widget? icone;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: marca.destaque,
        foregroundColor: marca.sobreDestaque,
        disabledBackgroundColor: marca.destaque.withValues(alpha: 0.5),
        disabledForegroundColor: marca.sobreDestaque,
        minimumSize: const Size.fromHeight(MedidasMarca.alturaBotao),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MedidasMarca.raio),
        ),
        textStyle: BrandFonts.label,
      ),
      child: carregando
          ? IndicadorCarregando(cor: marca.sobreDestaque)
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
