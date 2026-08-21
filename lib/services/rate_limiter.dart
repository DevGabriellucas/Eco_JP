/// Limitador de frequência client-side. Bloqueia ações repetidas rápido demais
/// (spam de denúncias/comentários) guardando o timestamp da última ação de cada
/// tipo em memória.
///
/// AVISO: proteção só de UX/conveniência — o estado vive na memória do app e
/// zera ao reiniciar, então um usuário mal-intencionado consegue burlar. A
/// proteção real contra spam é server-side (Cloud Functions + regras),
/// pendente do plano Blaze. Ver roadmap v2.0.
class RateLimiter {
  RateLimiter._();
  static final RateLimiter instance = RateLimiter._();

  // Última execução registrada por chave de ação.
  final Map<String, DateTime> _ultimaAcao = {};

  /// Intervalos mínimos entre ações do mesmo tipo.
  static const Duration intervaloDenuncia = Duration(seconds: 30);
  static const Duration intervaloComentario = Duration(seconds: 5);

  /// Tempo restante até a ação [chave] poder ser repetida, ou `Duration.zero`
  /// se já está liberada.
  Duration tempoRestante(String chave, Duration intervalo) {
    final ultima = _ultimaAcao[chave];
    if (ultima == null) return Duration.zero;
    final decorrido = DateTime.now().difference(ultima);
    final restante = intervalo - decorrido;
    return restante.isNegative ? Duration.zero : restante;
  }

  /// True se a ação [chave] pode ser executada agora.
  bool permitido(String chave, Duration intervalo) =>
      tempoRestante(chave, intervalo) == Duration.zero;

  /// Registra que a ação [chave] acabou de acontecer (inicia a contagem).
  void registrar(String chave) {
    _ultimaAcao[chave] = DateTime.now();
  }

  /// Verifica o limite e, se liberado, já registra a ação. Lança
  /// [RateLimitException] se ainda estiver dentro do intervalo de bloqueio.
  void checarERegistrar(String chave, Duration intervalo) {
    final restante = tempoRestante(chave, intervalo);
    if (restante > Duration.zero) {
      throw RateLimitException(restante);
    }
    registrar(chave);
  }
}

/// Ação bloqueada por acontecer rápido demais. Carrega quanto tempo falta.
class RateLimitException implements Exception {
  final Duration tempoRestante;
  const RateLimitException(this.tempoRestante);

  int get segundosRestantes => tempoRestante.inSeconds + 1;

  @override
  String toString() =>
      'Aguarde $segundosRestantes segundo(s) antes de tentar novamente.';
}
