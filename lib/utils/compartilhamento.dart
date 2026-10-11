import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../core/deep_link.dart';
import '../data/repositories/ocorrencia_repository.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';

/// Abre a folha de compartilhamento do sistema com um resumo da denúncia.
///
/// Retorna true quando o envio foi concluído — nesse caso o contador `shares`
/// já foi somado em [o] e no Firestore. Cancelar a folha não conta.
///
/// [origem] é a área do botão que abriu a folha; o iPad precisa dela para
/// ancorar o popover.
Future<bool> compartilharOcorrencia(
  OcorrenciaModel o, {
  OcorrenciaRepository? repository,
  Rect? origem,
}) async {
  final resultado = await SharePlus.instance.share(
    ShareParams(
      text: textoCompartilhamento(o),
      subject: 'Denúncia no EcoJP: ${_titulo(o)}',
      sharePositionOrigin: origem,
    ),
  );

  // Android nem sempre sabe se o usuário concluiu o envio e devolve
  // `unavailable`; só `dismissed` significa cancelamento explícito.
  if (resultado.status == ShareResultStatus.dismissed) return false;

  try {
    // Só conta a primeira vez de cada usuário (ver regras).
    final contou = await (repository ?? OcorrenciaRepository())
        .incrementarCompartilhamento(o.id);
    if (contou) o.shares++;
  } catch (e) {
    // Contador é informativo: falhar a gravação não invalida o
    // compartilhamento, que já aconteceu do ponto de vista do usuário.
    debugPrint('Erro ao contar compartilhamento: $e');
  }
  return true;
}

/// Texto enviado ao compartilhar [o].
///
/// A ordem pensa em quem recebe pelo WhatsApp: o que é, onde, a descrição e
/// os links clicáveis. O link `ecojp://` só abre com o app instalado e os
/// apps de conversa não o deixam clicável, por isso vai por último.
@visibleForTesting
String textoCompartilhamento(OcorrenciaModel o) {
  final categoria = OccurrenceTypeParser.fromString(o.tipoLixo).label;
  final mapaUrl = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '${o.latitude},${o.longitude}',
  });

  final texto = StringBuffer()
    ..writeln('Denúncia no EcoJP')
    ..writeln('$categoria: ${_titulo(o)}');

  if (o.localizacao.trim().isNotEmpty) {
    texto.writeln('Local: ${o.localizacao.trim()}');
  }

  if (o.descricao.trim().isNotEmpty) {
    texto
      ..writeln()
      ..writeln(o.descricao.trim());
  }

  texto
    ..writeln()
    ..writeln('Ver no mapa: $mapaUrl');

  final video = o.videoUrl?.trim();
  final midia = _midiaPrincipal(o);
  if (midia != null) {
    final rotulo = (video != null && video.isNotEmpty) ? 'Vídeo' : 'Foto';
    texto.writeln('$rotulo: $midia');
  }

  texto
    ..writeln()
    ..writeln('Tem o app EcoJP? Abra direto: ${deepLinkOcorrencia(o.id)}');

  return texto.toString().trim();
}

/// Área na tela do widget de [context], usada como origem da folha de
/// compartilhamento no iPad.
Rect? origemDoWidget(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

String _titulo(OcorrenciaModel o) =>
    o.titulo.trim().isEmpty ? 'Sem título' : o.titulo.trim();

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
