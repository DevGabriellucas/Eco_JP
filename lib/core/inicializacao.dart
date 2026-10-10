import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../utils/crashlytics.dart';

/// Tempo mínimo da splash. Lido pela raiz do app no primeiro build, para o
/// relógio começar na abertura e correr junto com a inicialização: o total
/// é max(3 s, inicialização), não a soma.
final splashMinimoProvider = FutureProvider<void>(
  (ref) => Future<void>.delayed(const Duration(seconds: 3)),
);

/// Tudo que precisa estar pronto antes de montar o app (o router e os
/// serviços usam o Firebase já na criação). Os passos independentes correm
/// em paralelo. Passou de 15 s, vira erro e a tela oferece tentar de novo,
/// em vez de deixar a pessoa presa na splash.
final inicializacaoProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    _inicializarFirebase(),
    // Aquece o shared_preferences (tema salvo) para a primeira tela já abrir
    // no tema certo.
    SharedPreferences.getInstance(),
  ]).timeout(const Duration(seconds: 15));
});

Future<void> _inicializarFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Persistência offline do Firestore: guarda em disco os dados já
  // buscados (denúncias, perfis, comentários) para o app abrir e navegar
  // mesmo sem internet, servindo do cache. Cache sem limite de tamanho.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await Future.wait([_ativarAppCheck(), _configurarCrashlytics()]);
}

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
Future<void> _ativarAppCheck() async {
  const chaveRecaptcha = String.fromEnvironment('APP_CHECK_RECAPTCHA_SITE_KEY');
  if (kIsWeb && chaveRecaptcha.isEmpty) {
    debugPrint(
      'App Check: APP_CHECK_RECAPTCHA_SITE_KEY ausente; web sem token.',
    );
    return;
  }
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
Future<void> _configurarCrashlytics() async {
  if (!crashlyticsDisponivel) return;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
}
