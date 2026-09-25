import 'package:eco_jp/pages/inicial_page.dart';
import 'package:eco_jp/widgets/auth_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => const MaterialApp(home: InicialPage());

  testWidgets('mostra logo e CTAs sem o bloco de apresentacao', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Registre problemas da sua cidade'), findsNothing);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    expect(find.textContaining('Fotografe e denuncie'), findsNothing);
    expect(find.text('Começar'), findsOneWidget);
    expect(find.text('Já tenho uma conta'), findsOneWidget);
  });

  testWidgets('apresentacao fixa sem carrossel e com logo ampliada',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    final logo = find.byType(EcoHubWordmark);
    expect(tester.getCenter(logo),
        tester.getCenter(find.byKey(const ValueKey('onboarding-logo-area'))));
    expect(tester.widget<EcoHubWordmark>(logo).trimPadding, isTrue);
    expect(
        tester.getSize(logo).width,
        closeTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio - 32,
            .01));
    expect(
        tester.getCenter(logo).dx,
        closeTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
            .01));
    await tester.drag(logo, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Acompanhe cada denúncia'), findsNothing);
    expect(find.text('Autoridades no mesmo app'), findsNothing);
    expect(find.text('Registre problemas da sua cidade'), findsNothing);
    expect(find.text('Começar'), findsOneWidget);
  });
}
