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

  // launchUrl direto, sem canLaunchUrl antes: a checagem depende das
  // <queries> do AndroidManifest e dá falso negativo quando falta alguma.
  // launchUrl devolve false (ou lança) quando nada abre a URL.
  if (await _tentarAbrir(uri)) return true;
  // Fallback: esquema geo: (alguns dispositivos sem Google Maps).
  final q =
      rotulo == null ? destino : '$destino(${Uri.encodeComponent(rotulo)})';
  return _tentarAbrir(Uri.parse('geo:$destino?q=$q'));
}

Future<bool> _tentarAbrir(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Erro ao abrir $uri: $e');
    return false;
  }
}
