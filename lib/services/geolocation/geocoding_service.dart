import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

/// Sugestão de endereço para o autocomplete do formulário de denúncia.
class EnderecoSugestao {
  final String descricao;
  final double? lat;
  final double? lon;

  const EnderecoSugestao({required this.descricao, this.lat, this.lon});
}

/// Geocoding de endereços para o formulário de denúncia:
/// autocomplete (Google Places → Nominatim), busca por CEP (ViaCEP),
/// geocode direto e reverso.
///
/// Isola o acesso HTTP e o provedor de geocoding, permitindo testes unitários
/// com um `http.Client` mockado (a UI apenas orquestra `setState`/debounce).
class GeocodingService {
  GeocodingService({http.Client? client, String? googleApiKey})
    : _client = client ?? http.Client(),
      _googleKey =
          googleApiKey ?? const String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  final http.Client _client;

  // Passe a key via: flutter run --dart-define=GOOGLE_MAPS_API_KEY=SUA_KEY
  final String _googleKey;

  /// Detecta se o texto digitado é um CEP (8 dígitos, com ou sem hífen).
  bool pareceCep(String texto) {
    return RegExp(r'^\d{5}-?\d{3}$').hasMatch(texto.trim());
  }

  /// Autocomplete robusto com 3 estratégias:
  /// 1. CEP → buscarPorCep (ViaCEP)
  /// 2. Nominatim → rua, endereço, bairro (tudo)
  /// 3. Fallback → aceita qualquer texto se nada encontrar
  Future<List<EnderecoSugestao>> autocomplete(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return const [];

    // Estratégia 1: Se for CEP, busca direto
    if (pareceCep(trimmed)) {
      return await buscarPorCep(trimmed);
    }

    // Estratégia 2: Usa Google Places ou Nominatim
    final resultados = _googleKey.isNotEmpty
        ? await _buscarGooglePlaces(trimmed)
        : await _buscarNominatim(trimmed);

    // Estratégia 3: Se não encontrou nada, retorna o texto como fallback
    // (usuário pode digitar manualmente e confirmar depois via geocodificação)
    if (resultados.isEmpty) {
      return [EnderecoSugestao(descricao: trimmed)];
    }

    return resultados;
  }

