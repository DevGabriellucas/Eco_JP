import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:eco_jp/models/occurrence_types.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Gera marcadores ([BitmapDescriptor]) customizados para cada categoria,
/// reutilizando o ícone e a cor de [OccurrenceType] já usados no feed —
/// assim o pin no mapa "conversa" visualmente com o resto do app.
///
/// O desenho é rasterizado (operação assíncrona), então os ícones são
/// gerados uma única vez e mantidos em cache.
class MarkerIconFactory {
  MarkerIconFactory._();

  static Map<OccurrenceType, BitmapDescriptor>? _cache;

  /// Retorna o mapa de ícones por categoria, gerando-o na primeira chamada.
  ///
  /// Em caso de falha (ex.: plataforma sem suporte a rasterização de canvas),
  /// devolve um mapa vazio — cabe ao chamador usar o marcador padrão como
  /// fallback.
  static Future<Map<OccurrenceType, BitmapDescriptor>> carregar() async {
    if (_cache != null) return _cache!;
    try {
      final mapa = <OccurrenceType, BitmapDescriptor>{};
      for (final tipo in OccurrenceType.values) {
        mapa[tipo] = await _desenharPin(tipo.icon, tipo.color);
      }
      return _cache = mapa;
    } catch (_) {
      return {};
    }
  }

  static Future<BitmapDescriptor> _desenharPin(
    IconData icone,
    Color cor, {
    double tamanho = 120,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final centroX = tamanho / 2;
    final raio = tamanho * 0.32;
    final centro = Offset(centroX, raio + tamanho * 0.04);

    // Sombra suave logo abaixo do pin.
    canvas.drawCircle(
      centro.translate(0, 2),
      raio,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Corpo do pin em formato de gota: triângulo + círculo.
    final corpo = Paint()..color = cor;
    final ponta = Path()
      ..moveTo(centroX - raio * 0.5, centro.dy + raio * 0.6)
      ..lineTo(centroX, tamanho)
      ..lineTo(centroX + raio * 0.5, centro.dy + raio * 0.6)
      ..close();
    canvas
      ..drawPath(ponta, corpo)
      ..drawCircle(centro, raio, corpo)
      ..drawCircle(
        centro,
        raio,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = tamanho * 0.06,
      );

    // Glyph do ícone (branco) centralizado no círculo.
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icone.codePoint),
        style: TextStyle(
          fontSize: raio * 1.05,
          fontFamily: icone.fontFamily,
          package: icone.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));

    final imagem = await recorder.endRecording().toImage(
      tamanho.toInt(),
      tamanho.toInt(),
    );
    final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List png = bytes!.buffer.asUint8List();

    return BitmapDescriptor.bytes(png, imagePixelRatio: 2.5);
  }
}
