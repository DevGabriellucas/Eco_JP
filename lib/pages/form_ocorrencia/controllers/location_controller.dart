import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/geolocation/geocoding_service.dart';

/// Estado e lógica da localização de uma denúncia: campo de endereço,
/// autocomplete (texto/CEP), seleção de sugestão, GPS e resolução final das
/// coordenadas para o envio.
///
/// Dono do [TextEditingController] e do [FocusNode] do endereço. Não conhece
/// UI: publica mudanças via [notifyListeners] e devolve mensagens de erro para
/// a página exibir. O [GeocodingService] é injetável para testes.
class LocationController extends ChangeNotifier {
  LocationController({required GeocodingService geo}) : _geo = geo;

  final GeocodingService _geo;

  final TextEditingController enderecoCtrl = TextEditingController();
  final FocusNode enderecoFocus = FocusNode();

  double? latitude;
  double? longitude;

  // Autocomplete.
  List<EnderecoSugestao> sugestoes = [];
  bool buscandoSug = false;
  bool mostrarSug = false;

  bool loadingLoc = false;

  Timer? _debounce;
  bool _disposed = false;

  String get endereco => enderecoCtrl.text.trim();

  bool get coordenadasConfirmadas => coordenadaValida(latitude, longitude);

  static bool coordenadaValida(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return false;
    return lat != 0 && lon != 0;
  }

  void onEnderecoChanged(String v) {
    if (mostrarSug || latitude != null || longitude != null) {
      mostrarSug = false;
      latitude = null;
      longitude = null;
      notifyListeners();
    }
    _debounce?.cancel();
    final texto = v.trim();
    // Autocomplete com 2+ caracteres (CEP, bairro, rua): mais rápido e útil.
    if (texto.length < 2) {
      sugestoes = [];
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_geo.pareceCep(texto)) {
        _buscarPorCep(texto);
      } else {
        _buscarSugestoes(texto);
      }
    });
  }

  Future<void> _buscarSugestoes(String q) async {
    buscandoSug = true;
    notifyListeners();
    try {
      final list = await _geo.autocomplete(q);
      if (_disposed) return;
      sugestoes = list;
      mostrarSug = list.isNotEmpty;
      notifyListeners();
    } finally {
      if (!_disposed) {
        buscandoSug = false;
        notifyListeners();
      }
    }
  }

  // Busca um endereço pelo CEP (ViaCEP) e resolve as coordenadas no Nominatim.
  Future<void> _buscarPorCep(String cep) async {
    final list = await _geo.buscarPorCep(cep);
    if (_disposed) return;
    sugestoes = list;
    mostrarSug = list.isNotEmpty;
    notifyListeners();
  }

  void selecionarSugestao(EnderecoSugestao s) {
    enderecoCtrl.text = s.descricao;
    latitude = s.lat;
    longitude = s.lon;
    sugestoes = [];
    mostrarSug = false;
    notifyListeners();
    enderecoFocus.unfocus();
  }

  /// Fecha o teclado sem apagar as sugestões (para o usuário lê-las e tocá-las
  /// depois de tirar o foco).
  void aoTocarFora() {
    if (enderecoFocus.hasFocus) enderecoFocus.unfocus();
  }

  /// Usa o GPS do dispositivo, preenchendo endereço + coordenadas. Retorna uma
  /// mensagem de erro para exibir, ou `null` em caso de sucesso.
  Future<String?> usarLocalizacaoAtual() async {
    loadingLoc = true;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Ative o GPS do dispositivo.';
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          return 'Permissão negada.';
        }
      }
      if (perm == LocationPermission.deniedForever) {
        return 'Permissão bloqueada nas configurações.';
      }
      if (_disposed) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (_disposed) return null;

      final addr = await _geo.reverseGeocode(pos.latitude, pos.longitude);
      if (_disposed) return null;
      latitude = pos.latitude;
      longitude = pos.longitude;
      enderecoCtrl.text = addr;
      mostrarSug = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Localização: $e');
      return 'Erro ao obter localização.';
    } finally {
      if (!_disposed) {
        loadingLoc = false;
        notifyListeners();
      }
    }
  }

  /// Garante coordenadas para o envio: usa as já resolvidas (sugestão/GPS) ou
  /// geocodifica o texto do endereço. Retorna (lat, lon) — podem ser `null`.
  Future<(double?, double?)> resolverCoordenadas() async {
    if (latitude != null && longitude != null) {
      return (latitude, longitude);
    }
    final coord = await _geo.geocodificar(endereco);
    return (coord?.$1, coord?.$2);
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    enderecoCtrl.dispose();
    enderecoFocus.dispose();
    super.dispose();
  }
}
