import 'package:firebase_analytics/firebase_analytics.dart';

/// Eventos de uso do EcoJP. Centralizado para manter os nomes de evento
/// consistentes — evita strings soltas divergentes espalhadas pelo app.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> denunciaCriada({
    required String categoria,
    required bool anonima,
  }) => _analytics.logEvent(
    name: 'denuncia_criada',
    parameters: {'categoria': categoria, 'anonima': anonima},
  );

  Future<void> statusAvancado({
    required String statusOficial,
  }) => _analytics.logEvent(
    name: 'status_avancado',
    parameters: {'status_oficial': statusOficial},
  );

  Future<void> denunciaDeAbusoCriada({required String alvoTipo}) =>
      _analytics.logEvent(
        name: 'denuncia_abuso_criada',
        parameters: {'alvo_tipo': alvoTipo},
      );

  Future<void> dadosExportados() =>
      _analytics.logEvent(name: 'dados_exportados');

  Future<void> login({required String metodo}) =>
      _analytics.logLogin(loginMethod: metodo);

  Future<void> cadastro({required String metodo}) =>
      _analytics.logSignUp(signUpMethod: metodo);

  /// Associa eventos subsequentes ao usuário logado (sem dado pessoal, só o
  /// UID já usado nas demais coleções do Firestore).
  Future<void> definirUsuario(String? uid) => _analytics.setUserId(id: uid);
}
