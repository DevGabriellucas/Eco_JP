import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:eco_jp/utils/texto.dart';

/// Coordenadas centrais conferidas dos principais bairros de João Pessoa (PB).
///
/// Tanto os "pontos" aproximados do cronograma (assets/data/rotas_coleta.json)
/// quanto o geocodificador do aparelho erram a posição de vários bairros — ex.:
/// Altiplano caía atrás do Shopping Mangabeira e Bessa perto do Aeroclube.
/// Esta tabela tem prioridade na busca por bairro para o mapa centralizar no
/// lugar certo. As chaves já estão normalizadas (sem acento, minúsculas).
const Map<String, LatLng> _coordenadasBairros = {
  // ── Orla / leste ────────────────────────────────────────────────────────
  'bessa': LatLng(-7.0745, -34.8395),
  'jardim oceania': LatLng(-7.0855, -34.8365),
  'jardim aeroclube': LatLng(-7.0895, -34.8390),
  'aeroclube': LatLng(-7.0895, -34.8390),
  'manaira': LatLng(-7.0975, -34.8370),
  'brisamar': LatLng(-7.1015, -34.8360),
  'tambau': LatLng(-7.1140, -34.8340),
  'cabo branco': LatLng(-7.1490, -34.8050),
  'altiplano': LatLng(-7.1405, -34.8240),
  'portal do sol': LatLng(-7.1560, -34.8150),
  'seixas': LatLng(-7.1525, -34.7975),
  'penha': LatLng(-7.1640, -34.7965),

  // ── Centro / central ──────────────────────────────────────────────────────
  'miramar': LatLng(-7.1095, -34.8445),
  'bairro dos estados': LatLng(-7.1165, -34.8480),
  'expedicionarios': LatLng(-7.1130, -34.8540),
  'centro': LatLng(-7.1190, -34.8775),
  'jaguaribe': LatLng(-7.1240, -34.8650),
  'torre': LatLng(-7.1290, -34.8575),
  'tambauzinho': LatLng(-7.1265, -34.8490),
  'pedro gondim': LatLng(-7.1225, -34.8520),
  'bairro dos ipes': LatLng(-7.1330, -34.8430),
  'mandacaru': LatLng(-7.1230, -34.8720),
  'alto do mateus': LatLng(-7.1380, -34.8940),
  'cruz das armas': LatLng(-7.1450, -34.8830),

  // ── Sul / UFPB e adjacências ──────────────────────────────────────────────
  'bancarios': LatLng(-7.1430, -34.8215),
  'castelo branco': LatLng(-7.1385, -34.8465),
  'jardim cidade universitaria': LatLng(-7.1380, -34.8450),
  'anatolia': LatLng(-7.1500, -34.8430),
  'jardim sao paulo': LatLng(-7.1640, -34.8470),
  'cristo redentor': LatLng(-7.1555, -34.8665),
  'jose americo': LatLng(-7.1760, -34.8370),
  'agua fria': LatLng(-7.1720, -34.8520),
  'ernesto geisel': LatLng(-7.1850, -34.8640),
  'cuia': LatLng(-7.1950, -34.8510),
  'valentina de figueiredo': LatLng(-7.2090, -34.8540),
  'valentina': LatLng(-7.2090, -34.8540),
  'mangabeira': LatLng(-7.2050, -34.8400),
};

/// Coordenada central conferida de um bairro de João Pessoa, ignorando
/// acentos e caixa. Retorna `null` quando o bairro não está na tabela (o
/// chamador então recorre ao cronograma ou ao geocodificador).
LatLng? coordenadaBairroJP(String bairro) {
  final chave = removerAcentos(bairro).toLowerCase().trim();
  return _coordenadasBairros[chave];
}
