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
import 'utils/crashlytics.dart';

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

        // App Check: attesta que as chamadas ao Firestore vêm de uma instância
        // legítima do app oficial, e não de um script com a chave extraída do
        // APK. Sem isso, qualquer pessoa que descompile o binário consegue
        // consumir a cota de leitura do projeto (ver Política de Privacidade,
        // item 5, que declara esta proteção ao usuário).
        //
        // Em debug usamos o provedor de depuração: ele imprime um token no
        // console na primeira execução, que precisa ser registrado em
        // Firebase Console → App Check → Apps → Gerenciar tokens de depuração.
        // Sem esse registro, o app de desenvolvimento é bloqueado quando a
        // imposição (enforcement) estiver ligada no Console.
        //
        // IMPORTANTE: ativar aqui NÃO impõe nada sozinho. A imposição é um
        // botão no Console (App Check → APIs → Cloud Firestore → Impor). Ligue
        // esse botão só depois de confirmar, na aba de métricas do Console, que
        // as requisições já chegam com token válido — caso contrário o app em
        // produção para de funcionar de uma vez.
        //
        // Web: reCAPTCHA v3, com a chave de site registrada em App Check →
        // Apps → Web e passada no build com
        //   --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=<chave>
        // Sem a chave o web não recebe token e seria bloqueado quando a
        // imposição for ligada.
        const chaveRecaptcha = String.fromEnvironment(
          'APP_CHECK_RECAPTCHA_SITE_KEY',
        );
        if (kIsWeb && chaveRecaptcha.isEmpty) {
          debugPrint(
            'App Check: APP_CHECK_RECAPTCHA_SITE_KEY ausente; web sem token.',
          );
        } else {
          await FirebaseAppCheck.instance.activate(
            providerWeb: kIsWeb ? ReCaptchaV3Provider(chaveRecaptcha) : null,
            providerAndroid: kDebugMode
                ? const AndroidDebugProvider()
                : const AndroidPlayIntegrityProvider(),
            providerApple: kDebugMode
                ? const AppleDebugProvider()
                : const AppleAppAttestWithDeviceCheckFallbackProvider(),
          );
        }

        // Crashlytics: desativado em debug (evita poluir o console com
        // crashes de desenvolvimento) e captura erros do Flutter framework +
        // erros não tratados fora dele (o runZonedGuarded cobre o resto).
        // Só nas plataformas que o suportam (ver crashlyticsDisponivel).
        if (crashlyticsDisponivel) {
          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
            !kDebugMode,
          );
          FlutterError.onError =
              FirebaseCrashlytics.instance.recordFlutterFatalError;
        }

        runApp(const ProviderScope(child: MyApp()));
      } catch (e) {
        // Se o Firebase não inicializar, mostra uma tela de erro em vez de tela branca.
        runApp(const _AppErroInicializacao());
      }
    },
    (error, stack) {
      // Erros fora da árvore de widgets (streams, futures soltos) também vão
      // pro Crashlytics, quando o Firebase já foi inicializado com sucesso.
      registrarErro(error, stack, fatal: true);
    },
  );
}

class _AppErroInicializacao extends StatelessWidget {
  const _AppErroInicializacao();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0A1018),
        body: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
