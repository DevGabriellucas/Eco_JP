/// Caminhos de rota centralizados. Evita strings soltas espalhadas pelo app
/// (antes cada `pushNamed('/login')` repetia a string literal).
abstract final class Routes {
  const Routes._();

  static const String splash = '/splash';
  static const String inicial = '/inicial';
  static const String login = '/login';
  static const String cadastro = '/cadastro';
  static const String verificacaoEmail = '/verificacao-email';
  static const String consentimento = '/consentimento';
  static const String home = '/home';
  static const String formOcorrencia = '/form-ocorrencia';
  static const String filaVerificacao = '/fila-verificacao';
  static const String filaModeracao = '/fila-moderacao';
  static const String notificacoes = '/notificacoes';
  static const String perfilPublico = '/perfil-publico';

  /// Detalhe de uma ocorrência por id. Usada por deeplinks
  /// (`ecojp://ocorrencia/<id>`) e navegação interna: `/ocorrencia/:id`.
  static const String ocorrencia = '/ocorrencia';
}

/// Argumentos passados via `extra` para a rota [Routes.perfilPublico] —
/// carrega o fallback de nome/foto (denúncia pode não ter os dados do autor
/// carregados ainda), então não dá pra reduzir a um simples `:userId` na URL.
class PerfilPublicoArgs {
  const PerfilPublicoArgs({
    required this.userId,
    required this.fallbackName,
    this.fallbackPhotoUrl,
  });

  final String userId;
  final String fallbackName;
  final String? fallbackPhotoUrl;
}
