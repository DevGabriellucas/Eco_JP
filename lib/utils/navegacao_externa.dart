import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre o app de mapas do dispositivo (Google Maps, Waze ou equivalente) com
/// uma rota até as coordenadas informadas, partindo da localização atual.
///
/// Usa a URL universal do Google Maps Directions, que o Android e o iOS
/// reconhecem e abrem no app de mapas instalado. Retorna `false` se não foi
/// possível abrir nenhum app de mapas.
Future<bool> abrirRotaNoMapa({
  required double latitude,
  required double longitude,
  String? rotulo,
}) async {
  final destino = '$latitude,$longitude';
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destino,
    'travelmode': 'driving',
  });

  try {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // Fallback: esquema geo: (alguns dispositivos sem Google Maps).
    final geo = Uri.parse('geo:$destino?q=$destino${rotulo != null ? '($rotulo)' : ''}');
    if (await canLaunchUrl(geo)) {
      return launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    return false;
  } catch (e) {
    debugPrint('Erro ao abrir rota no mapa: $e');
    return false;
  }
}
