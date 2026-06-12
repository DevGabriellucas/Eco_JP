import 'package:flutter/material.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:eco_jp/services/geolocation/geolocation_service.dart';
import 'package:eco_jp/services/geolocation/geovalidations.dart';

class MapDisplay extends StatefulWidget {
  final MapController controller;

  const MapDisplay({super.key, required this.controller});

  @override
  State<MapDisplay> createState() => _MapDisplayState();
}

class _MapDisplayState extends State<MapDisplay> {
  final LocationService locationService = LocationService();

  CameraPosition? cameraPosition;

  @override
  void initState() {
    super.initState();

    loadLocation();
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

  @override
  Widget build(BuildContext context) {
    if (cameraPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GoogleMap(
      initialCameraPosition: cameraPosition!,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: widget.controller.listaMarcadores,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
