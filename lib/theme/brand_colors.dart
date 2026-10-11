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

  // Superfícies claras (sheet branco do onboarding). Valores estimados na
  // imagem do Figma, não lidos do arquivo: confira e ajuste aqui.
  // `primary` é o verde do miolo dos pontos em initial_page_branch.svg.
  static const primary = Color(0xFF087F5B); // botão primário e links no claro
  static const onPrimary = Color(0xFFFFFFFF); // texto sobre `primary`
  static const surfaceLight = Color(0xFFFFFFFF); // sheet / cartão claro
  static const primarySoft = Color(0xFFE8F3EE); // fundo de ícone no claro
  static const textOnLight = Color(0xFF1A2420); // títulos no claro
  static const textOnLightMuted = Color(0xFF5F6B66); // texto de apoio no claro
  static const neutralSoft = Color(0xFFD3D9D6); // indicador inativo, divisórias
  // Valor do Figma (não estimado). Contraste ~5:1 sobre branco.
  static const linkSecondary = Color(0xFF287894); // links secundários no claro

  // Superfícies escuras (modo escuro das telas de entrada). Os três primeiros
  // foram estimados nos mockups escuros, não lidos do arquivo: confira e
  // ajuste aqui. `linkSecondaryDark` é a cor do clock.svg do Figma.
  static const surfaceDarkRaised = Color(0xFF22302A); // caixas e círculos
  static const borderDark = Color(0xFF34413B); // bordas e divisórias
  static const contourOnDark = Color(0xFF2C3833); // curvas do login no escuro
  static const linkSecondaryDark = Color(0xFF73B8D0); // links secundários
}
