import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/comentario_repository.dart';
import '../../../data/repositories/ocorrencia_repository.dart';
import '../../../models/ocorrencia_model.dart';

/// Repositório da coleção `ocorrencias` (denúncias) por injeção de dependência.
/// Ponto único de acesso — todas as telas de denúncia consomem por aqui em vez
/// de instanciar `OcorrenciaRepository()` diretamente, o que também torna a
/// dependência mockável nos testes.
final ocorrenciaRepositoryProvider =
    Provider<OcorrenciaRepository>((ref) => OcorrenciaRepository());

/// Repositório da subcoleção `comentarios`.
final comentarioRepositoryProvider =
    Provider<ComentarioRepository>((ref) => ComentarioRepository());

/// Denúncia que o feed deve focar (rolar até ela e destacar). Usado quando a
/// autoridade toca em "Abrir" na fila de verificação: em vez de abrir a página
/// de detalhe, voltamos ao feed com esta denúncia em foco. O feed consome,
/// executa o scroll/destaque e limpa o valor (volta a null). Guardamos o
/// modelo inteiro para garantir a exibição mesmo que a denúncia ainda não
/// tenha sido carregada pela paginação do feed.
final feedFocoOcorrenciaProvider = StateProvider<OcorrenciaModel?>((ref) => null);

/// ID do comentário que o feed deve focar (destacar). Usado quando a
/// autoridade toca em "Ver" na fila de moderação para um comentário:
/// a denúncia é aberta em foco (via feedFocoOcorrenciaProvider) e este
/// provider armazena o ID do comentário para que ele seja destacado.
final feedFocoComentarioProvider = StateProvider<String?>((ref) => null);
