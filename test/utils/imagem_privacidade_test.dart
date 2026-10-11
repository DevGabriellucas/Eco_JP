import 'dart:typed_data';

import 'package:eco_jp/utils/imagem_privacidade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// JPEG com bloco EXIF contendo GPS (latitude 7°S, longitude 34°W), como o
/// de uma foto de celular. Tags numéricas: as de nome ('GPSLatitude') não
/// são resolvidas pelo pacote dentro do IFD de GPS e o fixture sairia limpo.
Uint8List _jpegComGps({int orientacao = 1, int largura = 4, int altura = 4}) {
  final original = img.Image(width: largura, height: altura);
  original.exif.gpsIfd[0x0001] = img.IfdValueAscii('S');
  original.exif.gpsIfd[0x0002] = img.IfdValueRational(7, 1);
  original.exif.gpsIfd[0x0003] = img.IfdValueAscii('W');
  original.exif.gpsIfd[0x0004] = img.IfdValueRational(34, 1);
  original.exif.imageIfd[0x0112] = img.IfdValueShort(orientacao);
  return Uint8List.fromList(img.encodeJpg(original));
}

void main() {
  test('saída é um JPEG válido com as mesmas dimensões', () async {
    final original = img.Image(width: 8, height: 6);
    final bytes = Uint8List.fromList(img.encodeJpg(original));

    final limpo = await removerMetadadosImagem(bytes);
    final decodificada = img.decodeImage(limpo);
    expect(decodificada, isNotNull);
    expect(decodificada!.width, 8);
    expect(decodificada.height, 6);
  });

  test('fixture carrega GPS de verdade (premissa dos testes abaixo)', () {
    // Se isto falhar, o fixture deixou de ter GPS e os testes de remoção
    // passariam sem provar nada.
    final gps = img.decodeImage(_jpegComGps())!.exif.gpsIfd;
    expect(gps.isEmpty, isFalse);
  });

  test('decode+encode puro do pacote preserva o GPS (motivo da limpeza)', () {
    final reencodado = img.encodeJpg(img.decodeImage(_jpegComGps())!);
    expect(img.decodeImage(reencodado)!.exif.gpsIfd.isEmpty, isFalse);
  });

  test('remove GPS embutido (reidentificação do denunciante anônimo)',
      () async {
    final limpo = await removerMetadadosImagem(_jpegComGps());
    final exif = img.decodeImage(limpo)!.exif;
    expect(exif.gpsIfd.isEmpty, isTrue);
    expect(exif.isEmpty, isTrue);
  });

  test('aplica a orientação nos pixels antes de apagar a tag', () async {
    // Orientação 6 = girar 90°: 8x4 armazenado vira 4x8 exibido.
    final limpo = await removerMetadadosImagem(
      _jpegComGps(orientacao: 6, largura: 8, altura: 4),
    );
    final decodificada = img.decodeImage(limpo)!;
    expect(decodificada.exif.imageIfd.hasOrientation, isFalse);
    expect(decodificada.width, 4);
    expect(decodificada.height, 8);
  });

  test('bytes que não são imagem são recusados (nunca envia o original)', () {
    final lixo = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(
      removerMetadadosImagem(lixo),
      throwsA(isA<ImagemInvalidaException>()),
    );
  });
}
