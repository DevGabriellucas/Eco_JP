import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../utils/texto.dart';
import 'area_municipio.dart';

/// Sugestão de endereço para o autocomplete do formulário de denúncia.
class EnderecoSugestao {
  final String descricao;
  final double? lat;
  final double? lon;

  /// Bairro estruturado, quando o provedor devolve (Photon, Nominatim,
  /// ViaCEP). Gravado na denúncia para o ranking de bairros.
  final String? bairro;

  const EnderecoSugestao({
    required this.descricao,
    this.lat,
    this.lon,
    this.bairro,
  });
}

/// Resultado do geocode reverso (GPS → endereço).
class EnderecoReverso {
  final String endereco;
  final String? bairro;

  /// [endereco] sem o número da casa. Vai no lugar dele em denúncia anônima:
  /// a posição do GPS costuma ser a do próprio denunciante.
  final String enderecoSemNumero;

  const EnderecoReverso({
    required this.endereco,
    this.bairro,
    String? enderecoSemNumero,
  }) : enderecoSemNumero = enderecoSemNumero ?? endereco;
}

/// Geocoding de endereços para o formulário de denúncia:
/// autocomplete (Google Places → Photon), busca por CEP (ViaCEP),
/// geocode direto e reverso (Nominatim).
///
/// Todas as buscas ficam restritas a João Pessoa ([AreaMunicipio]).
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

  static const _timeout = Duration(seconds: 8);

  // A política do Nominatim exige identificar o app em toda requisição.
  static const _headers = {
    'User-Agent': 'EcoJP/1.0 (app de denuncias ambientais de Joao Pessoa)',
  };

  /// Detecta se o texto digitado é um CEP (8 dígitos, com ou sem hífen).
  bool pareceCep(String texto) {
    return RegExp(r'^\d{5}-?\d{3}$').hasMatch(texto.trim());
  }

  /// Autocomplete com 3 estratégias:
  /// 1. CEP → buscarPorCep (ViaCEP)
  /// 2. Google Places (com chave) ou Photon
  /// 3. Fallback → aceita qualquer texto se nada encontrar
  Future<List<EnderecoSugestao>> autocomplete(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return const [];

    // Estratégia 1: Se for CEP, busca direto
    if (pareceCep(trimmed)) {
      return await buscarPorCep(trimmed);
    }

    // Estratégia 2: Google Places ou Photon. O Nominatim não é usado aqui:
    // a política de uso do OSM proíbe autocomplete (uma busca por tecla).
    final resultados = _googleKey.isNotEmpty
        ? await _buscarGooglePlaces(trimmed)
        : await _buscarPhoton(trimmed);

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
          'input': '$q, ${AreaMunicipio.sufixoBusca}',
          'components': 'country:br',
          'location': '-7.1153,-34.8641',
          'radius': '20000',
          'strictbounds': 'true',
          'language': 'pt-BR',
          'key': _googleKey,
        },
      );
      final res = await _client.get(uri).timeout(_timeout);
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
      return _buscarPhoton(q);
    }
  }

  /// Photon (komoot): geocoder sobre dados do OSM feito para autocomplete.
  Future<List<EnderecoSugestao>> _buscarPhoton(String q) async {
    try {
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': q,
        'limit': '10',
        'bbox': AreaMunicipio.bboxPhoton,
      });
      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return const [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final seen = <String>{};
      final list = <EnderecoSugestao>[];
      for (final raw in data['features'] as List<dynamic>? ?? const []) {
        final feature = raw as Map<String, dynamic>;
        final coords = (feature['geometry'] as Map?)?['coordinates'] as List?;
        if (coords == null || coords.length < 2) continue;
        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        if (!AreaMunicipio.contem(lat, lon)) continue;

        final p = feature['properties'] as Map<String, dynamic>? ?? const {};
        final rua = (p['street'] ?? p['name'])?.toString() ?? '';
        final numero = p['housenumber']?.toString() ?? '';
        final bairro = (p['district'] ?? p['locality'])?.toString();
        final partes = [
          if (rua.isNotEmpty) numero.isEmpty ? rua : '$rua, $numero',
          if (bairro != null && bairro.isNotEmpty) bairro,
          'João Pessoa',
        ];
        final desc = partes.join(', ');
        if (!seen.add(desc)) continue;
        list.add(
          EnderecoSugestao(descricao: desc, lat: lat, lon: lon, bairro: bairro),
        );
      }
      return list;
    } catch (e) {
      debugPrint('Photon: $e');
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
          .timeout(_timeout);
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

      // Resolve lat/lon do endereço retornado pelo CEP (null se cair fora
      // de João Pessoa).
      final coord = await geocodificar('$descricao, $uf');
      return [
        EnderecoSugestao(
          descricao: descricao,
          lat: coord?.$1,
          lon: coord?.$2,
          bairro: bairro.isEmpty ? null : bairro,
        ),
      ];
    } catch (e) {
      debugPrint('ViaCEP: $e');
      return const [];
    }
  }

  /// Geocodifica um endereço em texto para coordenadas (lat, lon) dentro de
  /// João Pessoa, ou `null`. Acrescenta a cidade ao texto e limita a busca à
  /// área do município — antes "Centro" pegava o primeiro Centro do Brasil.
  Future<(double, double)?> geocodificar(String endereco) async {
    final texto = endereco.trim();
    if (texto.isEmpty) return null;
    final q = removerAcentos(texto).toLowerCase().contains('joao pessoa')
        ? texto
        : '$texto, ${AreaMunicipio.sufixoBusca}';
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'countrycodes': 'br',
        'limit': '1',
        'format': 'jsonv2',
        'accept-language': 'pt-BR',
        'viewbox': AreaMunicipio.viewboxNominatim,
        'bounded': '1',
      });
      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as List<dynamic>;
      if (data.isEmpty) return null;
      final item = data.first as Map<String, dynamic>;
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      if (!AreaMunicipio.contem(lat, lon)) return null;
      return (lat, lon);
    } catch (e) {
      debugPrint('Geocodificar: $e');
      return null;
    }
  }

  /// Endereço legível (e bairro) a partir de coordenadas: Nominatim e, se ele
  /// falhar ou não trouxer nada útil, Photon. `null` se nenhum resolveu —
  /// antes devolvia o texto "Endereço não encontrado", que acabava gravado
  /// como endereço e contado como bairro no ranking.
  Future<EnderecoReverso?> reverseGeocode(double lat, double lng) async {
    return await _reversoNominatim(lat, lng) ?? await _reversoPhoton(lat, lng);
  }

  Future<EnderecoReverso?> _reversoNominatim(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'addressdetails': '1',
        'accept-language': 'pt-BR',
      });
      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = data['address'];
      if (addr is! Map<String, dynamic>) return null;
      return _montarReverso(
        rua: _primeiro(addr, _chavesRua),
        numero: addr['house_number']?.toString(),
        bairro: _primeiro(addr, _chavesBairro),
        cidade: _primeiro(addr, _chavesCidade),
      );
    } catch (e) {
      debugPrint('reverseGeocode (Nominatim) falhou: $e');
      return null;
    }
  }

  Future<EnderecoReverso?> _reversoPhoton(double lat, double lng) async {
    try {
      final uri = Uri.https('photon.komoot.io', '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'limit': '1',
      });
      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? const [];
      if (features.isEmpty) return null;
      final p = (features.first as Map<String, dynamic>)['properties']
              as Map<String, dynamic>? ??
          const {};
      return _montarReverso(
        rua: (p['street'] ?? p['name'])?.toString(),
        numero: p['housenumber']?.toString(),
        bairro: (p['district'] ?? p['locality'])?.toString(),
        cidade: p['city']?.toString(),
      );
    } catch (e) {
      debugPrint('reverseGeocode (Photon) falhou: $e');
      return null;
    }
  }

  /// Só a cidade não serve de endereço: sem rua nem bairro devolve `null` e
  /// quem chama decide o que mostrar.
  static EnderecoReverso? _montarReverso({
    String? rua,
    String? numero,
    String? bairro,
    String? cidade,
  }) {
    String? limpo(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    final r = limpo(rua);
    final n = limpo(numero);
    final b = limpo(bairro);
    if (r == null && b == null) return null;
    final resto = [
      if (b != null) b,
      limpo(cidade) ?? 'João Pessoa',
    ];
    return EnderecoReverso(
      endereco: [if (r != null) n == null ? r : '$r, $n', ...resto].join(', '),
      bairro: b,
      enderecoSemNumero: [if (r != null) r, ...resto].join(', '),
    );
  }

  static const _chavesRua = [
    'road',
    'pedestrian',
    'footway',
    'residential',
    'path',
  ];
  static const _chavesBairro = [
    'suburb',
    'neighbourhood',
    'quarter',
    'city_district',
  ];
  static const _chavesCidade = ['city', 'town', 'municipality'];

  static String? _primeiro(Map<String, dynamic> addr, List<String> chaves) {
    for (final chave in chaves) {
      final v = addr[chave]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }
}
