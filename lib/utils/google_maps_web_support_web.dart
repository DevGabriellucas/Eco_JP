import 'dart:js_interop';

@JS('ECOJP_MAPS_READY')
external JSBoolean? get _mapsReady;

bool get isGoogleMapsWebReady => _mapsReady?.toDart ?? false;
