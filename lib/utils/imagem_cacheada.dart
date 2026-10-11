import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// [ImageProvider] com cache em **disco**: a imagem baixada fica salva no
/// aparelho (via `flutter_cache_manager`), então reabre instantânea e continua
/// visível **offline** — ao contrário de [NetworkImage], que só guarda em
/// memória e some ao reiniciar o app ou sair da tela.
///
/// Serve tanto para `Image(image: ...)` quanto para o `backgroundImage` de um
/// `CircleAvatar` (ambos aceitam qualquer [ImageProvider]).
///
/// [cacheWidth] limita a resolução de *decode* em memória (mesma função do
/// `cacheWidth` do `Image.network`): passe a largura em pixels físicos para não
/// decodificar a foto maior do que ela será exibida.
ImageProvider imagemCacheada(String url, {int? cacheWidth}) {
  final ImageProvider provider = CachedNetworkImageProvider(url);
  if (cacheWidth == null) return provider;
  return ResizeImage(provider, width: cacheWidth);
}
