import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geovalidations.dart';

class LocationService {
  /// Cache em memória das coordenadas já resolvidas por bairro (compartilhado
  /// entre instâncias). A localização de um bairro não muda durante a sessão,
  /// então evitamos repetir a chamada de geocodificação.
  static final Map<String, LatLng> _cacheBairro = {};

  /// Resolve a posição aproximada de um bairro de João Pessoa pelo nome.
  /// Retorna `null` quando não há resultado, o resultado cai fora de João Pessoa,
  /// não há suporte (web) ou ocorre erro de rede.
  Future<LatLng?> geocodeBairro(String bairro) async {
    final chave = bairro.toLowerCase().trim();
    final emCache = _cacheBairro[chave];
    if (emCache != null) return emCache;
    return null;
  }

  Future<PositionResult> _requestPermissionAndGetPosition() async {
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      return PositionFailure('Ligue sua localização!');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return PositionFailure('Localização negada!');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await GeolocatorPlatform.instance.openLocationSettings();
      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return PositionFailure('Localização negada permanentemente!');
      }
    }

    return PositionSucess(await Geolocator.getCurrentPosition());
  }

  //Obtém a posição atual LatLng(Class de latitude e longitude do GoogleMaps).
  Future<LatLngResult> getCurrentLatLng() async {
    final positionResult = await _requestPermissionAndGetPosition();

    switch (positionResult) {
      case PositionSucess(:final position):
        return LatLngSucess(LatLng(position.latitude, position.longitude));
      case PositionFailure(:final error):
        return LatLngFailure(error);
    }
  }
}
