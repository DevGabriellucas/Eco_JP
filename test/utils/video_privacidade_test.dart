import 'dart:convert';
import 'dart:typed_data';

import 'package:eco_jp/utils/video_privacidade.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _caixa(String tipo, List<int> corpo) {
  final tamanho = 8 + corpo.length;
  return Uint8List.fromList([
    (tamanho >> 24) & 0xff,
    (tamanho >> 16) & 0xff,
    (tamanho >> 8) & 0xff,
    tamanho & 0xff,
    ...latin1.encode(tipo),
    ...corpo,
  ]);
}

List<int> _concat(List<List<int>> partes) => [for (final p in partes) ...p];

String _tipoEm(Uint8List b, int pos) =>
    String.fromCharCodes(b, pos + 4, pos + 8);

bool _contem(Uint8List b, String texto) =>
    latin1.decode(b, allowInvalid: true).contains(texto);

void main() {
  // ftyp + mdat + moov{ mvhd, udta{©xyz}, trak{ tkhd, meta{...} } }
  final ftyp = _caixa('ftyp', ascii.encode('isom0000'));
  final mdat = _caixa('mdat', List.filled(32, 7));
  final xyz = _caixa('©xyz', latin1.encode('-07.1150-034.8610/'));
  final udta = _caixa('udta', xyz);
  final metaTrak = _caixa(
    'meta',
    latin1.encode('com.apple.quicktime.location.ISO6709'),
  );
  final trak =
      _caixa('trak', _concat([_caixa('tkhd', List.filled(12, 1)), metaTrak]));
  final moov = _caixa(
    'moov',
    _concat([_caixa('mvhd', List.filled(16, 2)), udta, trak]),
  );
  final video = Uint8List.fromList(_concat([ftyp, mdat, moov]));

  test('fixture contém a localização (premissa)', () {
    expect(_contem(video, '-034.8610'), isTrue);
    expect(_contem(video, 'location.ISO6709'), isTrue);
  });

  test('remove a localização sem mudar tamanho nem as outras caixas', () {
    final limpo = limparMetadadosVideo(video);

    expect(limpo.length, video.length);
    expect(_contem(limpo, '-034.8610'), isFalse);
    expect(_contem(limpo, 'location.ISO6709'), isFalse);

    // ftyp e mdat intactos (mdat são as amostras do vídeo).
    expect(limpo.sublist(0, ftyp.length + mdat.length),
        video.sublist(0, ftyp.length + mdat.length));
    final posMoov = ftyp.length + mdat.length;
    expect(_tipoEm(limpo, posMoov), 'moov');
    final posUdta = posMoov + 8 + 24; // após o mvhd
    expect(_tipoEm(limpo, posUdta), 'free');
  });

  test('não altera o vídeo original passado', () {
    final copia = Uint8List.fromList(video);
    limparMetadadosVideo(video);
    expect(video, copia);
  });

  test('bytes que não são contêiner de vídeo voltam iguais', () {
    final lixo = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(limparMetadadosVideo(lixo), lixo);
  });
}
