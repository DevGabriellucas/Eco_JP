import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/deep_link.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_mode_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Persistência offline do Firestore: guarda em disco os dados já
        // buscados (denúncias, perfis, comentários) para o app abrir e navegar
        // mesmo sem internet, servindo do cache. Cache sem limite de tamanho.
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );

        await FirebaseAppCheck.instance.activate(
          // Em produção Android usa Play Integrity (validado pela Play Store).
          // Em debug/emulador usa o provider de depuração pra não bloquear testes.
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          // Mesma lógica no Apple: App Attest em produção (exige dispositivo
          // real e conta Apple Developer), debug provider só em kDebugMode —
          // sem isso, o App Check ficava sem proteção real em builds iOS
          // de produção mesmo fora do modo debug.
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestProvider(),
        );

        // Crashlytics: desativado em debug (evita poluir o console com
        // crashes de desenvolvimento) e captura erros do Flutter framework +
        // erros não tratados fora dele (o runZonedGuarded cobre o resto).
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          !kDebugMode,
        );
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;

        runApp(const ProviderScope(child: MyApp()));
      } catch (e) {
        // Se o Firebase não inicializar, mostra uma tela de erro em vez de tela branca.
        runApp(const _AppErroInicializacao());
      }
    },
    (error, stack) {
      // Erros fora da árvore de widgets (streams, futures soltos) também vão
      // pro Crashlytics, quando o Firebase já foi inicializado com sucesso.
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

class _AppErroInicializacao extends StatelessWidget {
  const _AppErroInicializacao();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A1018),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.cloud_off, color: Colors.white70, size: 64),
                SizedBox(height: 20),
                Text(
                  'Não foi possível conectar ao servidor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Verifique sua conexão com a internet e abra o aplicativo novamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return DeepLinkListener(
      child: MaterialApp.router(
        title: 'EcoJP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
