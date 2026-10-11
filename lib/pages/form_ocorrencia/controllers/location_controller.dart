import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/geolocation/area_municipio.dart';
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

  /// Bairro estruturado vindo do provedor (sugestão, CEP ou GPS). Gravado na
  /// denúncia: o ranking de bairros deixa de depender de recortar o texto
  /// do endereço.
  String? bairro;

  // Autocomplete.
  List<EnderecoSugestao> sugestoes = [];
  bool buscandoSug = false;
  bool mostrarSug = false;

  bool loadingLoc = false;

  Timer? _debounce;
  bool _disposed = false;

  String get endereco => enderecoCtrl.text.trim();

  /// Último endereço vindo do GPS, para trocar pela versão sem número.
  EnderecoReverso? _enderecoGps;

  /// Texto gravado na denúncia. Anônima com o endereço do GPS ainda intacto
  /// sai sem o número da casa: as coordenadas já são arredondadas, mas
  /// "Rua X, 123" apontava a posição exata do denunciante. Endereço digitado
  /// ou escolhido nas sugestões fica como a pessoa escreveu.
  String enderecoPublico({required bool anonima}) {
    final gps = _enderecoGps;
    if (anonima && gps != null && endereco == gps.endereco) {
      return gps.enderecoSemNumero;
    }
    return endereco;
  }

  bool get coordenadasConfirmadas => coordenadaValida(latitude, longitude);

  /// Coordenada dentro de João Pessoa (mesmos limites das regras).
  static bool coordenadaValida(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    return AreaMunicipio.contem(lat, lon);
  }

  void onEnderecoChanged(String v) {
    if (mostrarSug || latitude != null || longitude != null) {
      mostrarSug = false;
      latitude = null;
      longitude = null;
      bairro = null;
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
    bairro = s.bairro;
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
        // Leva direto às permissões do app (antes abria a tela do GPS, que
        // não resolve uma permissão negada para sempre).
        await Geolocator.openAppSettings();
        return 'Permita o acesso à localização nas configurações do app.';
      }
      if (_disposed) return null;

      // O que estava digitado quando o GPS começou: se a pessoa editar o
      // campo enquanto espera, o resultado não sobrescreve o que ela digitou.
      final textoAntes = enderecoCtrl.text;

      final Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      } on TimeoutException {
        // Ambiente fechado: sem fix de GPS em tempo útil.
        return 'Não foi possível obter sua localização. Digite o endereço.';
      }
      if (_disposed) return null;
      if (!coordenadaValida(pos.latitude, pos.longitude)) {
        return 'Sua localização está fora de João Pessoa. Digite o endereço '
            'da ocorrência.';
      }

      final addr = await _geo.reverseGeocode(pos.latitude, pos.longitude);
      if (_disposed) return null;
      if (enderecoCtrl.text != textoAntes) return null;
      return aplicarPosicaoGps(pos.latitude, pos.longitude, addr);
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

  /// Texto do campo quando o GPS deu a posição, mas nenhum provedor achou o
  /// nome da rua.
  static const textoSemEndereco = 'Minha localização atual, João Pessoa';

  /// Aplica uma posição do GPS já validada. Devolve um aviso para a página
  /// ou `null`.
  ///
  /// A coordenada do GPS vale mesmo sem endereço: antes, se o reverso
  /// falhava, a posição era descartada e o campo ficava com um texto de erro
  /// que a pessoa precisava apagar à mão.
  @visibleForTesting
  String? aplicarPosicaoGps(double lat, double lon, EnderecoReverso? addr) {
    latitude = lat;
    longitude = lon;
    bairro = addr?.bairro;
    _enderecoGps = addr;
    enderecoCtrl.text = addr?.endereco ?? textoSemEndereco;
    sugestoes = [];
    mostrarSug = false;
    notifyListeners();
    if (addr != null) return null;
    return 'Localização confirmada, mas não achamos o nome da rua. Se quiser, '
        'escreva um ponto de referência na descrição.';
  }

  /// Esvazia o campo de endereço e a localização resolvida (botão "x").
  void limparEndereco() {
    _debounce?.cancel();
    enderecoCtrl.clear();
    latitude = null;
    longitude = null;
    bairro = null;
    sugestoes = [];
    mostrarSug = false;
    notifyListeners();
    enderecoFocus.requestFocus();
  }

  /// Garante coordenadas para o envio: usa as já resolvidas (sugestão/GPS) ou
  /// geocodifica o texto do endereço. Retorna (lat, lon) — podem ser `null`.
  Future<(double?, double?)> resolverCoordenadas() async {
    if (latitude != null && longitude != null) {
      return (latitude, longitude);
    }
    final coord = await _geo.geocodificar(endereco);
    // Endereço digitado sem escolher sugestão: o bairro vem do reverso das
    // coordenadas encontradas (best-effort; sem ele a denúncia vai sem).
    if (coord != null && bairro == null) {
      bairro = (await _geo.reverseGeocode(coord.$1, coord.$2))?.bairro;
    }
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
