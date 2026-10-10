import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/deep_link.dart';
import 'core/inicializacao.dart';
import 'core/sessao_unica.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_mode_provider.dart';
import 'pages/inicializacao_erro_page.dart';
import 'pages/splash_page.dart';
import 'theme/app_theme.dart';
import 'theme/brand_fonts.dart';
import 'utils/crashlytics.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      BrandFonts.registrarLicencas();
      // Nada de await aqui: a splash Flutter aparece já no primeiro frame e
      // a inicialização (Firebase etc.) corre por trás dela, em
      // inicializacaoProvider.
      runApp(const ProviderScope(child: EcoJpApp()));
    },
    (error, stack) {
      // Erros fora da árvore de widgets (streams, futures soltos) também vão
      // pro Crashlytics, quando o Firebase já foi inicializado com sucesso.
      registrarErro(error, stack, fatal: true);
    },
  );
}

/// Raiz do app: segura a splash enquanto a inicialização roda e só então
/// monta o [MyApp] (o router e os serviços usam o Firebase na criação).
class EcoJpApp extends ConsumerWidget {
  const EcoJpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Começa a contar os 3 s da splash já na abertura; quem espera por eles
    // é o redirect do router (ver app_router.dart).
    ref.watch(splashMinimoProvider);
    final inicializacao = ref.watch(inicializacaoProvider);

    // isLoading antes de hasError: ao tentar de novo, volta para a splash em
    // vez de continuar mostrando o erro anterior.
    if (inicializacao.isLoading) {
      return const _AppSemRouter(home: SplashPage());
    }
    if (inicializacao.hasError) {
      return _AppSemRouter(
        home: InicializacaoErroPage(
          onTentarNovamente: () => ref.invalidate(inicializacaoProvider),
        ),
      );
    }
    return const MyApp();
  }
}

class _AppSemRouter extends StatelessWidget {
  const _AppSemRouter({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoJP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: home,
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return SessaoUnicaListener(
      child: DeepLinkListener(
        child: MaterialApp.router(
          title: 'EcoJP',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerGlobal,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}
