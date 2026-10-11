import 'package:flutter/foundation.dart';

/// Executa [operacao], registra qualquer erro com o contexto [acao] no formato
/// padrão "Erro ao <acao>: <erro>" e re-lança para o chamador tratar.
///
/// Centraliza o boilerplate try/log/rethrow das camadas de dados e serviço.
/// É também o ponto único para, no futuro, encaminhar esses erros ao
/// Crashlytics (`recordError(e, s, reason: acao)`) sem tocar em cada método.
Future<T> comLogDeErro<T>(String acao, Future<T> Function() operacao) async {
  try {
    return await operacao();
  } catch (e) {
    debugPrint('Erro ao $acao: $e');
    rethrow;
  }
}
