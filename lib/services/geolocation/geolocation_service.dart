import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geovalidations.dart';

class LocationService {
  LocationService() {
    // O plugin `geocoding` não tem implementação no navegador (web),
    // então a instância pode ser nula. Usamos `?.` para não quebrar a tela.
    GeocodingPlatform.instance?.setLocaleIdentifier('pt_BR');
  }

  /// Cache em memória das coordenadas já resolvidas por bairro (compartilhado
  /// entre instâncias). A localização de um bairro não muda durante a sessão,
  /// então evitamos repetir a chamada de geocodificação.
  static final Map<String, LatLng> _cacheBairro = {};

  /// Bounding box aproximado de João Pessoa (PB). O geocodificador do aparelho
  /// às vezes devolve uma cidade homônima em outro estado; descartamos esses
  /// resultados para o mapa não "pular" para o lugar errado.
  static bool _dentroDeJoaoPessoa(LatLng p) {
    return p.latitude >= -7.30 &&
        p.latitude <= -6.95 &&
        p.longitude >= -35.00 &&
        p.longitude <= -34.75;
  }

  /// Resolve a posição aproximada de um bairro de João Pessoa pelo nome,
  /// usando o geocodificador do aparelho. Retorna `null` quando não há
  /// resultado, o resultado cai fora de João Pessoa, não há suporte (web) ou
  /// ocorre erro de rede.
  Future<LatLng?> geocodeBairro(String bairro) async {
    final chave = bairro.toLowerCase().trim();

    final emCache = _cacheBairro[chave];
    if (emCache != null) return emCache;

    try {
      final locais = await locationFromAddress(
        '$bairro, João Pessoa, Paraíba, Brasil',
      );
      if (locais.isEmpty) return null;

      // Usa o primeiro resultado que de fato cai dentro de João Pessoa.
      for (final local in locais) {
        final latLng = LatLng(local.latitude, local.longitude);
        if (_dentroDeJoaoPessoa(latLng)) {
          _cacheBairro[chave] = latLng;
          return latLng;
        }
      }
      return null;
    } catch (_) {
      // Sem implementação no navegador, sem rede ou endereço não encontrado.
      return null;
    }
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
