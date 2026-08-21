import 'package:share_plus/share_plus.dart';

import '../core/deep_link.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';

/// Abre a folha de compartilhamento do sistema com um resumo da denuncia.
Future<void> compartilharOcorrencia(OcorrenciaModel o) async {
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

  await Share.share(
    texto.toString(),
    subject: 'Denuncia EcoJP',
  );
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
