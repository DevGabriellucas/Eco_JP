import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/comentario_repository.dart';
import '../../../data/repositories/ocorrencia_repository.dart';

/// Repositório da coleção `ocorrencias` (denúncias) por injeção de dependência.
/// Ponto único de acesso — todas as telas de denúncia consomem por aqui em vez
/// de instanciar `OcorrenciaRepository()` diretamente, o que também torna a
/// dependência mockável nos testes.
final ocorrenciaRepositoryProvider =
    Provider<OcorrenciaRepository>((ref) => OcorrenciaRepository());

/// Repositório da subcoleção `comentarios`.
final comentarioRepositoryProvider =
    Provider<ComentarioRepository>((ref) => ComentarioRepository());
