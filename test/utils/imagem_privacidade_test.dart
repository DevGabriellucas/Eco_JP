import 'dart:typed_data';

import 'package:eco_jp/utils/imagem_privacidade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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

  test('saída não carrega metadados EXIF', () async {
    final original = img.Image(width: 4, height: 4);
    final bytes = Uint8List.fromList(img.encodeJpg(original));

    final limpo = await removerMetadadosImagem(bytes);
    final exif = img.decodeImage(limpo)!.exif;
    expect(exif.isEmpty, isTrue);
  });

  test('remove GPS embutido (reidentificação do denunciante anônimo)', () async {
    final original = img.Image(width: 4, height: 4);
    original.exif.gpsIfd['GPSLatitude'] = 7;
    original.exif.gpsIfd['GPSLongitude'] = 34;
    final sujo = Uint8List.fromList(img.encodeJpg(original));

    // Premissa do teste: o input realmente carrega GPS após o round-trip.
    // Se esta versão do pacote não preserva GPS no encode, a limpeza é trivial.
    final gpsAntes = img.decodeImage(sujo)!.exif.gpsIfd;
    if (gpsAntes.isEmpty) {
      markTestSkipped('encodeJpg não preservou GPS nesta versão do pacote');
      return;
    }

    final limpo = await removerMetadadosImagem(sujo);
    expect(img.decodeImage(limpo)!.exif.gpsIfd.isEmpty, isTrue);
  });

  test('bytes que não são imagem voltam inalterados', () async {
    final lixo = Uint8List.fromList([1, 2, 3, 4, 5]);
    final resultado = await removerMetadadosImagem(lixo);
    expect(resultado, equals(lixo));
  });
}
