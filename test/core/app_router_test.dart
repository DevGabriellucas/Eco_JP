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

/// Conta de e-mail/senha sem Firebase (para a tela de confirmação).
class _AuthFalso extends Fake implements AuthService {
  @override
  String? get emailAtual => 'maria@email.com';

  @override
  Future<bool> recarregarEVerificarEmail() async => false;
}

void main() {
  late StreamController<User?> auth;
  late Completer<bool> perfil;
  late Completer<bool> consentimento;
  late ProviderContainer container;
  late List<String> locais;
  User? usuarioAtual;

  final naoConfirmada =
      MockUser(uid: 'u1', email: 'maria@email.com', isEmailVerified: false);
  final confirmada = MockUser(uid: 'u1', email: 'maria@email.com');

  // Criados dentro de cada teste (zona do relógio falso): criados no setUp,
  // os eventos e futures resolviam fora do pump e o teste travava.
  void preparar() {
    auth = StreamController<User?>.broadcast();
    perfil = Completer<bool>();
    consentimento = Completer<bool>();
    locais = [];
    usuarioAtual = null;
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_AuthFalso()),
        splashMinimoProvider.overrideWith((ref) async {}),
        // Como o authStateChanges do Firebase: quem se inscreve recebe o
        // usuário atual na hora (é o que faz o invalidate funcionar).
        authStateChangesProvider.overrideWith((ref) async* {
          if (usuarioAtual != null) yield usuarioAtual;
          yield* auth.stream;
        }),
        // Como os reais: conta não confirmada resolve na hora; a confirmada
        // depende do Firestore (aqui, do teste).
        perfilGarantidoProvider.overrideWith((ref) {
          final user = ref.watch(authStateChangesProvider).value;
          if (user == null || !user.emailVerified) return Future.value(true);
          return perfil.future;
        }),
        consentStatusProvider.overrideWith((ref) {
          final user = ref.watch(authStateChangesProvider).value;
          if (user == null || !user.emailVerified) return Future.value(false);
          return consentimento.future;
        }),
      ],
    );
  }

  tearDown(() {
    container.dispose();
    auth.close();
  });

  Future<void> montar(WidgetTester tester) async {
    preparar();
    final router = container.read(goRouterProvider);
    router.routerDelegate.addListener(
      () => locais.add(router.routerDelegate.currentConfiguration.uri.path),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('abertura do app: sem sessão resolvida, fica na splash',
      (tester) async {
    await montar(tester);
    await tester.pump();
    expect(
      container
          .read(goRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      Routes.splash,
    );
  });

  testWidgets(
      'ao confirmar o e-mail vai direto ao destino, sem passar pela splash',
      (tester) async {
    await montar(tester);
    usuarioAtual = naoConfirmada;
    auth.add(naoConfirmada);
    await tester.pumpAndSettle();
    expect(locais.last, Routes.verificacaoEmail);
    locais.clear();

    // O que a tela faz quando a confirmação chega: o reload() atualiza o
    // usuário atual e o invalidate força uma nova emissão.
    usuarioAtual = confirmada;
    container.invalidate(authStateChangesProvider);
    await tester.pump();
    await tester.pump();
    // Perfil e consentimento ainda carregando (leituras no Firestore).
    perfil.complete(true);
    await tester.pump();
    consentimento.complete(true);
    await tester.pumpAndSettle();

    expect(locais, isNot(contains(Routes.splash)));
    expect(locais.last, Routes.consentimento);
  });
}
