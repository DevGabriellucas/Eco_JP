import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'geovalidations.dart';

class OsmAddress {
  String street;
  String neighborhood;
  String district;
  String city;
  String state;
  String postalCode;

  OsmAddress({
    required this.street,
    required this.neighborhood,
    required this.district,
    required this.city,
    required this.state,
    required this.postalCode,
  });
}

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

  /// Resolve a posição aproximada de um bairro de João Pessoa pelo nome,
  /// usando o geocodificador do aparelho. Retorna `null` quando não há
  /// resultado, não há suporte (web) ou ocorre erro de rede.
  Future<LatLng?> geocodeBairro(String bairro) async {
    final chave = bairro.toLowerCase().trim();

    final emCache = _cacheBairro[chave];
    if (emCache != null) return emCache;

    try {
      final locais = await locationFromAddress(
        '$bairro, João Pessoa, Paraíba, Brasil',
      );
      if (locais.isEmpty) return null;

      final local = locais.first;
      final latLng = LatLng(local.latitude, local.longitude);
      _cacheBairro[chave] = latLng;
      return latLng;
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

  //Obtém em a posição atual em objeto Placemark(Que tem mais dados).
  Future<PlacemarkResult> getCurrentPlacemark() async {
    final positionResult = await _requestPermissionAndGetPosition();

    switch (positionResult) {
      case PositionSucess(:final position):
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isEmpty) {
          return PlacemarkFailure(
            'Nenhum endereço encontrado para as coordenadas.',
          );
        }

        return PlacemarkSucess(placemarks.first);

      case PositionFailure(:final error):
        return PlacemarkFailure(error);
    }
  }

  //Obtém a posição atual em String.
  Future<StringResult> getCurrentFormattedAddress() async {
    final positionResult = await _requestPermissionAndGetPosition();

    switch (positionResult) {
      case PositionSucess(:final position):
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isEmpty) {
          return StringFailure(
            'Nenhum endereço encontrado para as coordenadas.',
          );
        }

        return StringSucess(_formatAddress(placemarks.first));

      case PositionFailure(:final error):
        return StringFailure(error);
    }
  }

  //Retorna uma lista de Endereços.
  Future<List<OsmAddress>> searchAddressSuggestions(String searchQuery) async {
    /*
    IMPORTANTE
    Para evitar que o app faça uma requisição a cada letra digitada, você pode usar um Debouncer na sua tela (na Controller ou no onChange do seu TextField). O objetivo dele é: esperar o usuário parar de digitar por 500 milissegundos antes de disparar a função.
    */

    if (searchQuery.trim().isEmpty) return [];

    final List<OsmAddress> addressSuggestions = [];

    final encodedQuery = Uri.encodeComponent(searchQuery);
    final url =
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&countrycodes=br&addressdetails=1&limit=4&format=jsonv2';

    try {
      // Requisição com timeout de 10 segundos
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'EcoJP'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('Erro na requisição HTTP!');
        return [];
      }

      final decodedData = jsonDecode(response.body);
      if (decodedData == null) return [];

      for (var item in decodedData) {
        final addressData = item['address'] ?? {};

        final street = addressData['road'] ?? '';
        final neighborhood =
            addressData['suburb'] ?? addressData['neighbourhood'] ?? '';
        final district = addressData['district'] ?? '';
        final city =
            addressData['city'] ??
            addressData['town'] ??
            addressData['village'] ??
            '';
        final state = addressData['state'] ?? '';
        final postalCode = addressData['postcode'] ?? '';

        addressSuggestions.add(
          OsmAddress(
            street: street,
            neighborhood: neighborhood,
            district: district,
            city: city,
            state: state,
            postalCode: postalCode,
          ),
        );
      }
    } on TimeoutException catch (_) {
      debugPrint(
        'Erro: A requisição demorou demais e foi cancelada (Timeout).',
      );
      return [];
    } catch (e) {
      debugPrint('Erro ao buscar sugestões: $e');
      return [];
    }

    for (var address in addressSuggestions) {
      debugPrint('Rua encontrada: ${address.street}');
    }

    return addressSuggestions;
  }

  String _formatAddress(Placemark mark) {
    final street = mark.street?.isNotEmpty == true ? mark.street! : '-';
    final number = mark.subThoroughfare?.isNotEmpty == true
        ? mark.subThoroughfare!
        : '-';
    final neighborhood = mark.subAdministrativeArea?.isNotEmpty == true
        ? mark.subAdministrativeArea!
        : '-';

    return '$street, $number - $neighborhood';
  }
}
