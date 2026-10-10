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
}

void main() {
  late _AuthFalso auth;

  setUp(() => auth = _AuthFalso());

  Future<void> montar(
    WidgetTester tester, {
    Size tamanho = const Size(360, 800),
    double escalaTexto = 1.0,
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

  const tamanhos = {
    'estreito 320x568': Size(320, 568),
    'frame 360x800': Size(360, 800),
    'alto 412x915': Size(412, 915),
    'paisagem 800x360': Size(800, 360),
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
