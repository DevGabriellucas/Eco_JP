import 'dart:async';

import 'package:eco_jp/core/inicializacao.dart';
import 'package:eco_jp/core/router/app_router.dart';
import 'package:eco_jp/core/router/routes.dart';
import 'package:eco_jp/features/auth/providers/auth_providers.dart';
import 'package:eco_jp/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthFalso extends Fake implements AuthService {
  @override
  String? get emailAtual => 'maria@email.com';

  @override
  Future<bool> recarregarEVerificarEmail() async => false;
}

/// Regressão do relato "a confirmação de e-mail aparece e logo depois vai
/// para outra tela sozinha": com o router de verdade e a pilha de telas
/// abertas por push (inicial → login → cadastro), a confirmação fica sozinha
/// na pilha e não sai sem a conta deslogar ou confirmar.
void main() {
  testWidgets('cadastro aberto por push: a confirmação fica e não sai sozinha',
      (tester) async {
    final auth = StreamController<User?>.broadcast();
    User? atual;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_AuthFalso()),
        splashMinimoProvider.overrideWith((ref) async {}),
        authStateChangesProvider.overrideWith((ref) async* {
          yield atual;
          yield* auth.stream;
        }),
        perfilGarantidoProvider.overrideWith((ref) async => true),
        consentStatusProvider.overrideWith((ref) async => false),
      ],
    );
    addTearDown(() {
      container.dispose();
      auth.close();
    });

    final router = container.read(goRouterProvider);
    String pilha() => router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .join(' > ');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(pilha(), Routes.inicial);

    // Como no app: inicial → "Já tenho uma conta" → "Cadastre-se".
    router.push(Routes.login);
    await tester.pumpAndSettle();
    router.push(Routes.cadastro);
    await tester.pumpAndSettle();
    expect(pilha(), '${Routes.inicial} > ${Routes.login} > ${Routes.cadastro}');

    // O cadastro: segura o redirect, cria a conta, libera.
    container.read(cadastroEmAndamentoProvider.notifier).state = true;
    final nova =
        MockUser(uid: 'u1', email: 'maria@email.com', isEmailVerified: false);
    atual = nova;
    auth.add(nova);
    await tester.pumpAndSettle();
    expect(pilha(), endsWith(Routes.cadastro));
    container.read(cadastroEmAndamentoProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(pilha(), Routes.verificacaoEmail);

    // "Pouco tempo depois": ciclos da checagem e outras notificações do
    // router não podem tirar a pessoa da confirmação.
    await tester.pump(const Duration(seconds: 9));
    container.invalidate(consentStatusProvider);
    container.invalidate(perfilGarantidoProvider);
    await tester.pumpAndSettle();
    expect(pilha(), Routes.verificacaoEmail);
  });

  testWidgets('nome em uso: a conta é apagada e a pessoa continua no cadastro',
      (tester) async {
    final auth = StreamController<User?>.broadcast();
    User? atual;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_AuthFalso()),
        splashMinimoProvider.overrideWith((ref) async {}),
        authStateChangesProvider.overrideWith((ref) async* {
          yield atual;
          yield* auth.stream;
        }),
        perfilGarantidoProvider.overrideWith((ref) async => true),
        consentStatusProvider.overrideWith((ref) async => false),
      ],
    );
    addTearDown(() {
      container.dispose();
      auth.close();
    });

    final router = container.read(goRouterProvider);
    String pilha() => router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .join(' > ');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push(Routes.login);
    await tester.pumpAndSettle();
    router.push(Routes.cadastro);
    await tester.pumpAndSettle();

    // Cria a conta, a reserva do nome falha e o cadastro apaga a conta.
    container.read(cadastroEmAndamentoProvider.notifier).state = true;
    atual = MockUser(uid: 'u1', isEmailVerified: false);
    auth.add(atual);
    await tester.pumpAndSettle();
    atual = null;
    auth.add(null);
    await tester.pumpAndSettle();
    container.read(cadastroEmAndamentoProvider.notifier).state = false;
    await tester.pumpAndSettle();

    // Continua no cadastro (onde a mensagem "nome em uso" aparece), em vez
    // de passar pela confirmação e cair na inicial.
    expect(pilha(), '${Routes.inicial} > ${Routes.login} > ${Routes.cadastro}');
  });
}
