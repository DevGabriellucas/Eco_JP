import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../core/deep_link.dart';
import '../data/repositories/ocorrencia_repository.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';

/// Abre a folha de compartilhamento do sistema com um resumo da denuncia.
///
/// Retorna true quando o envio foi concluido — nesse caso o contador `shares`
/// ja foi somado em [o] e no Firestore. Cancelar a folha nao conta.
Future<bool> compartilharOcorrencia(
  OcorrenciaModel o, {
  OcorrenciaRepository? repository,
}) async {
  final categoria = OccurrenceTypeParser.fromString(o.tipoLixo).label;
  final titulo = o.titulo.trim().isEmpty ? 'Sem titulo' : o.titulo.trim();
  final mapaUrl = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '${o.latitude},${o.longitude}',
  });

  final texto = StringBuffer()
    ..writeln('Denuncia no EcoJP')
    ..writeln('$categoria: $titulo')
    ..writeln('Abrir no app: ${deepLinkOcorrencia(o.id)}')
    ..writeln('Codigo EcoJP: ${o.id}');

  if (o.localizacao.trim().isNotEmpty) {
    texto.writeln('Endereco: ${o.localizacao.trim()}');
  }

  texto.writeln('Mapa: $mapaUrl');

  if (o.descricao.trim().isNotEmpty) {
    texto.writeln('\n${o.descricao.trim()}');
  }

  final midia = _midiaPrincipal(o);
  if (midia != null) {
    texto.writeln('\nMidia: $midia');
  }

  final resultado = await SharePlus.instance.share(
    ShareParams(
      text: texto.toString(),
      subject: 'Denuncia EcoJP',
    ),
  );

  // Android nem sempre sabe se o usuario concluiu o envio e devolve
  // `unavailable`; so `dismissed` significa cancelamento explicito.
  if (resultado.status == ShareResultStatus.dismissed) return false;

  o.shares++;
  try {
    await (repository ?? OcorrenciaRepository()).incrementarCompartilhamento(
      o.id,
    );
  } catch (e) {
    // Contador e informativo: falhar a gravacao nao invalida o
    // compartilhamento, que ja aconteceu do ponto de vista do usuario.
    debugPrint('Erro ao contar compartilhamento: $e');
  }
  return true;
}

String? _midiaPrincipal(OcorrenciaModel o) {
  final video = o.videoUrl?.trim();
  if (video != null && video.isNotEmpty) return video;

  if (o.imagensUrls.isNotEmpty) {
    final imagem = o.imagensUrls.first.trim();
    if (imagem.isNotEmpty) return imagem;
  }

  final fallback = o.imagemUrl?.trim();
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return null;
}
