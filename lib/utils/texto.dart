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

/// True se o code point [c] é invisível/perigoso e não deve ser persistido em
/// texto de usuário. Testado por code point (não por regex com literais
/// invisíveis) para manter o código-fonte 100% ASCII e legível. Cobre:
///   • Controle C0 (< 0x20) exceto tab (0x09) e newline (0x0A);
///   • DEL (0x7F) e controle C1 (0x80–0x9F);
///   • Zero-width — ZWSP/ZWNJ/ZWJ (0x200B–0x200D) e BOM/ZWNBSP (0xFEFF),
///     usados para inflar o tamanho e ofuscar conteúdo;
///   • Marcas bidirecionais — overrides (0x202A–0x202E) e isolates
///     (0x2066–0x2069), usadas para spoofing visual (ex.: um nome que "parece"
///     outro invertendo a direção do texto).
bool _codePointRemovivel(int c) {
  if (c < 0x20) return c != 0x09 && c != 0x0A;
  if (c == 0x7F) return true;
  if (c >= 0x80 && c <= 0x9F) return true;
  if (c >= 0x200B && c <= 0x200D) return true;
  if (c == 0xFEFF) return true;
  if (c >= 0x202A && c <= 0x202E) return true;
  if (c >= 0x2066 && c <= 0x2069) return true;
  return false;
}

/// Higieniza texto vindo do usuário antes de persistir: remove caracteres de
/// controle, zero-width e marcas bidirecionais, e apara espaços nas pontas.
///
/// Preserva quebras de linha — descrições e comentários podem ter parágrafos
/// legítimos. Para campos que devem ser uma única linha (título, nome,
/// localização), use [sanitizarLinhaUnica].
///
/// Defesa em profundidade: o cliente já valida tamanho e as Firestore Rules
/// rejeitam conteúdo em branco (`naoEmBranco`), mas a limpeza garante que o
/// dado gravado é seguro para qualquer consumidor futuro (export em PDF, painel
/// web) e que zero-width/bidi não burlem os limites de tamanho.
String sanitizarTexto(String texto) {
  final buffer = StringBuffer();
  for (final rune in texto.runes) {
    if (_codePointRemovivel(rune)) continue;
    buffer.writeCharCode(rune);
  }
  return buffer.toString().trim();
}

/// Como [sanitizarTexto], mas força uma única linha: troca qualquer quebra de
/// linha/tab por espaço e colapsa espaços repetidos. Para título, nome e
/// localização.
String sanitizarLinhaUnica(String texto) {
  return sanitizarTexto(texto).replaceAll(RegExp(r'\s+'), ' ').trim();
}
