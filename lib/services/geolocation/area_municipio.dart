/// Área atendida pelo EcoJP: o município de João Pessoa (com folga).
///
/// Mesmos limites de `isValidCoordinate` em firestore.rules — se um mudar, o
/// outro precisa mudar junto. Antes a única validação era lat/lon ≠ 0: o
/// geocoding de "Centro" pegava o primeiro Centro do Brasil, e quem estava
/// fora da cidade publicava direto pelo GPS, poluindo mapa e estatísticas.
abstract final class AreaMunicipio {
  static const double latMin = -7.30;
  static const double latMax = -6.95;
  static const double lonMin = -35.00;
  static const double lonMax = -34.75;

  /// Sufixo acrescentado às buscas de endereço em texto livre.
  static const String sufixoBusca = 'João Pessoa - PB';

  /// `viewbox` do Nominatim (lon1,lat1,lon2,lat2).
  static const String viewboxNominatim = '$lonMin,$latMax,$lonMax,$latMin';

  /// `bbox` do Photon (minLon,minLat,maxLon,maxLat).
  static const String bboxPhoton = '$lonMin,$latMin,$lonMax,$latMax';

  static bool contem(double lat, double lon) =>
      lat >= latMin && lat <= latMax && lon >= lonMin && lon <= lonMax;
}
