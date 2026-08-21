import 'package:eco_jp/pages/inicial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => const MaterialApp(home: InicialPage());

  testWidgets('mostra o primeiro slide e os CTAs de cadastro/login', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Registre problemas da sua cidade'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
    expect(find.text('Já tenho uma conta'), findsOneWidget);
  });

  testWidgets('deslizar avança para o segundo slide', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Acompanhe cada denúncia'), findsOneWidget);
    // Os CTAs seguem visíveis em qualquer slide.
    expect(find.text('Começar'), findsOneWidget);
  });
}