  Future<List<EnderecoSugestao>> _buscarGooglePlaces(String q) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': '$q, João Pessoa',
          'components': 'country:br',
          'location': '-7.1153,-34.8641',
          'radius': '50000',
          'language': 'pt-BR',
          'key': _googleKey,
        },
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // O autocomplete do Google não retorna lat/lon (só a descrição);
      // as coordenadas são resolvidas por geocodificação ao enviar.
      return (data['predictions'] as List<dynamic>? ?? [])
          .map((p) => p['description']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .map((desc) => EnderecoSugestao(descricao: desc))
          .toList();
    } catch (e) {
      debugPrint('Google Places: $e');
      return _buscarNominatim(q);
    }
  }

  Future<List<EnderecoSugestao>> _buscarNominatim(String q) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$q, João Pessoa',
        'countrycodes': 'br',
        'limit': '50',
        'format': 'jsonv2',
        'accept-language': 'pt-BR',
        'addressdetails': '1',
        // bounding box de João Pessoa para priorizar resultados locais
        'viewbox': '-34.98,-6.97,-34.78,-7.29',
        'bounded': '0',
      });
      final res = await _client
          .get(uri, headers: {'User-Agent': 'EcoJP/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];

      final data = jsonDecode(res.body) as List<dynamic>;
      final seen = <String>{};
      final list = <EnderecoSugestao>[];
      for (final raw in data) {
        final item = raw as Map<String, dynamic>;
        final desc = _formatarEnderecoNominatim(item);
        if (desc.isEmpty || !seen.add(desc)) continue;
        list.add(
          EnderecoSugestao(
            descricao: desc,
            lat: double.tryParse(item['lat']?.toString() ?? ''),
            lon: double.tryParse(item['lon']?.toString() ?? ''),
          ),
        );
      }
      return list;
    } catch (e) {
      debugPrint('Nominatim: $e');
      return const [];
    }
  }

  /// Busca um endereço pelo CEP (ViaCEP) e resolve as coordenadas no Nominatim.
  /// Retorna uma lista com 0 ou 1 sugestão.
  Future<List<EnderecoSugestao>> buscarPorCep(String cepRaw) async {
    final cep = cepRaw.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return const [];
    try {
      final res = await _client
          .get(Uri.https('viacep.com.br', '/ws/$cep/json/'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['erro'] == true || data['erro'] == 'true') return const [];

      final logradouro = data['logradouro']?.toString() ?? '';
      final bairro = data['bairro']?.toString() ?? '';
      final cidade = data['localidade']?.toString() ?? '';
      final uf = data['uf']?.toString() ?? '';

      final desc = [
        logradouro,
        bairro,
        cidade,
      ].where((s) => s.isNotEmpty).join(', ');
      final descricao = desc.isEmpty ? '$cidade - $uf' : desc;

      // Resolve lat/lon do endereço retornado pelo CEP.
      final coord = await geocodificar('$descricao, $uf');
      return [
        EnderecoSugestao(descricao: descricao, lat: coord?.$1, lon: coord?.$2),
      ];
    } catch (e) {
      debugPrint('ViaCEP: $e');
      return const [];
    }
  }

  /// Geocodifica um endereço em texto para coordenadas (lat, lon).
  Future<(double, double)?> geocodificar(String endereco) async {
    if (endereco.trim().isEmpty) return null;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': endereco,
        'countrycodes': 'br',
        'limit': '1',
        'format': 'jsonv2',
        'accept-language': 'pt-BR',
      });
      final res = await _client
          .get(uri, headers: {'User-Agent': 'EcoJP/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as List<dynamic>;
      if (data.isEmpty) return null;
      final item = data.first as Map<String, dynamic>;
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return (lat, lon);
    } catch (e) {
      debugPrint('Geocodificar: $e');
      return null;
    }
  }

  /// Endereço legível a partir de coordenadas. Tenta o plugin `geocoding`
  /// (placemark nativo) e cai para o Nominatim reverse.
  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
        ].where((s) => s != null && s.trim().isNotEmpty).take(3).join(', ');
        if (parts.isNotEmpty) return parts;
      }
    } catch (e) {
      // Geocoder da plataforma indisponível (ex.: web/sem rede): cai no Nominatim.
      debugPrint('reverseGeocode (placemark) falhou, tentando Nominatim: $e');
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'addressdetails': '1',
        'accept-language': 'pt-BR',
      });
      final res = await _client.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'];
        if (addr is Map<String, dynamic>) {
          final parts =
              [
                    addr['road'],
                    addr['neighbourhood'],
                    addr['suburb'],
                    addr['city'],
                  ]
                  .where((s) => s is String && s.trim().isNotEmpty)
                  .take(3)
                  .map((s) => s.toString())
                  .join(', ');
          if (parts.isNotEmpty) return parts;
        }
      }
    } catch (e) {
      // Sem endereço via Nominatim também: devolve o texto padrão abaixo.
      debugPrint('reverseGeocode (Nominatim) falhou: $e');
    }

    return 'Endereço não encontrado';
  }

  String _formatarEnderecoNominatim(Map<String, dynamic> item) {
    final addr = item['address'] as Map<String, dynamic>?;
    if (addr == null) {
      final display = item['display_name']?.toString() ?? '';
      return display.split(',').take(3).join(',').trim();
    }

    // Tenta montar: "Rua/Avenida + Número + Bairro + Cidade"
    final road =
        addr['road']?.toString() ??
        addr['pedestrian']?.toString() ??
        addr['footway']?.toString() ??
        addr['path']?.toString() ??
        addr['street']?.toString() ??
        '';
    final numero = addr['house_number']?.toString() ?? '';

    final bairro =
        addr['neighbourhood']?.toString() ??
        addr['suburb']?.toString() ??
        addr['quarter']?.toString() ??
        addr['city_district']?.toString() ??
        '';
    final cidade =
        addr['city']?.toString() ??
        addr['town']?.toString() ??
        addr['municipality']?.toString() ??
        '';

    final parts = <String>[];

    // Monta rua com número se houver
    if (road.isNotEmpty) {
      parts.add(numero.isNotEmpty ? '$road, $numero' : road);
    }

    if (bairro.isNotEmpty) parts.add(bairro);
    if (cidade.isNotEmpty && cidade != road) parts.add(cidade);

    if (parts.isEmpty) {
      final display = item['display_name']?.toString() ?? '';
      return display.split(',').take(2).join(',').trim();
    }
    return parts.join(', ');
  }
}
