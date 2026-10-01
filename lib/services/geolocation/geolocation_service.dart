import 'dart:async';

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
    try {
      return await _obterPosicao();
    } catch (e) {
      // Sem try/catch, uma exceção do plugin deixava o mapa em spinner eterno.
      return PositionFailure('Não foi possível obter sua localização.');
    }
  }

  Future<PositionResult> _obterPosicao() async {
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
      // Permissão negada para sempre se resolve nas configurações do APP;
      // antes abria a tela do GPS, que não muda nada.
      await Geolocator.openAppSettings();
      return PositionFailure('Permita a localização nas configurações do app.');
    }

    try {
      return PositionSucess(
        await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      // Ambiente fechado: usa a última posição conhecida, se houver.
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) return PositionSucess(ultima);
      return PositionFailure('Não foi possível obter sua localização.');
    }
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
