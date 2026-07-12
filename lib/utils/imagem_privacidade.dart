import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Remove metadados EXIF (incluindo geolocalização embutida) de uma foto
/// antes do upload. Importante para denúncias anônimas: sem isso, o GPS
/// da câmera dentro da própria foto poderia reidentificar o denunciante,
/// mesmo com o campo `anonima` protegido no Firestore.
///
/// Roda em isolate separado (`compute`) porque decodificar/recodificar
/// imagens grandes é custoso e travaria a UI se rodasse na main thread.
Future<Uint8List> removerMetadadosImagem(Uint8List bytes) {
  return compute(_semExif, bytes);
}

Uint8List _semExif(Uint8List bytes) {
  final imagem = img.decodeImage(bytes);
  if (imagem == null) return bytes; // formato não reconhecido, mantém original

  // decodeImage já não preserva EXIF por padrão nas versões recentes do
  // pacote `image`, mas encodeJpg abaixo é explícito: reconstrói a imagem
  // do zero (só pixels), sem qualquer bloco de metadados.
  return Uint8List.fromList(img.encodeJpg(imagem, quality: 90));
}
