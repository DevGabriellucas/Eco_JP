// Gera o foreground do ícone adaptativo (Android) com padding, para o logo
// caber na "safe zone" da máscara adaptativa sem ter a borda cortada.
//
// Rode com: dart run tool/gen_icone_adaptativo.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final origem = File('assets/images/logo_ecojp.png');
  final logo = img.decodePng(origem.readAsBytesSync());
  if (logo == null) {
    stderr.writeln('Falha ao ler logo_ecojp.png');
    exit(1);
  }

  const canvas = 1024;
  // Safe zone adaptativa ≈ 66% do tile. Escalamos o logo para caber nela,
  // deixando o resto transparente (o fundo verde aparece ao redor).
  final alvo = (canvas * 0.66).round();

  final resultado = img.Image(width: canvas, height: canvas, numChannels: 4);
  final redimensionado = img.copyResize(
    logo,
    width: alvo,
    height: alvo,
    interpolation: img.Interpolation.cubic,
  );
  final deslocamento = ((canvas - alvo) / 2).round();
  img.compositeImage(
    resultado,
    redimensionado,
    dstX: deslocamento,
    dstY: deslocamento,
  );

  // Fora de assets/ de propósito: é fonte de build do ícone, não deve ir no APK.
  File(
    'tool/logo_ecojp_adaptive.png',
  ).writeAsBytesSync(img.encodePng(resultado));
  stdout.writeln('OK: tool/logo_ecojp_adaptive.png (${canvas}x$canvas)');

  // Logo enxuto para a splash: o original tem 926px/1,5MB e o native_splash o
  // replica em várias densidades (light+dark), inflando o APK em ~8MB. 512px
  // basta (fica centralizado, não ocupa a tela toda) e corta o peso.
  const splash = 512;
  final logoSplash = img.copyResize(
    logo,
    width: splash,
    height: splash,
    interpolation: img.Interpolation.cubic,
  );
  File(
    'tool/logo_splash.png',
  ).writeAsBytesSync(img.encodePng(logoSplash));
  stdout.writeln('OK: tool/logo_splash.png (${splash}x$splash)');
}
