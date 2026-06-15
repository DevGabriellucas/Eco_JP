import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/rota_coleta_model.dart';

/// Carrega o cronograma de coleta domiciliar a partir do asset local
/// `assets/data/rotas_coleta.json`.
///
/// O JSON é organizado em grupos (frequência + turno); este serviço "achata"
/// os grupos em uma lista de [RotaColetaModel] (uma entrada por bairro/grupo).
///
/// É uma agenda fixa (não muda em tempo de execução), então o resultado é
/// cacheado em memória após a primeira leitura — evita reabrir e reparsear
/// o JSON a cada vez que o usuário usa a camada ou a busca.
class RotaColetaService {
  static List<RotaColetaModel>? _cache;

  Future<List<RotaColetaModel>> carregarRotas() async {
    final cache = _cache;
    if (cache != null) return cache;

    final raw = await rootBundle.loadString('assets/data/rotas_coleta.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final rotas = <RotaColetaModel>[];
    for (final grupo in json['grupos'] as List) {
      final grupoMap = grupo as Map<String, dynamic>;
      for (final bairro in grupoMap['bairros'] as List) {
        rotas.add(
          RotaColetaModel.fromGrupoBairro(
            grupoMap,
            bairro as Map<String, dynamic>,
          ),
        );
      }
    }

    _cache = rotas;
    return rotas;
  }
}
