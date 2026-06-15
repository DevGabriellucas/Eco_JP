// Utilitários de texto.

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';

/// Remove acentos/diacríticos de [texto], preservando os demais caracteres.
/// Útil para buscas e para gerar identificadores a partir de nomes.
String removerAcentos(String texto) {
  final buffer = StringBuffer();
  for (final char in texto.split('')) {
    final i = _comAcento.indexOf(char);
    buffer.write(i == -1 ? char : _semAcento[i]);
  }
  return buffer.toString();
}

/// Gera um identificador estável (kebab-case, sem acentos) a partir de [texto].
/// Ex.: "Cidade Verde (Mangabeira)" -> "cidade-verde-mangabeira".
String slugify(String texto) {
  return removerAcentos(texto)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
