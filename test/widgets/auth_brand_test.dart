import 'dart:io';
import 'dart:ui' as ui;
import 'package:eco_jp/pages/inicial_page.dart';
import 'package:eco_jp/pages/login_page.dart';
import 'package:eco_jp/widgets/auth_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    for (final login in [false, true]) {
      testWidgets('branding ${login ? 'login' : 'intro'} $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
          home: RepaintBoundary(
              key: key, child: login ? const LoginPage() : const InicialPage()),
        )));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
        final logo = find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/ecohub_wordmark.png');
        expect(logo, findsOneWidget);
        final imageWidget = tester.widget<Image>(logo);
        expect(imageWidget.color, isNull);
        expect(imageWidget.fit, BoxFit.contain);
        if (login) {
          final wordmark = find.byType(EcoHubWordmark);
          expect(tester.getSize(wordmark).width, closeTo(size.width - 32, .01));
          expect(tester.getCenter(wordmark).dx, closeTo(size.width / 2, .01));
        } else {
          expect(find.byType(AnimatedContainer), findsNothing);
        }
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('Eco Hub'), findsOneWidget);
        if (login) {
          await tester.enterText(
              find.byType(TextFormField).first, 'teste@example.com');
          await tester.tap(find.byTooltip('Mostrar senha'));
          await tester.pump();
          expect(find.byTooltip('Ocultar senha'), findsOneWidget);
        }
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/branding-preview')
            ..createSync(recursive: true);
          File('${directory.path}/${login ? 'login' : 'intro'}-${size.width.toInt()}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        if (login) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
