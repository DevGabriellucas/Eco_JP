/// Estilo escuro do Google Maps, harmonizado com a paleta escura do app
/// (`AppPalette.dark`). O terreno base fica em ~#101512 — de propósito mais
/// escuro que a `surface` (#171C19), para que os controles do overlay (FABs e
/// chips, que usam `pal.surface`) "flutuem" acima do mapa, do mesmo jeito que
/// cards sobre o `background` no resto do app. Vias um pouco mais claras, água
/// mais escura e rótulos em cinza-esverdeado claro com contorno escuro.
/// Diferente do "night mode" azulado padrão do Google, que destoaria do verde
/// do Eco_JP.
///
/// Aplicado via `GoogleMap(style: ...)` só quando o tema está no escuro; no
/// claro passamos `null` e o mapa volta ao padrão. String literal (`const`)
/// para não depender de asset nem de carga assíncrona.
const String kEstiloMapaEscuro = r'''
[
  { "elementType": "geometry", "stylers": [{ "color": "#101512" }] },
  { "elementType": "labels.icon", "stylers": [{ "visibility": "off" }] },
  { "elementType": "labels.text.fill", "stylers": [{ "color": "#9aa39c" }] },
  { "elementType": "labels.text.stroke", "stylers": [{ "color": "#0e1311" }] },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [{ "color": "#2b322d" }]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#b0b8b1" }]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#6b7770" }]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#c2cabf" }]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#8fa392" }]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{ "color": "#13201a" }]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#5f8f6b" }]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{ "color": "#1e2621" }]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{ "color": "#0e1311" }]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#9aa39c" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{ "color": "#283029" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{ "color": "#101512" }]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#c2cabf" }]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#8fa392" }]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [{ "color": "#1e2621" }]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [{ "color": "#161d19" }]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{ "color": "#0a0f0d" }]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#4a5a52" }]
  }
]
''';
