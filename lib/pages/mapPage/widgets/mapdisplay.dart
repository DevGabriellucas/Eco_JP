import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/pages/mapPage/map_style.dart';
import 'package:eco_jp/services/geolocation/geolocation_service.dart';
import 'package:eco_jp/services/geolocation/geovalidations.dart';
import 'package:eco_jp/theme/app_theme.dart';
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
    if (cameraPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final pal = context.pal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final temMarcadores = widget.controller.listaMarcadores.isNotEmpty;

    // Enquadra automaticamente os marcadores na primeira carga.
    if (!_jaEnquadrou && temMarcadores && _mapController != null) {
      _jaEnquadrou = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enquadrarMarcadores();
      });
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: cameraPosition!,
          // Tiles escuros (harmonizados com o tema) só no modo escuro; no
          // claro, null volta o mapa ao padrão. Reativo: troca junto do tema.
          style: isDark ? kEstiloMapaEscuro : null,
          myLocationEnabled: true,
          // Botão nativo desativado: ficava atrás dos filtros de status no
          // topo. Usamos um botão próprio no canto inferior esquerdo.
          myLocationButtonEnabled: false,
          // No modo calor, escondemos os marcadores para destacar os hotspots.
          markers: widget.controller.heatmapAtivo
              ? const {}
              : widget.controller.listaMarcadores,
          heatmaps: widget.controller.listaHeatmap,
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

        // Coluna de ações no canto inferior direito: filtro de pendentes,
        // camada de calor e reenquadrar.
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'filtro-pendentes',
                backgroundColor: widget.controller.soPendentes
                    ? AppColors.primary
                    : pal.surface,
                foregroundColor: widget.controller.soPendentes
                    ? Colors.white
                    : pal.ink,
                elevation: 3,
                tooltip: 'Só pendentes de verificação',
                onPressed: () =>
                    setState(() => widget.controller.alternarSoPendentes()),
                child: const Icon(Icons.pending_actions),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.small(
                heroTag: 'mapa-calor',
                backgroundColor: widget.controller.heatmapAtivo
                    ? AppColors.danger
                    : pal.surface,
                foregroundColor: widget.controller.heatmapAtivo
                    ? Colors.white
                    : pal.ink,
                elevation: 3,
                tooltip: 'Mapa de calor (regiões mais afetadas)',
                onPressed: () =>
                    setState(() => widget.controller.alternarHeatmap()),
                child: const Icon(Icons.local_fire_department),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.small(
                heroTag: 'enquadrar-ocorrencias',
                backgroundColor: pal.surface,
                foregroundColor: pal.ink,
                elevation: 3,
                onPressed: temMarcadores ? _enquadrarMarcadores : null,
                child: const Icon(Icons.fit_screen),
              ),
            ],
          ),
        ),

        // Botão para centralizar o mapa na localização atual.
        Positioned(
          left: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'minha-localizacao',
            backgroundColor: pal.surface,
            foregroundColor: pal.ink,
            elevation: 3,
            onPressed: _irParaMinhaLocalizacao,
            child: const Icon(Icons.my_location),
          ),
        ),

        // Legenda do mapa de calor: só aparece com a camada ligada, explicando
        // o que as cores significam (poucas → muitas denúncias).
        if (widget.controller.heatmapAtivo)
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: _LegendaCalor()),
          ),
      ],
    );
  }
}

/// Legenda do gradiente do mapa de calor. Usa exatamente a mesma paleta do
/// heatmap ([kCoresGradienteCalor]) para não divergir das cores no mapa.
class _LegendaCalor extends StatelessWidget {
  const _LegendaCalor();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Concentração de denúncias',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: pal.muted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Poucas', style: TextStyle(fontSize: 10, color: pal.hint)),
              const SizedBox(width: 6),
              Container(
                width: 90,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: kCoresGradienteCalor),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Text('Muitas', style: TextStyle(fontSize: 10, color: pal.hint)),
            ],
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
            context,
            label: 'Todos',
            cor: AppColors.muted,
            selecionado: controller.statusSelecionado == null,
            onTap: () => controller.selecionarStatus(null),
          ),
          for (final s in OccurrenceStatus.values)
            _chip(
              context,
              label: s.label,
              cor: s.color,
              selecionado: controller.statusSelecionado == s,
              onTap: () => controller.selecionarStatus(s),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required Color cor,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selecionado ? cor : pal.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selecionado ? cor : pal.border),
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
              color: selecionado ? Colors.white : pal.muted,
            ),
          ),
        ),
      ),
    );
  }
}
