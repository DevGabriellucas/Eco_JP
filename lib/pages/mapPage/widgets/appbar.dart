import 'package:flutter/material.dart';

AppBar barraOcorrencias(BuildContext context) {
  return AppBar(
    centerTitle: true,
    automaticallyImplyLeading: false,
    title: Text(
      'Mapa de ocorrências',
      style: Theme.of(context).textTheme.titleLarge,
    ),
  );
}
