import 'package:drawing_animation/drawing_animation.dart';
import 'package:eco_jp/pages/loading_screen.dart';
import 'package:flutter/material.dart';
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
  testWidgets('aguarda a animação quando o app carrega primeiro',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoadingScreen(
          load: () async {},
          next: (_) => const Scaffold(body: Text('Ready')),
          error: (_) => const Scaffold(body: Text('Failed')),
        ),
      ),
    );

    await _pumpUntilDrawingIsReady(tester);
    expect(find.text('Ready'), findsNothing);
    expect(
      find.byKey(const ValueKey('animated-logo-layer')),
      findsOneWidget,
    );

    final drawing =
        tester.widget<AnimatedDrawing>(find.byType(AnimatedDrawing));
    drawing.onFinish!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(const ValueKey('animated-logo-layer')), findsNothing);
    expect(find.byKey(const ValueKey('final-ecohub-logo')), findsOneWidget);
    expect(find.text('Ready'), findsNothing);

    // Logo completa por ~300 ms e então o crossfade começa.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Ready'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(LoadingScreen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(LoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
