import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crashlytics só existe em Android, iOS e macOS. No web e no Windows
/// qualquer chamada a `FirebaseCrashlytics.instance` lança, e fazê-la na
/// inicialização derrubava o app antes do runApp.
bool get crashlyticsDisponivel {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS =>
      Firebase.apps.isNotEmpty,
    _ => false,
  };
}

/// Registra [erro] no Crashlytics quando disponível; senão só no console.
Future<void> registrarErro(
  Object erro,
  StackTrace? stack, {
  String? motivo,
  bool fatal = false,
}) async {
  if (!crashlyticsDisponivel) {
    debugPrint('Erro${motivo == null ? '' : ' ($motivo)'}: $erro');
    return;
  }
  await FirebaseCrashlytics.instance.recordError(
    erro,
    stack,
    reason: motivo,
    fatal: fatal,
  );
}
