import 'package:eco_jp/features/auth/providers/auth_providers.dart';
import 'package:eco_jp/pages/login_page.dart';
import 'package:eco_jp/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Login sempre falha, sem tocar no Firebase.
class _AuthFalso extends Fake implements AuthService {
  int tentativas = 0;

  @override
  Future<AuthResult> login(String email, String password) async {
    tentativas++;
    return AuthResult(success: false, message: 'Email ou senha inválidos.');
  }

  @override
  Future<AuthResult> loginGoogle() async =>
      AuthResult(success: false, message: 'Login cancelado.');
}

/// Cor da borda do campo de senha quando não está focado.
Color? _bordaSenha(WidgetTester tester) {
  final campo = tester.widget<TextField>(find.byType(TextField).at(1));
  return campo.decoration?.enabledBorder?.borderSide.color;
}

void main() {
  late _AuthFalso auth;

  setUp(() => auth = _AuthFalso());

  Future<void> montar(
    WidgetTester tester, {
    Size tamanho = const Size(360, 800),
    double escalaTexto = 1.0,
    double teclado = 0,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: tamanho,
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              viewInsets: EdgeInsets.only(bottom: teclado),
              textScaler: TextScaler.linear(escalaTexto),
            ),
            child: const LoginPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra título, campos, ações e rodapé', (tester) async {
    await montar(tester);

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('SENHA'), findsOneWidget);
    expect(find.text('Esqueceu a senha?'), findsOneWidget);
    expect(find.text('Logar'), findsOneWidget);
    expect(find.text('Logar com Google'), findsOneWidget);
    expect(find.text('Cadastre-se'), findsOneWidget);
  });

  testWidgets('olho alterna a senha visível', (tester) async {
    await montar(tester);
    TextField senha() => tester.widget<TextField>(find.byType(TextField).at(1));

    expect(senha().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(senha().obscureText, isFalse);
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);
  });

  testWidgets('erro do Google não deixa a senha com borda de erro',
      (tester) async {
    await montar(tester);
    final bordaNormal = _bordaSenha(tester);

    await tester.ensureVisible(find.text('Logar com Google'));
    await tester.tap(find.text('Logar com Google'));
    await tester.pumpAndSettle();

    expect(find.text('Login cancelado.'), findsOneWidget);
    expect(_bordaSenha(tester), bordaNormal);
  });

  testWidgets('erro de senha marca o campo', (tester) async {
    await montar(tester);
    final bordaNormal = _bordaSenha(tester);
    await tester.tap(find.text('Logar'));
    await tester.pumpAndSettle();
    expect(_bordaSenha(tester), isNot(bordaNormal));
  });

  testWidgets('diálogo de recuperar senha não estoura com fonte e teclado',
      (tester) async {
    // O diálogo abre fora da tela, com a fonte do sistema sem limite.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await montar(tester, tamanho: const Size(360, 640));

    await tester.ensureVisible(find.text('Esqueceu a senha?'));
    await tester.tap(find.text('Esqueceu a senha?'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar senha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha no login mostra a mensagem uma vez', (tester) async {
    await montar(tester);
    await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextField).at(1), 'errada');
    await tester.tap(find.text('Logar'));
    await tester.pumpAndSettle();

    expect(auth.tentativas, 1);
    // Só abaixo da senha; antes aparecia também num snackbar.
    expect(find.text('Email ou senha inválidos.'), findsOneWidget);
  });

  for (final tamanho in const [Size(800, 1280), Size(800, 360)]) {
    testWidgets('formulário limitado a 440 e centralizado: $tamanho',
        (tester) async {
      await montar(tester, tamanho: tamanho);
      final email = tester.getRect(find.byType(TextField).first);
      expect(email.width, lessThanOrEqualTo(440));
      expect(email.center.dx, closeTo(tamanho.width / 2, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('teclado aberto: sem overflow e rodapé alcançável',
      (tester) async {
    await montar(tester, teclado: 300);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Cadastre-se'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cadastre-se').hitTestable(), findsOneWidget);
  });

  testWidgets('rodapé fica no pé da tela quando sobra espaço', (tester) async {
    await montar(tester, tamanho: const Size(412, 915));
    final rodape = tester.getRect(find.text('Cadastre-se'));
    // Pé da tela: 915 - padding inferior (24) - folga do rodapé.
    expect(rodape.bottom, greaterThan(915 - 24 - 60));
  });

  const tamanhos = {
    'estreito 320x568': Size(320, 568),
    'frame 360x800': Size(360, 800),
    'alto 412x915': Size(412, 915),
    'paisagem 800x360': Size(800, 360),
    'paisagem baixa 640x320': Size(640, 320),
  };

  for (final MapEntry(key: nome, value: tamanho) in tamanhos.entries) {
    for (final escala in [1.0, 2.0]) {
      testWidgets('sem overflow: $nome, texto ${escala}x', (tester) async {
        await montar(tester, tamanho: tamanho, escalaTexto: escala);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
