import 'package:flutter/material.dart';

AppBar barraOcorrencias(
  BuildContext context, {
  bool mostrarVoltar = false,
}) {
  return AppBar(
    centerTitle: true,
    automaticallyImplyLeading: mostrarVoltar,
    title: Text(
      'Mapa de ocorrências',
      style: Theme.of(context).textTheme.titleLarge,
    ),
  );
}
