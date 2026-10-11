import 'package:eco_jp/features/auth/providers/auth_providers.dart';
import 'package:eco_jp/pages/cadastro_page.dart';
import 'package:eco_jp/pages/inicial_page.dart';
import 'package:eco_jp/pages/legal/consentimento_page.dart';
import 'package:eco_jp/pages/login_page.dart';
import 'package:eco_jp/pages/verificacao_email_page.dart';
import 'package:eco_jp/services/auth_service.dart';
import 'package:eco_jp/theme/app_icons.dart';
import 'package:eco_jp/theme/brand_colors.dart';
import 'package:eco_jp/theme/marca_cores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthFalso extends Fake implements AuthService {
  @override
  String? get emailAtual => 'gabriel@email.com';

  @override
  Future<bool> recarregarEVerificarEmail() async => false;
}

// Tema mínimo com a paleta de marca (o AppTheme real também carrega a
// Poppins da rede, o que não cabe num teste de widget).
ThemeData _tema(MarcaCores marca) => ThemeData(
      brightness: marca.brilho,
      extensions: [marca],
    );

Future<void> _montar(
  WidgetTester tester,
  Widget pagina, {
  MarcaCores marca = MarcaCores.dark,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(_AuthFalso())],
      child: MaterialApp(
        theme: _tema(MarcaCores.light),
        darkTheme: _tema(MarcaCores.dark),
        themeMode: marca.escuro ? ThemeMode.dark : ThemeMode.light,
        home: pagina,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Color? _fundoDoScaffold(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor;

Color? _corDoTexto(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).style?.color;

Color? _fundoDoBotao(WidgetTester tester, String texto) {
  final botao =
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, texto));
  return botao.style?.backgroundColor?.resolve({});
}

bool _temSvg(String asset) => find
    .byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          w.bytesLoader is SvgAssetLoader &&
          (w.bytesLoader as SvgAssetLoader).assetName == asset,
    )
    .evaluate()
    .isNotEmpty;

void main() {
  test('sem a extensão no tema, context.marca cai na paleta clara', () {
    // A extensão é opcional: telas montadas com ThemeData cru seguem claras.
    expect(MarcaCores.light.escuro, isFalse);
    expect(MarcaCores.dark.escuro, isTrue);
  });

  test('lerp interpola cores e troca assets na metade', () {
    final meio = MarcaCores.light.lerp(MarcaCores.dark, 0.25);
    expect(meio.logo, MarcaCores.light.logo);
    expect(MarcaCores.light.lerp(MarcaCores.dark, 0.75).logo,
        MarcaCores.dark.logo);
    expect(meio.fundo, isNot(MarcaCores.light.fundo));
  });

  group('modo escuro', () {
    testWidgets('inicial: sheet escuro, título claro, botão accent',
        (tester) async {
      await _montar(tester, const InicialPage());
      final sheet = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == BrandColors.background,
      );
      expect(sheet, findsOneWidget);
      expect(_corDoTexto(tester, 'Registre problemas da sua cidade'),
          BrandColors.textPrimary);
      expect(_fundoDoBotao(tester, 'Começar'), BrandColors.accent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('login: fundo escuro, logo com "hub" branco, botão accent',
        (tester) async {
      await _montar(tester, const LoginPage());
      expect(_fundoDoScaffold(tester), BrandColors.background);
      expect(_corDoTexto(tester, 'Entrar'), BrandColors.textPrimary);
      expect(_temSvg(AppLogos.ecohub), isTrue);
      expect(_temSvg(AppLogos.ecohubOnLight), isFalse);
      expect(_fundoDoBotao(tester, 'Logar'), BrandColors.accent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cadastro: fundo escuro e campos com a borda escura',
        (tester) async {
      await _montar(tester, const CadastroPage());
      expect(_fundoDoScaffold(tester), BrandColors.background);
      expect(_corDoTexto(tester, 'Criar conta'), BrandColors.textPrimary);
      final campo = tester.widget<TextField>(find.byType(TextField).first);
      expect(campo.decoration?.enabledBorder?.borderSide.color,
          BrandColors.borderDark);
      expect(campo.decoration?.focusedBorder?.borderSide.color,
          BrandColors.accent);
      expect(_fundoDoBotao(tester, 'Cadastrar'), BrandColors.accent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirmação: ilustração da versão escura', (tester) async {
      await _montar(tester, const VerificacaoEmailPage());
      expect(_fundoDoScaffold(tester), BrandColors.background);
      expect(
          _corDoTexto(tester, 'Confirme seu e-mail'), BrandColors.textPrimary);
      expect(_temSvg(AppIllustrations.emailBranch), isTrue);
      expect(_temSvg(AppIllustrations.emailBranchLight), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('consentimento: fundo escuro e título claro', (tester) async {
      await _montar(
        tester,
        ConsentimentoPage(onAceitar: () async {}, onRecusar: () async {}),
      );
      expect(_fundoDoScaffold(tester), BrandColors.background);
      expect(
          _corDoTexto(tester, 'Privacidade e Termos'), BrandColors.textPrimary);
      expect(tester.takeException(), isNull);
    });
  });

  group('modo claro continua igual', () {
    testWidgets('login: fundo branco, logo para fundo claro, botão primary',
        (tester) async {
      await _montar(tester, const LoginPage(), marca: MarcaCores.light);
      expect(_fundoDoScaffold(tester), BrandColors.surfaceLight);
      expect(_temSvg(AppLogos.ecohubOnLight), isTrue);
      expect(_fundoDoBotao(tester, 'Logar'), BrandColors.primary);
    });

    testWidgets('confirmação: ilustração da versão clara', (tester) async {
      await _montar(tester, const VerificacaoEmailPage(),
          marca: MarcaCores.light);
      expect(_fundoDoScaffold(tester), BrandColors.surfaceLight);
      expect(_temSvg(AppIllustrations.emailBranchLight), isTrue);
    });
  });
}
