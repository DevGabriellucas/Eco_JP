import 'package:eco_jp/theme/app_theme.dart';
import 'package:flutter/material.dart';

AppBar barraOcorrencias(
  BuildContext context, {
  required bool rotasColetaAtivas,
  required VoidCallback onToggleRotasColeta,
  required VoidCallback onBuscarBairro,
}) {
  return AppBar(
    centerTitle: true,
    automaticallyImplyLeading: false,
    title: Text(
      'Mapa de ocorrências',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    actions: [
      IconButton(
        tooltip: 'Consultar coleta por bairro',
        icon: const Icon(Icons.search, color: AppColors.ink),
        onPressed: onBuscarBairro,
      ),
      IconButton(
        tooltip: rotasColetaAtivas
            ? 'Ocultar rotas de coleta de lixo'
            : 'Mostrar rotas de coleta de lixo',
        icon: Icon(
          rotasColetaAtivas
              ? Icons.local_shipping
              : Icons.local_shipping_outlined,
          color: rotasColetaAtivas ? AppColors.primary : AppColors.ink,
        ),
        onPressed: onToggleRotasColeta,
      ),
    ],
  );
}
