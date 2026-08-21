import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/geolocation/geocoding_service.dart';

/// Serviço de geocoding de endereços (form de denúncia) por injeção de
/// dependência. Código novo/telas migradas devem consumir por aqui.
final geocodingServiceProvider =
    Provider<GeocodingService>((ref) => GeocodingService());
