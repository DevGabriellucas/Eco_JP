import 'package:flutter/material.dart';

import '../../utils/margem_responsiva.dart';
import 'medidas_marca.dart';

/// Corpo das telas de formulário: ocupa pelo menos a tela inteira (dá para
/// prender um rodapé no pé com `MainAxisAlignment.spaceBetween`) e rola
/// quando não cabe (teclado aberto, tela baixa, fonte grande).
///
/// O [builder] recebe a margem lateral já responsiva: em tablet e paisagem o
/// conteúdo fica numa coluna centralizada de até
/// [MedidasMarca.larguraMaxConteudo].
///
/// Sem medição intrínseca (SliverFillRemaining/IntrinsicHeight), que seria
/// refeita a cada frame da animação do teclado.
class CorpoRolavel extends StatelessWidget {
  const CorpoRolavel({super.key, required this.builder});

  final Widget Function(BuildContext context, double margem) builder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: builder(
              context,
              margemResponsiva(
                c.maxWidth,
                margemMinima: MedidasMarca.margemLateral,
                larguraMaxima: MedidasMarca.larguraMaxConteudo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
