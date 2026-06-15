import 'dart:async';

import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/models/rota_coleta_model.dart';
import 'package:eco_jp/services/geolocation/geolocation_service.dart';
import 'package:eco_jp/services/ocorrencia_service.dart';
import 'package:eco_jp/services/rota_coleta_service.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:eco_jp/utils/texto.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:eco_jp/pages/mapPage/controller/calc_mostaffectedzones.dart';
import 'package:eco_jp/pages/mapPage/controller/marker_icons.dart';

abstract class MapControllerState {}

class MapControllerStateInit extends MapControllerState {}

class MapControllerStateLoading extends MapControllerState {}

class MapControllerStateLoaded extends MapControllerState {
  final List<OcorrenciaModel> listaDeOcorrencias;

  MapControllerStateLoaded(this.listaDeOcorrencias);
}

class MapControllerStateError extends MapControllerState {
  final String errorMsg;

  MapControllerStateError(this.errorMsg);
}

class MapController extends ChangeNotifier {
  MapController({this.aoTocarMarcador, this.aoTocarRotaColeta});

  /// Disparado quando o usuário toca em um marcador individual no mapa.
  void Function(OcorrenciaModel ocorrencia)? aoTocarMarcador;

  /// Disparado quando o usuário toca em uma rota de coleta no mapa.
  void Function(RotaColetaModel rota)? aoTocarRotaColeta;

  final OcorrenciaService service = OcorrenciaService();
  final RotaColetaService _rotaColetaService = RotaColetaService();
  final LocationService _locationService = LocationService();

  /// Identificador do agrupador (clustering nativo do Google Maps).
  static const ClusterManagerId clusterManagerId = ClusterManagerId(
    'ocorrencias',
  );

  MapControllerState state = MapControllerStateInit();

  Set<Marker> listaMarcadores = {};

  // Fonte da verdade (todas as ocorrências) + filtros visuais do mapa.
  List<OcorrenciaModel> _todasOcorrencias = [];
  final Set<OccurrenceType> _categoriasOcultas = {};
  OccurrenceStatus? _statusSelecionado;

  // Ícones customizados por categoria (vazio = usa marcador padrão).
  Map<OccurrenceType, BitmapDescriptor> _icones = {};

  List<({String bairro, int quantidade})> zonasMaisAfetadas = [];

  StreamSubscription<List<OcorrenciaModel>>? _subscription;

  // ── Rotas de coleta de lixo (camada opcional, dados estáticos) ───────────

  bool mostrarRotasColeta = false;
  List<RotaColetaModel> _rotasColeta = [];
  Set<Polyline> _polylinesColeta = {};

  // Bairro localizado pela busca: círculo de área aproximada + alvo de câmera
  // (consumido pela view, que detém o GoogleMapController).
  Set<Circle> _circuloBairro = {};
  LatLng? _alvoCamera;
  int _alvoCameraToken = 0;
  String? bairroSelecionado;

  Set<Polyline> get polylinesColeta =>
      mostrarRotasColeta ? _polylinesColeta : {};

  Set<Circle> get circuloBairro => _circuloBairro;

  /// Ponto para o qual a câmera deve animar; muda de identidade a cada nova
  /// seleção. A view observa [alvoCameraToken] para saber quando reagir.
  LatLng? get alvoCamera => _alvoCamera;
  int get alvoCameraToken => _alvoCameraToken;

  /// Agendas (uma por grupo do cronograma) cadastradas para um bairro.
  List<RotaColetaModel> agendasDoBairro(String bairro) =>
      _rotasColeta.where((r) => r.bairro == bairro).toList();

  /// Nomes de bairro distintos, ordenados ignorando acentos.
  List<String> get bairrosOrdenados {
    final nomes = _rotasColeta.map((r) => r.bairro).toSet().toList();
    nomes.sort(
      (a, b) => removerAcentos(
        a,
      ).toLowerCase().compareTo(removerAcentos(b).toLowerCase()),
    );
    return nomes;
  }

  // ── Estado dos filtros (consultado pela UI) ──────────────────────────────

  bool categoriaVisivel(OccurrenceType tipo) =>
      !_categoriasOcultas.contains(tipo);

  OccurrenceStatus? get statusSelecionado => _statusSelecionado;

  Future<void> loadOcorrencias() async {
    state = MapControllerStateLoading();
    notifyListeners();

    // Gera os ícones customizados uma única vez. Se falhar, _icones fica
    // vazio e criarMarcador() recorre ao marcador padrão.
    _icones = await MarkerIconFactory.carregar();

    try {
      _subscription?.cancel();

      _subscription = service.listarOcorrencias().listen(
        (data) {
          _todasOcorrencias = data;
          state = MapControllerStateLoaded(data);

          _recomputar();

          notifyListeners();
        },
        onError: (error) {
          state = MapControllerStateError(
            "Erro no carregamento das ocorrências",
          );

          notifyListeners();
        },
      );
    } catch (e) {
      state = MapControllerStateError("Erro no carregamento das ocorrências");

      notifyListeners();
    }
  }

