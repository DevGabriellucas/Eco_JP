import 'package:eco_jp/pages/inicial_page.dart';
import 'package:eco_jp/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => const MaterialApp(home: InicialPage());

  Future<void> montar(
    WidgetTester tester,
    Size tamanho, {
    double escalaTexto = 1.0,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: tamanho,
            padding: const EdgeInsets.only(top: 44, bottom: 34),
            textScaler: TextScaler.linear(escalaTexto),
          ),
          child: const InicialPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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

  testWidgets('indicador acompanha a página', (tester) async {
    await montar(tester, const Size(390, 844));
    expect(find.bySemanticsLabel('Página 1 de 3'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Página 2 de 3'), findsOneWidget);
  });

  testWidgets('topo com padrão, trilha e logo; ícone do slide', (tester) async {
    await montar(tester, const Size(390, 844));
    // 3 no topo + o ícone do slide visível (o PageView só monta o atual).
    expect(find.byType(SvgPicture), findsNWidgets(4));
  });

  // Regressão: a trilha ficava numa caixa começando a 23% do topo com
  // BoxFit.cover; em tela baixa o cover cortava o topo do SVG na borda da
  // caixa e a trilha terminava "no ar". Agora ela tem a proporção natural do
  // SVG, na largura da tela, apoiada no sheet.
  for (final tamanho in const [Size(412, 732), Size(390, 844)]) {
    testWidgets('trilha inteira, na largura da tela e sobre o sheet: $tamanho',
        (tester) async {
      await montar(tester, tamanho);

      final trilha = tester.getRect(find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName ==
                AppIllustrations.initialPageBranch,
      ));
      final topoDoSheet = tester.getRect(find.byType(PageView)).top - 31;

      expect(trilha.width, closeTo(tamanho.width, 0.5));
      expect(trilha.height, closeTo(tamanho.width * 280 / 360, 0.5));
      expect(trilha.bottom, closeTo(topoDoSheet, 0.5));

      final logo = tester.getRect(find.bySemanticsLabel('ecohub'));
      expect(logo.top, greaterThanOrEqualTo(0));
      expect(logo.bottom, lessThan(topoDoSheet));
    });
  }

  testWidgets('tablet: conteúdo limitado a 480 e logo alinhado ao título',
      (tester) async {
    await montar(tester, const Size(800, 1280));

    final botao =
        tester.getRect(find.widgetWithText(ElevatedButton, 'Começar'));
    expect(botao.width, lessThanOrEqualTo(480));
    expect(botao.center.dx, closeTo(400, 0.5));

    final titulo =
        tester.getRect(find.text('Registre problemas da sua cidade'));
    final logo = tester.getRect(find.bySemanticsLabel('ecohub'));
    expect(logo.left, closeTo(titulo.left, 0.5));
  });

  const tamanhos = {
    'pequeno 360x640': Size(360, 640),
    'iPhone 390x844': Size(390, 844),
    'estreito 320x568': Size(320, 568),
    'alto 412x915': Size(412, 915),
    'tablet 800x1280': Size(800, 1280),
    'paisagem 844x390': Size(844, 390),
  };

  for (final MapEntry(key: nome, value: tamanho) in tamanhos.entries) {
    for (final escala in [1.0, 1.3, 2.0]) {
      testWidgets('sem overflow: $nome, texto ${escala}x', (tester) async {
        await montar(tester, tamanho, escalaTexto: escala);
        expect(tester.takeException(), isNull);
        expect(find.text('Começar'), findsOneWidget);
      });
    }
  }
}
