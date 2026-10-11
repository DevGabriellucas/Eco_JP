import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Lançada quando os bytes não puderam ser decodificados como imagem. Nesse
/// caso a foto é recusada: enviar o original publicaria o EXIF (e o GPS) que
/// não conseguimos remover.
class ImagemInvalidaException implements Exception {
  const ImagemInvalidaException();

  @override
  String toString() => 'ImagemInvalidaException: formato não reconhecido';
}

/// Remove metadados EXIF (incluindo geolocalização embutida) de uma foto
/// antes do upload. Importante para denúncias anônimas: sem isso, o GPS
/// da câmera dentro da própria foto poderia reidentificar o denunciante,
/// mesmo com o campo `anonima` protegido no Firestore.
///
/// Lança [ImagemInvalidaException] se os bytes não forem uma imagem
/// reconhecida — nunca devolve o original sem limpar.
///
/// Roda em isolate separado (`compute`) porque decodificar/recodificar
/// imagens grandes é custoso e travaria a UI se rodasse na main thread.
Future<Uint8List> removerMetadadosImagem(Uint8List bytes) {
  return compute(_semExif, bytes);
}

Uint8List _semExif(Uint8List bytes) {
  // decodeImage pode lançar (não só retornar null) em bytes corrompidos ou
  // truncados.
  img.Image? imagem;
  try {
    imagem = img.decodeImage(bytes);
  } catch (_) {
    throw const ImagemInvalidaException();
  }
  if (imagem == null) throw const ImagemInvalidaException();

  // O decode do pacote `image` COPIA o EXIF inteiro para a imagem
  // (inclusive o GPS) e o encodeJpg grava de volta o que estiver em
  // `imagem.exif`. Primeiro aplicamos a orientação nos pixels (senão a foto
  // sairia deitada sem a tag Orientation) e só então zeramos os metadados.
  final orientada = img.bakeOrientation(imagem)..exif = img.ExifData();
  return Uint8List.fromList(img.encodeJpg(orientada, quality: 90));
}
