import 'dart:async';

import 'package:drawing_animation/drawing_animation.dart';
import 'package:eco_jp/pages/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpUntilDrawingIsReady(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  // Sem engine nos testes, a espera pelo primeiro frame desenhado vai até o
  // teto de 1 s; depois vêm os 500 ms de espera inicial.
  await tester.pump(const Duration(milliseconds: 1100));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
  final exception = tester.takeException();
  if (exception != null) throw exception;
  expect(find.byType(AnimatedDrawing), findsOneWidget);
}

void main() {
  testWidgets('anima uma vez, mantém a logo e aguarda o carregamento', (
    tester,
  ) async {
    final loading = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: LoadingScreen(
          load: () => loading.future,
          next: (_) => const Scaffold(body: Text('Ready')),
          error: (_) => const Scaffold(body: Text('Failed')),
        ),
      ),
    );

    await _pumpUntilDrawingIsReady(tester);
    await tester.pump(const Duration(milliseconds: 1));

    final drawing =
        tester.widget<AnimatedDrawing>(find.byType(AnimatedDrawing));
    expect(drawing.assetPath, isEmpty);
    expect(drawing.paths, hasLength(7));
    expect(drawing.paints, hasLength(7));
    expect(
      drawing.paints.every((paint) => paint.style == PaintingStyle.stroke),
      isTrue,
    );
    expect(drawing.paints.every((paint) => paint.strokeWidth == 3), isTrue);
    expect(drawing.duration, const Duration(milliseconds: 2000));
    expect(drawing.animationOrder, PathOrders.original);
    expect(drawing.lineAnimation, LineAnimation.oneByOne);
    expect(drawing.scaleToViewport, isFalse);
    expect(drawing.run, isTrue);

    final finalLogo = find.byKey(const ValueKey('final-ecohub-logo'));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(finalLogo, findsOneWidget);
    expect(
      find.byKey(const ValueKey('animated-logo-layer')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Ready'), findsNothing);
    expect(finalLogo, findsOneWidget);
    expect(find.byKey(const ValueKey('animated-logo-layer')), findsNothing);
    expect(find.byType(AnimatedDrawing), findsNothing);

    // O carregamento demorou: a logo continua completa e não reinicia.
    await tester.pump(const Duration(seconds: 3));
    expect(finalLogo, findsOneWidget);
    expect(find.byType(AnimatedDrawing), findsNothing);
    expect(find.text('Ready'), findsNothing);

    loading.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(LoadingScreen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(LoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
