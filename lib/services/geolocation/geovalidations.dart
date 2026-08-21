import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// _determinePosition
sealed class PositionResult {}

class PositionSucess extends PositionResult {
  final Position position;
  PositionSucess(this.position);
}

class PositionFailure extends PositionResult {
  final String error;
  PositionFailure(this.error);
}

// getActualPositionLatLng
sealed class LatLngResult {}

class LatLngSucess extends LatLngResult {
  final LatLng latLng;
  LatLngSucess(this.latLng);
}

class LatLngFailure extends LatLngResult {
  final String error;
  LatLngFailure(this.error);
}
