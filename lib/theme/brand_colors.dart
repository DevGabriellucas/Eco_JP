import 'package:flutter/material.dart';

/// Paleta extraída das telas do Figma. Fonte única dessas cores: nas telas,
/// use os tokens, nunca o hex direto (ver docs/DESIGN.md).
///
/// Os nomes descrevem o papel da cor, não a tela onde ela apareceu, para o
/// mesmo token servir a qualquer tela nova.
abstract final class BrandColors {
  // Fundos
  static const brandDeep = Color(0xFF08382E); // verde profundo de marca
  static const background = Color(0xFF1A2420); // fundo de tela escuro

  // Destaque
  static const accent = Color(0xFF52D5A0); // botões primários, links, realces
  static const onAccent =
      Color.fromARGB(255, 7, 12, 10); // texto/ícone sobre `accent`

  // Texto sobre fundos escuros
  static const textPrimary = Color(0xFFF6F8F7); // títulos, campos, botões
  static const textSecondary = Color(0xFFC7D0CB); // subtítulos e apoio
  // No Figma é #FFFFFF80 (RRGGBBAA); no Flutter o alfa vem primeiro.
  static const textTertiary = Color(0x80FFFFFF); // rodapés e legendas
}
