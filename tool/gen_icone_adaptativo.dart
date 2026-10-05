// Gera o ícone do app (Android) e o logo enxuto da splash a partir de
// assets/images/logo_ecojp.png.
//
// Ícone: só a face da moeda (castelo, sol, folhas e "EcoJP"), sem o aro de
// prata, num disco claro sobre o verde da marca. O aro some de propósito: em
// 48dp ele vira um anel cinza que rouba espaço do desenho, e a máscara do
// launcher cortava a borda dele.
//
// Rode com: dart run tool/gen_icone_adaptativo.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _res = 'android/app/src/main/res';

// Raio da face interna no logo original (926px), medido até antes da linha
// escura que separa a face do aro metálico.
const _raioFace = 358;

// Fração do tile adaptativo (108dp) ocupada pelo disco. A safe zone é um
// círculo de 66dp (61%); 60% deixa o castelo e o texto inteiros em qualquer
// máscara (círculo, squircle, gota) com um anel verde visível em volta.
const _fracaoDisco = 0.60;

// Mesmo verde de values/colors.xml (ic_launcher_background).
final _verde = img.ColorRgba8(0x1F, 0x7A, 0x4D, 0xFF);

// Tamanho em px de 108dp (foreground adaptativo) e 48dp (ícone legado) por
// densidade.
const _densidades = {
  'mdpi': (108, 48),
  'hdpi': (162, 72),
  'xhdpi': (216, 96),
  'xxhdpi': (324, 144),
  'xxxhdpi': (432, 192),
};

void main() {
  final logo = img.decodePng(
    File('assets/images/logo_ecojp.png').readAsBytesSync(),
  );
  if (logo == null) {
    stderr.writeln('Falha ao ler logo_ecojp.png');
    exit(1);
  }
  final face = _recortarFace(logo);

  for (final MapEntry(key: densidade, value: (tile, legado))
      in _densidades.entries) {
    // Foreground adaptativo: disco no centro, resto transparente (o verde vem
    // do <background> em mipmap-anydpi-v26/ic_launcher.xml).
    final disco = (tile * _fracaoDisco).round();
    final foreground = img.Image(width: tile, height: tile, numChannels: 4);
    _centralizar(foreground, _redimensionar(face, disco));
    _salvar('$_res/drawable-$densidade/ic_launcher_foreground.png', foreground);

    // Legado (launchers sem ícone adaptativo): círculo verde com o disco na
    // mesma proporção que a máscara circular mostra (60% de 108 / 72 = 90%).
    final legacy = img.Image(width: legado, height: legado, numChannels: 4);
    _discoVerde(legacy);
    _centralizar(
      legacy,
      _redimensionar(face, (legado * _fracaoDisco * 108 / 72).round()),
    );
    _salvar('$_res/mipmap-$densidade/ic_launcher.png', legacy);
  }

  // Logo enxuto para a splash: o original tem 926px/1,5MB e o native_splash o
  // replica em várias densidades (light+dark), inflando o APK em ~8MB. 512px
  // basta (fica centralizado, não ocupa a tela toda) e corta o peso.
  _salvar(
    'tool/logo_splash.png',
    img.copyResize(
      logo,
      width: 512,
      height: 512,
      interpolation: img.Interpolation.cubic,
    ),
  );
}

/// Recorta a face interna da moeda como um disco com borda suavizada.
img.Image _recortarFace(img.Image logo) {
  final cx = logo.width / 2;
  final cy = logo.height / 2;
  final face = img.copyCrop(
    logo,
    x: (cx - _raioFace).round(),
    y: (cy - _raioFace).round(),
    width: _raioFace * 2,
    height: _raioFace * 2,
  );
  const c = _raioFace - 0.5;
  for (final p in face) {
    final d = math.sqrt(math.pow(p.x - c, 2) + math.pow(p.y - c, 2));
    // Rampa de 2px na borda para não serrilhar.
    final cobertura = ((_raioFace - d) / 2).clamp(0.0, 1.0);
    p.a = p.a * cobertura;
  }
  return face;
}

img.Image _redimensionar(img.Image origem, int lado) => img.copyResize(
      origem,
      width: lado,
      height: lado,
      // average: reduções grandes (716px → 65px) com cubic serrilham.
      interpolation: img.Interpolation.average,
    );

void _centralizar(img.Image destino, img.Image origem) => img.compositeImage(
      destino,
      origem,
      dstX: (destino.width - origem.width) ~/ 2,
      dstY: (destino.height - origem.height) ~/ 2,
    );

void _discoVerde(img.Image destino) {
  final r = destino.width / 2;
  img.fillCircle(
    destino,
    x: r.floor(),
    y: r.floor(),
    radius: r.floor(),
    color: _verde,
    antialias: true,
  );
}

void _salvar(String caminho, img.Image imagem) {
  File(caminho).writeAsBytesSync(img.encodePng(imagem));
  stdout.writeln('OK: $caminho (${imagem.width}x${imagem.height})');
}
