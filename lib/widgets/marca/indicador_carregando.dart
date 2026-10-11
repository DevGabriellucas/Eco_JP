import 'package:flutter/material.dart';

/// Indicador de progresso pequeno, para dentro de botões.
class IndicadorCarregando extends StatelessWidget {
  const IndicadorCarregando({super.key, required this.cor});

  final Color cor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: cor),
    );
  }
}
