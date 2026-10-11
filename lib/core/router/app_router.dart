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
import '../../pages/splash_page.dart';
import '../../pages/verificacao_email_page.dart';
import '../inicializacao.dart';
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
      GoRoute(
        path: Routes.splash,
        // Mesmo visual da splash da inicialização, já visível: a troca entre
        // as duas não aparece.
        builder: (context, state) => const SplashPage(animarEntrada: false),
      ),
      GoRoute(
          path: Routes.inicial,
          builder: (context, state) => const InicialPage()),
      GoRoute(
          path: Routes.login, builder: (context, state) => const LoginPage()),
      GoRoute(
          path: Routes.cadastro,
          builder: (context, state) => const CadastroPage()),
      GoRoute(
        path: Routes.verificacaoEmail,
        builder: (context, state) => const VerificacaoEmailPage(),
      ),
      GoRoute(
        path: Routes.consentimento,
        builder: (context, state) => ConsentimentoPage(
          onAceitar: () async {
            final user = ref.read(authServiceProvider).currentUser;
            if (user == null) return true;
            // false = sem internet: o aceite ficou na fila offline do
            // Firestore e a tela avisa que será enviado quando voltar.
            final confirmado =
                await ref.read(consentServiceProvider).registrar(user.uid);
            // Recalcula o gate de consentimento (e, com ele, a criação do
            // perfil) → o redirect leva para /home.
            ref.invalidate(consentStatusProvider);
            return confirmado;
          },
          // Sai da conta; o redirect leva de volta à tela inicial.
          onRecusar: () => ref.read(authServiceProvider).sair(),
        ),
      ),
      GoRoute(
          path: Routes.home, builder: (context, state) => const HomeShell()),
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
        // Sem os argumentos (link externo, restauração de estado) não há
        // perfil a mostrar; antes o `state.extra!` derrubava o app.
        redirect: (_, state) =>
            state.extra is PerfilPublicoArgs ? null : Routes.home,
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
    _ref.listen(
        authStateChangesProvider, (previous, next) => notifyListeners());
    _ref.listen(consentStatusProvider, (previous, next) => notifyListeners());
    _ref.listen(perfilGarantidoProvider, (previous, next) => notifyListeners());
    _ref.listen(
        cadastroEmAndamentoProvider, (previous, next) => notifyListeners());
    _ref.listen(splashMinimoProvider, (previous, next) => notifyListeners());
  }

  final Ref _ref;

  /// Enquanto um estado ainda carrega: sem valor nenhum (abertura do app)
  /// segura na splash; recarregando (já tinha valor) fica na tela atual, sem
  /// decidir com o valor velho. Antes as recargas também iam para a splash:
  /// ao confirmar o e-mail ou depois do login a tela trocava de repente pela
  /// splash verde-escura e só então ia ao destino. O _RouterNotifier reavalia
  /// quando o valor novo chega.
  String? _aguardar(AsyncValue<Object?> estado, String loc) {
    if (!estado.hasValue) return loc == Routes.splash ? null : Routes.splash;
    return null;
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateChangesProvider);
    final loc = state.matchedLocation;

    // Segura na splash até os 3 s mínimos (contados desde a abertura do app)
    // e enquanto o Firebase resolve a sessão inicial.
    final splashMinimo = _ref.read(splashMinimoProvider);
    if (!splashMinimo.hasValue) {
      return loc == Routes.splash ? null : Routes.splash;
    }
    if (authState.isLoading || !authState.hasValue) {
      return _aguardar(authState, loc);
    }

    final user = authState.value;

    // Cadastro criando conta/reserva/perfil: não sai do lugar até terminar
    // (sucesso leva à verificação; nome em uso apaga a conta e mostra o erro).
    //
    // Sem checar `loc == /cadastro`: o cadastro abre por push (inicial →
    // login → cadastro), e no refresh o go_router avalia o redirect com a
    // tela de BAIXO da pilha (/inicial), não com o /cadastro. A trava nunca
    // valia: criar a conta levava na hora à confirmação, o cadastro seguia
    // invisível e, com nome já em uso, apagava a conta — a pessoa via a
    // confirmação e logo era jogada para a inicial, sem mensagem nenhuma.
    // Só o cadastro liga este flag, e o desliga no finally.
    if (_ref.read(cadastroEmAndamentoProvider)) return null;

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

    // Trava de consentimento (LGPD) ANTES do perfil: o perfil é público e
    // reserva o nome, então só pode ser criado depois do aceite (o próprio
    // perfilGarantidoProvider também espera o consentimento).
    final consentState = _ref.read(consentStatusProvider);
    if (consentState.isLoading || !consentState.hasValue) {
      return _aguardar(consentState, loc);
    }
    if (consentState.value ?? false) {
      return loc == Routes.consentimento ? null : Routes.consentimento;
    }

    // Perfil com nome reservado (primeiro login Google cria aqui, depois do
    // aceite). Enquanto cria, a tela de consentimento fica parada com o
    // botão carregando (_aguardar) e depois vai direto à home.
    final perfilState = _ref.read(perfilGarantidoProvider);
    if (perfilState.isLoading || !perfilState.hasValue) {
      return _aguardar(perfilState, loc);
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
