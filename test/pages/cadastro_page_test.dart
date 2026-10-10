import 'package:eco_jp/features/auth/providers/auth_providers.dart';
import 'package:eco_jp/pages/cadastro_page.dart';
import 'package:eco_jp/services/auth_service.dart';
import 'package:eco_jp/widgets/marca/icone_svg.dart';
import 'package:eco_jp/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conta quantas vezes tentaram criar conta, sem tocar no Firebase.
class _AuthFalso extends Fake implements AuthService {
  int cadastros = 0;

  @override
  Future<AuthResult> cadastrar(String email, String password) async {
    cadastros++;
    return AuthResult(success: false, message: 'falso');
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
            child: const CadastroPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder campo(int i) => find.byType(TextField).at(i);

  test('força da senha', () {
    expect(forcaSenha(''), 0);
    expect(forcaSenha('abc'), 0);
    expect(forcaSenha('abcdef'), 1);
    expect(forcaSenha('Abcdef12'), 3);
    expect(forcaSenha('Abcdef12!@xyz'), 4);
  });

  testWidgets('mostra título, campos, aceite e rodapé', (tester) async {
    await montar(tester);
    expect(find.text('Criar conta'), findsOneWidget);
    for (final rotulo in ['NOME', 'EMAIL', 'SENHA', 'REPETIR SENHA']) {
      expect(find.text(rotulo), findsOneWidget);
    }
    expect(find.text('Cadastrar'), findsOneWidget);
    expect(find.text('Faça login'), findsOneWidget);
  });

  testWidgets('medidor aparece ao digitar e mostra senha forte',
      (tester) async {
    await montar(tester);
    expect(find.byType(MedidorForcaSenha), findsNothing);

    await tester.enterText(campo(2), 'Abcdef12!@');
    await tester.pump();
    expect(find.text('Senha forte'), findsOneWidget);
  });

  testWidgets('check do "repetir senha" só quando as senhas batem',
      (tester) async {
    await montar(tester);
    bool temCheck() => find
        .descendant(
          of: campo(3),
          matching: find.byWidgetPredicate(
            (w) => w is IconeSvg && w.asset == AppIcons.check,
          ),
        )
        .evaluate()
        .isNotEmpty;

    await tester.enterText(campo(2), 'Abcdef12!@');
    await tester.enterText(campo(3), 'Abcdef12');
    await tester.pump();
    expect(temCheck(), isFalse);

    await tester.enterText(campo(3), 'Abcdef12!@');
    await tester.pump();
    expect(temCheck(), isTrue);
  });

  testWidgets('sem aceite dos termos não tenta criar a conta', (tester) async {
    await montar(tester);
    await tester.enterText(campo(0), 'Maria Silva');
    await tester.enterText(campo(1), 'maria@email.com');
    await tester.enterText(campo(2), 'Abcdef12!@');
    await tester.enterText(campo(3), 'Abcdef12!@');
    await tester.ensureVisible(find.text('Cadastrar'));
    await tester.tap(find.text('Cadastrar'));
    await tester.pump();

    expect(
      find.text('Aceite a Política de Privacidade e os Termos de Uso'),
      findsOneWidget,
    );
    expect(auth.cadastros, 0);
  });

  const tamanhos = {
    'estreito 320x568': Size(320, 568),
    'frame 360x800': Size(360, 800),
    'tablet 800x1280': Size(800, 1280),
    'paisagem 800x360': Size(800, 360),
    'paisagem baixa 640x320': Size(640, 320),
  };

  for (final MapEntry(key: nome, value: tamanho) in tamanhos.entries) {
    for (final escala in [1.0, 2.0]) {
      testWidgets('sem overflow: $nome, texto ${escala}x', (tester) async {
        await montar(tester, tamanho: tamanho, escalaTexto: escala);
        await tester.enterText(campo(2), 'Abcdef12!@');
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
