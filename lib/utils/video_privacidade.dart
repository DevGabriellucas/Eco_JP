import 'package:flutter/foundation.dart';

/// Neutraliza os metadados de um vídeo MP4/MOV antes do upload.
///
/// Câmeras de celular gravam a localização em `moov/udta/©xyz` (Android) ou
/// em `moov/meta` com a chave `com.apple.quicktime.location.ISO6709` (iOS),
/// além de modelo do aparelho e software. Em denúncia anônima isso
/// reidentificaria o denunciante.
///
/// Em vez de reescrever o arquivo, trocamos o tipo das caixas `udta` e `meta`
/// (dentro de `moov` e de cada `trak`) e das caixas XMP (`uuid`) por `free`:
/// o tamanho e os offsets das amostras continuam iguais, os players ignoram
/// caixas `free`, e o conteúdo antigo deixa de ser interpretado. O payload
/// também é zerado para o dado não continuar legível nos bytes.
///
/// Bytes que não parecem um contêiner ISO BMFF voltam inalterados — o
/// Cloudinary recusa formatos que não sejam vídeo de qualquer forma.
Future<Uint8List> removerMetadadosVideo(Uint8List bytes) {
  return compute(limparMetadadosVideo, bytes);
}

@visibleForTesting
Uint8List limparMetadadosVideo(Uint8List original) {
  final bytes = Uint8List.fromList(original);
  _limparCaixas(bytes, 0, bytes.length, nivel: 0);
  return bytes;
}

// UUID do XMP da Adobe (be7acfcb-97a9-42e8-9c71-999491e3afac).
const _uuidXmp = [
  0xbe, 0x7a, 0xcf, 0xcb, 0x97, 0xa9, 0x42, 0xe8, //
  0x9c, 0x71, 0x99, 0x94, 0x91, 0xe3, 0xaf, 0xac,
];

void _limparCaixas(Uint8List b, int inicio, int fim, {required int nivel}) {
  var pos = inicio;
  while (pos + 8 <= fim) {
    var tamanho = _u32(b, pos);
    var cabecalho = 8;
    if (tamanho == 1) {
      // Tamanho de 64 bits logo após o tipo.
      if (pos + 16 > fim) return;
      final alto = _u32(b, pos + 8);
      final baixo = _u32(b, pos + 12);
      tamanho = alto * 0x100000000 + baixo;
      cabecalho = 16;
    } else if (tamanho == 0) {
      tamanho = fim - pos; // vai até o fim do contêiner
    }
    if (tamanho < cabecalho || pos + tamanho > fim) return; // corrompido
    final tipo = String.fromCharCodes(b, pos + 4, pos + 8);
    final corpo = pos + cabecalho;
    final fimCaixa = pos + tamanho;

    if (nivel > 0 && (tipo == 'udta' || tipo == 'meta')) {
      _neutralizar(b, pos, corpo, fimCaixa);
    } else if (tipo == 'uuid' && _ehXmp(b, corpo, fimCaixa)) {
      _neutralizar(b, pos, corpo, fimCaixa);
    } else if (tipo == 'moov' || tipo == 'trak') {
      _limparCaixas(b, corpo, fimCaixa, nivel: nivel + 1);
    }
    pos = fimCaixa;
  }
}

bool _ehXmp(Uint8List b, int corpo, int fim) {
  if (corpo + 16 > fim) return false;
  for (var i = 0; i < 16; i++) {
    if (b[corpo + i] != _uuidXmp[i]) return false;
  }
  return true;
}

void _neutralizar(Uint8List b, int pos, int corpo, int fim) {
  b.setRange(pos + 4, pos + 8, 'free'.codeUnits);
  b.fillRange(corpo, fim, 0);
}

// Multiplicação em vez de `<<`: na web os operadores de bit são de 32 bits
// com sinal e um tamanho ≥ 2 GB viraria negativo.
int _u32(Uint8List b, int i) =>
    b[i] * 0x1000000 + b[i + 1] * 0x10000 + b[i + 2] * 0x100 + b[i + 3];
