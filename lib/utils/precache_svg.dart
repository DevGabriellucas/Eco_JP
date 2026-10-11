import 'package:flutter_svg/flutter_svg.dart';

/// Lê e decodifica o SVG [asset] antes de ele ser exibido, deixando-o no
/// cache do flutter_svg. Sem isso o SvgPicture aparece um ou dois frames
/// depois do resto da tela.
Future<void> precacheSvg(String asset) {
  final loader = SvgAssetLoader(asset);
  return svg.cache.putIfAbsent(
    loader.cacheKey(null),
    () => loader.loadBytes(null),
  );
}
