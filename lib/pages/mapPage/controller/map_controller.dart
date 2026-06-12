import 'dart:async';

import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/services/ocorrencia_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'calc_mostaffectedzones.dart';

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
  MapControllerState state = MapControllerStateInit();

  final OcorrenciaService service = OcorrenciaService();

  Set<Marker> listaMarcadores = {};

  ({String bairro, int quantidade}) zonaMaisAfetada = (
    bairro: '',
    quantidade: 0,
  );

  StreamSubscription<List<OcorrenciaModel>>? _subscription;

  Future<void> loadOcorrencias() async {
    state = MapControllerStateLoading();
    notifyListeners();

    try {
      _subscription?.cancel();

      _subscription = service.listarOcorrencias().listen(
        (data) {
          state = MapControllerStateLoaded(data);

          _loadMarcadores(data);
          _loadBairroMaisFrequente(data);

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

  Marker criarMarcador(OcorrenciaModel ocorrencia) {
    final categoria = OccurrenceTypeParser.fromString(ocorrencia.tipoLixo);

    return Marker(
      markerId: MarkerId(ocorrencia.id),
      position: LatLng(ocorrencia.latitude, ocorrencia.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(categoria.markerHue),
      infoWindow: InfoWindow(
        title: categoria.label,
        snippet: ocorrencia.descricao,
      ),
    );
  }

  void _loadMarcadores(List<OcorrenciaModel> ocorrencias) {
    // Recria o conjunto (novo objeto) para o GoogleMap detectar a mudança
    // — assim, ao excluir uma denúncia, o marcador some do mapa.
    // Ignora denúncias sem coordenada válida (lat/lon 0) para não cair no oceano.
    listaMarcadores = {
      for (final ocorrencia in ocorrencias)
        if (_temCoordenadaValida(ocorrencia)) criarMarcador(ocorrencia),
    };
  }

  bool _temCoordenadaValida(OcorrenciaModel o) {
    final lat = o.latitude;
    final lon = o.longitude;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return false;
    return lat != 0 && lon != 0;
  }

  void _loadBairroMaisFrequente(List<OcorrenciaModel> ocorrencias) {
    CalcMostAffectedZones calculo = CalcMostAffectedZones(ocorrencias);
    zonaMaisAfetada = calculo.bairroMaisFrequente();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
