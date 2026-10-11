import 'dart:async';

import 'package:eco_jp/pages/inicializacao_erro_page.dart';
import 'package:eco_jp/pages/splash_page.dart';
import 'package:eco_jp/theme/app_icons.dart';
import 'package:eco_jp/utils/precache_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _montar(
  WidgetTester tester,
  Size tamanho, {
  double escalaTexto = 1.0,
  bool animarEntrada = true,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: tamanho,
          textScaler: TextScaler.linear(escalaTexto),
        ),
        child: SplashPage(animarEntrada: animarEntrada),
      ),
    ),
  );
  // Passa do limite de 1 s da espera pelos assets e deixa o fade terminar.
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  const tamanhos = {
    'celular pequeno': Size(320, 568),
    'celular do Figma': Size(360, 800),
    'tablet': Size(800, 1280),
    'paisagem': Size(800, 360),
  };

  for (final MapEntry(key: nome, value: tamanho) in tamanhos.entries) {
    testWidgets('splash sem overflow: $nome', (tester) async {
      await _montar(tester, tamanho);

      expect(tester.takeException(), isNull);
      expect(find.text('NATUREZA CONECTADA'), findsOneWidget);
      expect(find.textContaining('JOÃO PESSOA'), findsOneWidget);
      // Padrão de fundo, logo e régua.
      expect(find.byType(SvgPicture), findsNWidgets(3));
    });

    testWidgets('splash sem overflow com fonte grande: $nome', (tester) async {
      await _montar(tester, tamanho, escalaTexto: 2.0);
      expect(tester.takeException(), isNull);
    });
  }

  // Regressão: a SafeArea era filha não posicionada do Stack, a Column
  // ficava com a largura do filho mais largo e tudo colava à esquerda.
  for (final tamanho in const [
    Size(360, 800),
    Size(320, 568),
    Size(800, 1280),
  ]) {
    testWidgets('conteúdo centralizado na horizontal: $tamanho',
        (tester) async {
      await _montar(tester, tamanho);
      final centro = tamanho.width / 2;
      final svgs = find.byType(SvgPicture);
      // Índices 1 e 2: logo e régua (o 0 é o fundo, que cobre a tela).
      for (final alvo in [
        svgs.at(1),
        svgs.at(2),
        find.text('NATUREZA CONECTADA'),
        find.textContaining('JOÃO PESSOA'),
      ]) {
        expect(tester.getCenter(alvo).dx, closeTo(centro, 1.0));
      }
    });
  }

  testWidgets('fonte que não termina de carregar não segura a splash',
      (tester) async {
    // Simula a Poppins do tema baixando da rede sem fim: pendingFonts espera
    // todas as fontes, inclusive as que a splash não usa.
    final original = SplashPage.esperarFontes;
    SplashPage.esperarFontes = () => Completer<void>().future;
    addTearDown(() => SplashPage.esperarFontes = original);

    // SVGs já em cache (o carregamento real não avança no relógio falso do
    // teste): assim só a espera das fontes pode atrasar o fade.
    await tester.runAsync(
      () => Future.wait([
        precacheSvg(AppIllustrations.contourLines),
        precacheSvg(AppLogos.ecohub),
        precacheSvg(AppIllustrations.splashBottom),
      ]),
    );

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    FadeTransition fade() => tester.widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(SplashPage),
                matching: find.byType(FadeTransition),
              )
              .first,
        );

    // Limite das fontes (300 ms), um frame para o fade começar e os 400 ms
    // dele: visível em ~0,8 s. Com o limite antigo (1 s esperando todas as
    // fontes) ainda estaria invisível aqui.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(fade().opacity.value, 1.0);
  });

  testWidgets('entrada animada termina visível', (tester) async {
    await _montar(tester, const Size(360, 800));
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(SplashPage),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1.0);
  });

  testWidgets('sem animação de entrada já nasce visível', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: SplashPage(animarEntrada: false)),
    );
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(SplashPage),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1.0);
  });

  testWidgets('erro de inicialização: "Tentar novamente" chama o callback',
      (tester) async {
    var tentativas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: InicializacaoErroPage(onTentarNovamente: () => tentativas++),
      ),
    );
    await tester.tap(find.text('Tentar novamente'));
    expect(tentativas, 1);
  });
}
