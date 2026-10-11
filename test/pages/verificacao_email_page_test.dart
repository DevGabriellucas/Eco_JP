import 'dart:async';

import 'package:eco_jp/features/auth/providers/auth_providers.dart';
import 'package:eco_jp/pages/verificacao_email_page.dart';
import 'package:eco_jp/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conta de e-mail ainda não confirmado, sem tocar no Firebase.
class _AuthFalso extends Fake implements AuthService {
  int envios = 0;
  int checagens = 0;
  int saidas = 0;

  /// Quando definido, a recarga só termina quando o teste completar.
  Completer<bool>? recargaLenta;

  @override
  String? get emailAtual => 'gabriel@email.com';

  @override
  Future<AuthResult> enviarEmailVerificacao() async {
    envios++;
    return AuthResult(success: true, message: 'Enviado');
  }

  @override
  Future<bool> recarregarEVerificarEmail() {
    checagens++;
    return recargaLenta?.future ?? Future.value(false);
  }

  @override
  Future<void> sair() async {
    saidas++;
    await Future<void>.delayed(const Duration(milliseconds: 500));
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
            child: const VerificacaoEmailPage(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mostra o e-mail da conta e as ações', (tester) async {
    await montar(tester);
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    expect(find.textContaining('gabriel@email.com', findRichText: true),
        findsOneWidget);
    expect(find.text('Já confirmei'), findsOneWidget);
    expect(find.text('Reenviar e-mail'), findsOneWidget);
    expect(find.text('Usar outra conta'), findsOneWidget);
  });

  testWidgets('reenviar inicia a espera com contagem', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Reenviar e-mail'));
    await tester.pump();
    expect(auth.envios, 1);
    expect(find.text('Reenviar e-mail em 60s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reenviar e-mail em 59s'), findsOneWidget);

    // Durante a espera não reenvia.
    await tester.tap(find.text('Reenviar e-mail em 59s'));
    await tester.pump();
    expect(auth.envios, 1);
  });

  testWidgets('confere a confirmação a cada 4 s', (tester) async {
    await montar(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    expect(auth.checagens, 2);
  });

  testWidgets('confirmado: "Já confirmei" segue carregando até trocar de tela',
      (tester) async {
    auth.recargaLenta = Completer<bool>()..complete(true);
    await montar(tester);

    await tester.tap(find.text('Já confirmei'));
    await tester.pump();
    await tester.pump();

    // O router ainda carrega perfil e consentimento: sem o indicador a tela
    // ficava parada, parecendo que nada aconteceu.
    expect(find.text('Já confirmei'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('recarga lenta: o timer não empilha outra checagem',
      (tester) async {
    auth.recargaLenta = Completer<bool>();
    await montar(tester);

    await tester.pump(const Duration(seconds: 4));
    expect(auth.checagens, 1);
    // A primeira ainda não terminou: os próximos ciclos reaproveitam.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    expect(auth.checagens, 1);

    auth.recargaLenta!.complete(false);
    await tester.pump();
    auth.recargaLenta = null;
    await tester.pump(const Duration(seconds: 4));
    expect(auth.checagens, 2);
  });

  testWidgets('em segundo plano não consulta; ao voltar confere na hora',
      (tester) async {
    await montar(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(auth.checagens, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.checagens, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(auth.checagens, 2);
  });

  testWidgets('"Usar outra conta" sai uma vez só', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Usar outra conta'));
    await tester.pump();
    await tester.tap(find.text('Usar outra conta'));
    await tester.pump(const Duration(seconds: 1));
    expect(auth.saidas, 1);
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
        expect(tester.takeException(), isNull);
      });
    }
  }
}