  /// Carrega o cronograma (uma única vez) e monta as polylines dos bairros
  /// que têm área desenhável. Usado tanto pela camada do mapa quanto pela
  /// busca por bairro.
  Future<void> carregarRotasSeNecessario() async {
    if (_rotasColeta.isNotEmpty) return;

    _rotasColeta = await _rotaColetaService.carregarRotas();
    _polylinesColeta = {
      for (final rota in _rotasColeta.where((r) => r.temArea))
        Polyline(
          polylineId: PolylineId(rota.id),
          points: rota.pontos,
          color: rota.turno.color,
          width: 4,
          consumeTapEvents: true,
          onTap: () => aoTocarRotaColeta?.call(rota),
        ),
    };
  }

  /// Mostra/oculta a camada de rotas de coleta no mapa.
  Future<void> toggleRotasColeta() async {
    await carregarRotasSeNecessario();
    mostrarRotasColeta = !mostrarRotasColeta;
    notifyListeners();
  }

  /// Localiza um bairro no mapa: usa o centro de uma área conhecida quando há,
  /// senão geocodifica o nome no aparelho. Desenha um círculo de área
  /// aproximada e pede à view para centralizar a câmera.
  Future<void> selecionarBairro(String bairro) async {
    bairroSelecionado = bairro;

    LatLng? alvo;
    for (final agenda in agendasDoBairro(bairro)) {
      if (agenda.temArea) {
        alvo = agenda.centro;
        break;
      }
    }
    alvo ??= await _locationService.geocodeBairro(bairro);

    if (alvo != null) {
      _alvoCamera = alvo;
      _alvoCameraToken++;
      _circuloBairro = {
        Circle(
          circleId: const CircleId('bairro-selecionado'),
          center: alvo,
          radius: 450,
          strokeWidth: 2,
          strokeColor: AppColors.primary,
          fillColor: AppColors.primary.withValues(alpha: 0.12),
        ),
      };
    }

    notifyListeners();
  }

  // ── Filtros ──────────────────────────────────────────────────────────────

  void alternarCategoria(OccurrenceType tipo) {
    if (!_categoriasOcultas.remove(tipo)) {
      _categoriasOcultas.add(tipo);
    }
    _recomputar();
    notifyListeners();
  }

  /// Seleciona um status; tocar no status já ativo limpa o filtro.
  void selecionarStatus(OccurrenceStatus? status) {
    _statusSelecionado = _statusSelecionado == status ? null : status;
    _recomputar();
    notifyListeners();
  }

  List<OcorrenciaModel> get _ocorrenciasFiltradas {
    return _todasOcorrencias.where((o) {
      if (!_temCoordenadaValida(o)) return false;
      final tipo = OccurrenceTypeParser.fromString(o.tipoLixo);
      if (_categoriasOcultas.contains(tipo)) return false;
      if (_statusSelecionado != null &&
          OccurrenceStatusParser.fromString(o.status) != _statusSelecionado) {
        return false;
      }
      return true;
    }).toList();
  }

  void _recomputar() {
    listaMarcadores = {
      for (final ocorrencia in _ocorrenciasFiltradas) criarMarcador(ocorrencia),
    };

    // O ranking de bairros considera todas as ocorrências com coordenada
    // válida, independentemente dos filtros visuais aplicados no mapa.
    zonasMaisAfetadas = CalcMostAffectedZones(
      _todasOcorrencias.where(_temCoordenadaValida).toList(),
    ).zonasMaisAfetadas(limite: 3);
  }

  Marker criarMarcador(OcorrenciaModel ocorrencia) {
    final categoria = OccurrenceTypeParser.fromString(ocorrencia.tipoLixo);

    return Marker(
      markerId: MarkerId(ocorrencia.id),
      position: LatLng(ocorrencia.latitude, ocorrencia.longitude),
      icon:
          _icones[categoria] ??
          BitmapDescriptor.defaultMarkerWithHue(categoria.markerHue),
      clusterManagerId: clusterManagerId,
      infoWindow: InfoWindow(
        title: categoria.label,
        snippet: ocorrencia.titulo.isNotEmpty
            ? ocorrencia.titulo
            : ocorrencia.descricao,
      ),
      onTap: aoTocarMarcador == null
          ? null
          : () => aoTocarMarcador!(ocorrencia),
    );
  }

  bool _temCoordenadaValida(OcorrenciaModel o) {
    final lat = o.latitude;
    final lon = o.longitude;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return false;
    return lat != 0 && lon != 0;
  }

  /// Limites geográficos que enquadram todos os marcadores visíveis.
  /// Retorna `null` quando não há marcadores.
  LatLngBounds? get boundsDosMarcadores {
    if (listaMarcadores.isEmpty) return null;

    final posicoes = listaMarcadores.map((m) => m.position);
    var minLat = posicoes.first.latitude;
    var maxLat = posicoes.first.latitude;
    var minLng = posicoes.first.longitude;
    var maxLng = posicoes.first.longitude;

    for (final p in posicoes) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
