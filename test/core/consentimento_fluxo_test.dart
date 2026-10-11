import 'dart:async';

import 'package:eco_jp/core/inicializacao.dart';
import 'package:eco_jp/core/router/app_router.dart';
import 'package:eco_jp/core/router/routes.dart';
import 'package:eco_jp/features/auth/providers/auth_providers.dart';
import 'package:eco_jp/models/usuario_model.dart';
import 'package:eco_jp/services/auth_service.dart';
import 'package:eco_jp/services/consent_service.dart';
import 'package:eco_jp/services/usuario_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conta verificada (como a do Google) entrando pela 1ª vez.
class _AuthFalso extends Fake implements AuthService {
  _AuthFalso(this.usuario, this.emitir);

  final User usuario;
  final void Function(User?) emitir;
  bool saiu = false;

  @override
  User? get currentUser => saiu ? null : usuario;

  @override
  Future<void> sair() async {
    saiu = true;
    emitir(null);
  }
}

class _ConsentFalso extends Fake implements ConsentService {
  bool consentiu = false;

  @override
  Future<bool> precisaConsentir(String uid) async => !consentiu;

  @override
  Future<bool> registrar(String uid) async {
    consentiu = true;
    return true;
  }
}

/// Conta quantas vezes o perfil público foi criado. A criação fica pendente
/// (como uma gravação no Firestore em andamento), o que segura a navegação
/// na tela de consentimento sem precisar montar a home.
class _UsuarioFalso extends Fake implements UsuarioService {
  int perfisCriados = 0;
  final _pendente = Completer<UsuarioModel>();

  @override
  Future<UsuarioModel> garantirPerfil(
    String uid, {
    String? nomeSugerido,
    String? fotoUrl,
  }) {
    perfisCriados++;
    return _pendente.future;
  }
}

void main() {
  late StreamController<User?> auth;
  late _AuthFalso authFalso;
  late _ConsentFalso consent;
  late _UsuarioFalso usuarios;
  late ProviderContainer container;
  User? atual;

  // Criados dentro do teste (zona do relógio falso), como em app_router_test.
  Future<void> montar(WidgetTester tester) async {
    auth = StreamController<User?>.broadcast();
    final usuario = MockUser(uid: 'g1', displayName: 'Maria Google');
    atual = usuario;
    authFalso = _AuthFalso(usuario, (u) {
      atual = u;
      auth.add(u);
    });
    consent = _ConsentFalso();
    usuarios = _UsuarioFalso();
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authFalso),
        consentServiceProvider.overrideWithValue(consent),
        usuarioServiceProvider.overrideWithValue(usuarios),
        splashMinimoProvider.overrideWith((ref) async {}),
        authStateChangesProvider.overrideWith((ref) async* {
          yield atual;
          yield* auth.stream;
        }),
      ],
    );
    addTearDown(() {
      container.dispose();
      auth.close();
    });

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child:
            MaterialApp.router(routerConfig: container.read(goRouterProvider)),
      ),
    );
    await tester.pumpAndSettle();
  }

  String local() => container
      .read(goRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  testWidgets('1º login: pede o consentimento ANTES de criar o perfil',
      (tester) async {
    await montar(tester);

    expect(local(), Routes.consentimento);
    // LGPD: nada público gravado antes do aceite.
    expect(usuarios.perfisCriados, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Concordar e continuar'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Só depois do aceite o perfil é criado (uma vez), e a tela espera por
    // ele em vez de piscar a splash.
    expect(consent.consentiu, isTrue);
    expect(usuarios.perfisCriados, 1);
    expect(local(), Routes.consentimento);

    // Encerra sem ir à home (precisaria do Firebase): desmonta o app e só
    // então deixa passar o limite de 10 s da criação do perfil pendente.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('recusar não cria perfil nem reserva nome', (tester) async {
    await montar(tester);
    expect(local(), Routes.consentimento);

    await tester.tap(find.text('Não concordo / sair'));
    await tester.pumpAndSettle();

    expect(local(), Routes.inicial);
    expect(usuarios.perfisCriados, 0);
  });
}
