/// Otimização de *entrega* de imagens do Cloudinary.
///
/// As fotos são enviadas em resolução original (uma foto de celular pode ter
/// vários MB e milhares de pixels — ver [CloudinaryService.uploadImage]).
/// Exibi-las cruas, sobretudo em thumbnails e no scroll do feed, desperdiça
/// banda, memória de *decode* e trava a rolagem.
///
/// Este helper injeta transformações de entrega na URL, executadas pelo CDN
/// do Cloudinary sem alterar o arquivo original:
///   • `f_auto`  → formato moderno (WebP/AVIF) quando o cliente suporta;
///   • `q_auto`  → qualidade adaptativa (menos bytes, sem perda perceptível);
///   • `w_`/`c_` → redimensiona no servidor para o tamanho realmente exibido.
///
/// URLs que não são do Cloudinary (ex.: foto de perfil do Google) voltam
/// intactas, então é seguro passar qualquer URL de imagem.
library;

const String _cloudinaryHost = 'res.cloudinary.com';
const String _uploadMarker = '/upload/';

/// Retorna [url] com transformações de entrega do Cloudinary para exibir a
/// imagem em ~[larguraLogica] pixels lógicos, considerando o
/// [devicePixelRatio] da tela (passe `MediaQuery.devicePixelRatioOf(context)`
/// para nitidez em telas 2x/3x).
///
/// [crop] `limit` (padrão) só reduz e preserva a proporção — ideal para
/// `BoxFit.contain`/`cover`. Use `fill` junto com [alturaLogica] para
/// thumbnails de tamanho fixo (recorta com foco automático via `g_auto`).
///
/// Idempotente: se a URL já tiver transformações injetadas, é devolvida como
/// está (não empilha `f_auto` duas vezes).
String cloudinaryOtimizada(
  String url, {
  required double larguraLogica,
  double? alturaLogica,
  double devicePixelRatio = 1.0,
  String crop = 'limit',
}) {
  if (!url.contains(_cloudinaryHost)) return url;
  final marker = url.indexOf(_uploadMarker);
  if (marker == -1) return url;

  // Já otimizada? O segmento logo após /upload/ numa URL crua é a versão
  // (vNNN) ou o caminho do arquivo; nunca começa com o nosso `f_auto`.
  final afterUpload = url.substring(marker + _uploadMarker.length);
  if (afterUpload.startsWith('f_auto')) return url;

  final buffer = StringBuffer(
      'f_auto,q_auto,c_$crop,w_${_px(larguraLogica, devicePixelRatio)}');
  if (alturaLogica != null) {
    buffer.write(',h_${_px(alturaLogica, devicePixelRatio)},g_auto');
  }

  final insertAt = marker + _uploadMarker.length;
  return '${url.substring(0, insertAt)}$buffer/$afterUpload';
}

/// URL de avatar quadrado do Cloudinary para um `CircleAvatar` de raio
/// [radius]. Usa DPR fixo de 3x — avatares são pequenos, então pedir 3x garante
/// nitidez em qualquer tela sem precisar de `context` (evita encadear
/// `MediaQuery` por métodos auxiliares que não recebem `BuildContext`).
String cloudinaryAvatar(String url, {required double radius}) =>
    cloudinaryOtimizada(
      url,
      larguraLogica: radius * 2,
      alturaLogica: radius * 2,
      devicePixelRatio: 3,
      crop: 'fill',
    );

/// Largura em pixels físicos para o `cacheWidth` do `Image.network`/`ResizeImage`,
/// limitando a resolução de *decode* em memória ao que de fato será exibido.
/// Protege mesmo quando a URL não é do Cloudinary (ex.: foto do Google).
int cacheLarguraPx(double larguraLogica, double devicePixelRatio) =>
    _px(larguraLogica, devicePixelRatio);

int _px(double logico, double dpr) => (logico * dpr).round().clamp(16, 2000);

final _fotoPublicaPermitida = RegExp(
  r'^https://(res\.cloudinary\.com/dmdghbgac/image/upload/|lh3\.googleusercontent\.com/)',
);

/// [url] se for de um host aceito pelas regras para foto pública (Cloudinary
/// do projeto ou avatar do Google), senão `null`. Espelha
/// `isOptionalPublicPhoto` em firestore.rules: gravar outra URL faria a
/// escrita inteira (comentário, denúncia, perfil) ser negada.
String? fotoPublicaPermitida(String? url) =>
    url != null && url.length <= 2048 && _fotoPublicaPermitida.hasMatch(url)
        ? url
        : null;

const String _videoUploadMarker = '/video/upload/';

/// Primeiro quadro de um vídeo do Cloudinary como JPG (`so_0`), para mostrar
/// no lugar do player até a pessoa apertar play. `null` se a URL não for de
/// vídeo do Cloudinary.
String? cloudinaryVideoThumbnail(String url, {int largura = 720}) {
  final i = url.indexOf(_videoUploadMarker);
  if (!url.contains(_cloudinaryHost) || i == -1) return null;
  final depois = url.substring(i + _videoUploadMarker.length);
  final semExtensao = depois.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '');
  return '${url.substring(0, i)}$_videoUploadMarker'
      'so_0,f_jpg,q_auto,w_$largura/$semExtensao.jpg';
}

/// Versão de reprodução de um vídeo do Cloudinary: qualidade automática e
/// no máximo [largura] px, em vez do arquivo original (até 50 MB). URLs de
/// fora do Cloudinary voltam como estão.
String cloudinaryVideoOtimizado(String url, {int largura = 720}) {
  final i = url.indexOf(_videoUploadMarker);
  if (!url.contains(_cloudinaryHost) || i == -1) return url;
  final depois = url.substring(i + _videoUploadMarker.length);
  if (depois.startsWith('q_auto')) return url;
  return '${url.substring(0, i)}$_videoUploadMarker'
      'q_auto,vc_auto,c_limit,w_$largura/$depois';
}
