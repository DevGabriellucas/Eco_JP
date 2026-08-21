import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cloudinary_service.dart';
import '../services/rate_limiter.dart';

/// Converte um erro de operação em uma mensagem amigável e específica em PT-BR.
///
/// Antes cada tela mostrava um "Não foi possível concluir a ação" genérico, que
/// não diz o que falhou nem o que fazer. Este mapa traduz as causas mais comuns
/// (offline, permissão, sessão expirada, rate limit, upload de imagem) em um
/// texto acionável, com fallback para [acao] quando a causa é desconhecida.
///
/// [acao] é um trecho curto no infinitivo descrevendo a operação, usado tanto
/// em mensagens específicas quanto no fallback — ex.: "enviar a denúncia",
/// "salvar o perfil", "excluir o comentário".
String mensagemErro(Object erro, {required String acao}) {
  if (erro is RateLimitException) {
    return 'Você está indo rápido demais. Aguarde ${erro.segundosRestantes}s '
        'e tente novamente.';
  }

  if (erro is CloudinaryConfigException || erro is CloudinaryUploadException) {
    return 'Não foi possível enviar a imagem. Verifique a conexão e tente '
        'novamente.';
  }

  if (erro is FirebaseException) {
    switch (erro.code) {
      case 'permission-denied':
        return 'Você não tem permissão para $acao.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'aborted':
        return 'Sem conexão com o servidor. Verifique a internet e tente '
            'novamente.';
      case 'resource-exhausted':
        return 'O serviço está sobrecarregado no momento. Tente novamente em '
            'instantes.';
      case 'unauthenticated':
        return 'Sua sessão expirou. Entre novamente para $acao.';
      case 'not-found':
        return 'O conteúdo não foi encontrado. Ele pode ter sido removido.';
    }
  }

  return 'Não foi possível $acao. Tente novamente.';
}
