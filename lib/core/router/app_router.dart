import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../pages/cadastro_page.dart';
import '../../pages/fila_moderacao_page.dart';
import '../../pages/fila_verificacao_page.dart';
import '../../pages/form_ocorrencia_page.dart';
import '../../pages/home_shell.dart';
import '../../pages/inicial_page.dart';
import '../../pages/legal/consentimento_page.dart';
import '../../pages/login_page.dart';
import '../../pages/notificacoes_page.dart';
import '../../pages/ocorrencia_deep_link_page.dart';
import '../../pages/perfil/perfil_publico_page.dart';
import '../../pages/verificacao_email_page.dart';
import 'routes.dart';

/// Router central do app. Substitui o `AuthCheck`/`_ConsentGate` que ficavam
/// no `main.dart` por um `redirect` declarativo, que reage a login/logout,
/// verificação de e-mail e consentimento (LGPD).
final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const _SplashScreen()),
      GoRoute(path: Routes.inicial, builder: (context, state) => const InicialPage()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginPage()),
      GoRoute(path: Routes.cadastro, builder: (context, state) => const CadastroPage()),
      GoRoute(
        path: Routes.verificacaoEmail,
        builder: (context, state) => const VerificacaoEmailPage(),
      ),
      GoRoute(
        path: Routes.consentimento,
        builder: (context, state) => ConsentimentoPage(
          onAceitar: () async {
            final user = ref.read(authServiceProvider).currentUser;
            if (user == null) return;
            await ref.read(consentServiceProvider).registrar(user.uid);
            // Recalcula o gate de consentimento → o redirect leva para /home.
            ref.invalidate(consentStatusProvider);
          },
        ),
      ),
      GoRoute(path: Routes.home, builder: (context, state) => const HomeShell()),
      GoRoute(
        path: Routes.formOcorrencia,
        builder: (context, state) => const FormOcorrenciaPage(),
      ),
      GoRoute(
        path: Routes.filaVerificacao,
        builder: (context, state) => const FilaVerificacaoPage(),
      ),
      GoRoute(
        path: Routes.filaModeracao,
        builder: (context, state) => const FilaModeracaoPage(),
      ),
      GoRoute(
        path: Routes.notificacoes,
        builder: (context, state) => const NotificacoesPage(),
      ),
      GoRoute(
        path: Routes.perfilPublico,
        builder: (_, state) {
          final extra = state.extra! as PerfilPublicoArgs;
          return PerfilPublicoPage(
            userId: extra.userId,
            fallbackName: extra.fallbackName,
            fallbackPhotoUrl: extra.fallbackPhotoUrl,
          );
        },
      ),
      GoRoute(
        path: '${Routes.ocorrencia}/:id',
        builder: (_, state) =>
            OcorrenciaDeepLinkPage(id: state.pathParameters['id'] ?? ''),
      ),
    ],
  );
});

/// Ponte entre os providers do Riverpod e o `refreshListenable` do GoRouter:
/// quando o estado de auth ou de consentimento muda, notifica o router para
/// reavaliar o [redirect].
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateChangesProvider, (previous, next) => notifyListeners());
    _ref.listen(consentStatusProvider, (previous, next) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateChangesProvider);
    final loc = state.matchedLocation;

    // Enquanto o Firebase resolve a sessão inicial, segura na splash.
    if (authState.isLoading || !authState.hasValue) {
      return loc == Routes.splash ? null : Routes.splash;
    }

    final user = authState.value;

    // Não autenticado: só telas públicas.
    if (user == null) {
      const publicas = {Routes.inicial, Routes.login, Routes.cadastro};
      return publicas.contains(loc) ? null : Routes.inicial;
    }

    // Conta e-mail/senha sem confirmar → trava de verificação de e-mail.
    final apenasSenha = user.providerData.every(
      (p) => p.providerId == 'password',
    );
    if (apenasSenha && !user.emailVerified) {
      return loc == Routes.verificacaoEmail ? null : Routes.verificacaoEmail;
    }

    // Trava de consentimento (LGPD).
    final consentState = _ref.read(consentStatusProvider);
    if (consentState.isLoading || !consentState.hasValue) {
      return loc == Routes.splash ? null : Routes.splash;
    }
    if (consentState.value ?? false) {
      return loc == Routes.consentimento ? null : Routes.consentimento;
    }

    // Totalmente autenticado: sai de qualquer tela de "portão".
    const portoes = {
      Routes.splash,
      Routes.inicial,
      Routes.login,
      Routes.cadastro,
      Routes.verificacaoEmail,
      Routes.consentimento,
    };
    if (portoes.contains(loc)) return Routes.home;
    return null;
  }
}

/// Tela mínima exibida enquanto o estado de auth/consentimento é resolvido.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
