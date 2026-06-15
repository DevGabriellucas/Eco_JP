import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/services/geolocation/geolocation_service.dart';
import 'package:eco_jp/services/geolocation/geovalidations.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:eco_jp/utils/google_maps_web_support.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapDisplay extends StatefulWidget {
  final MapController controller;

  const MapDisplay({super.key, required this.controller});

  @override
  State<MapDisplay> createState() => _MapDisplayState();
}

class _MapDisplayState extends State<MapDisplay> {
  final LocationService locationService = LocationService();

  GoogleMapController? _mapController;
  CameraPosition? cameraPosition;
  bool _jaEnquadrou = false;
  int _ultimoTokenCamera = 0;

  @override
  void initState() {
    super.initState();

    loadLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> loadLocation() async {
    final result = await locationService.getCurrentLatLng();

    switch (result) {
      case LatLngSucess(:final latLng):
        setState(() {
          cameraPosition = CameraPosition(target: latLng, zoom: 15);
        });

      case LatLngFailure():
        setState(() {
          cameraPosition = const CameraPosition(
            target: LatLng(-7.1195, -34.8450),
            zoom: 12,
          );
        });
    }
  }

  /// Anima a câmera para enquadrar todos os marcadores visíveis.
  Future<void> _enquadrarMarcadores() async {
    final bounds = widget.controller.boundsDosMarcadores;
    final mapController = _mapController;
    if (bounds == null || mapController == null) return;
    await mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  /// Centraliza o mapa na localização atual do usuário (botão próprio, no
  /// canto inferior esquerdo — substitui o botão nativo do Google Maps, que
  /// ficava sobre os filtros de status).
  Future<void> _irParaMinhaLocalizacao() async {
    final mapController = _mapController;
    if (mapController == null) return;

    final result = await locationService.getCurrentLatLng();
    switch (result) {
      case LatLngSucess(:final latLng):
        await mapController.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 16),
        );
      case LatLngFailure(:final error):
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isGoogleMapsWebReady) {
      return const _MapWebConfigMissing();
    }

    if (cameraPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final temMarcadores = widget.controller.listaMarcadores.isNotEmpty;

    // Enquadra automaticamente os marcadores na primeira carga.
    if (!_jaEnquadrou && temMarcadores && _mapController != null) {
      _jaEnquadrou = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enquadrarMarcadores();
      });
    }

    // Centraliza a câmera quando um bairro é selecionado na busca. O token
    // muda a cada seleção; só animamos quando ele avança e o mapa já existe.
    final tokenCamera = widget.controller.alvoCameraToken;
    final alvoCamera = widget.controller.alvoCamera;
    if (tokenCamera != _ultimoTokenCamera &&
        alvoCamera != null &&
        _mapController != null) {
      _ultimoTokenCamera = tokenCamera;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(alvoCamera, 15),
          );
        }
      });
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: cameraPosition!,
          myLocationEnabled: true,
          // Botão nativo desativado: ficava atrás dos filtros de status no
          // topo. Usamos um botão próprio no canto inferior esquerdo.
          myLocationButtonEnabled: false,
          markers: widget.controller.listaMarcadores,
          circles: widget.controller.circuloBairro,
          clusterManagers: {
            ClusterManager(clusterManagerId: MapController.clusterManagerId),
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            _mapController = controller;
            if (widget.controller.listaMarcadores.isNotEmpty) {
              _jaEnquadrou = true;
              _enquadrarMarcadores();
            }
          },
        ),

        // Filtros de status sobre o mapa. Clamp de fonte evita overflow da
        // faixa de altura fixa quando o sistema usa "fonte grande".
        Positioned(
          top: 12,
          left: 8,
          right: 8,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: _FiltrosStatus(controller: widget.controller),
          ),
        ),

        // Botão para reenquadrar todas as ocorrências.
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'enquadrar-ocorrencias',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            elevation: 3,
            onPressed: temMarcadores ? _enquadrarMarcadores : null,
            child: const Icon(Icons.fit_screen),
          ),
        ),

        // Botão para centralizar o mapa na localização atual.
        Positioned(
          left: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'minha-localizacao',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            elevation: 3,
            onPressed: _irParaMinhaLocalizacao,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

class _MapWebConfigMissing extends StatelessWidget {
  const _MapWebConfigMissing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.all(24),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 42, color: AppColors.hint),
          SizedBox(height: 14),
          Text(
            'Mapa indisponível no navegador',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Configure web/maps_config.js com uma chave Google Maps Web para usar o mapa no Chrome.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.hint, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Linha de chips para filtrar os marcadores por status.
class _FiltrosStatus extends StatelessWidget {
  final MapController controller;

  const _FiltrosStatus({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(
            label: 'Todos',
            cor: AppColors.muted,
            selecionado: controller.statusSelecionado == null,
            onTap: () => controller.selecionarStatus(null),
          ),
          for (final s in OccurrenceStatus.values)
            _chip(
              label: s.label,
              cor: s.color,
              selecionado: controller.statusSelecionado == s,
              onTap: () => controller.selecionarStatus(s),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color cor,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selecionado ? cor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selecionado ? cor : AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selecionado ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
