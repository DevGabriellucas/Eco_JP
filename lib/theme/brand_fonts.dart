import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fontes do Figma. Os arquivos estão embutidos em assets/fonts/ com o nome
/// que o google_fonts procura (`Familia-Peso.ttf`), então ele não baixa nada:
/// funciona offline e não expõe o IP de quem usa o app aos servidores do
/// Google, o que a política de privacidade não prevê.
///
/// Pesos embutidos: 400, 500 e 600. Outro peso ainda funciona, mas é baixado
/// da internet na primeira vez.
abstract final class BrandFonts {
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semiBold = FontWeight.w600;

  // Estilos nomeados. Valores medidos na imagem do Figma (frame 360x800),
  // não lidos do arquivo: ajuste aqui quando tiver os números exatos.
  // Variações (cor, tamanho) por copyWith na tela.

  /// Frase curta em caixa alta e espaçada, como "NATUREZA CONECTADA".
  static final tagline = mono(
    fontSize: 10,
    fontWeight: medium,
    letterSpacing: 2.4,
  );

  /// Título de tela (onboarding). Medido no frame 390x844.
  // letterSpacing 0 explícito: sem ele o Text herda o 0.25 do bodyMedium do
  // Material 3 e as linhas quebram em lugares diferentes do Figma.
  // 30 e 17: comparando a largura das linhas no mockup com um print do app
  // (Inter real), 28/16 ficavam ~7% menores que o Figma.
  static final heading = sans(
    fontSize: 30,
    fontWeight: semiBold,
    height: 1.3,
    letterSpacing: 0,
  );

  /// Texto corrido de apoio.
  static final body = sans(
    fontSize: 17,
    fontWeight: regular,
    height: 1.5,
    letterSpacing: 0,
  );

  /// Rótulo de botão e link.
  static final label = sans(
    fontSize: 16,
    fontWeight: semiBold,
    letterSpacing: 0,
  );

  /// Legenda pequena, como a localização no rodapé da splash.
  static final caption = mono(
    fontSize: 10,
    fontWeight: regular,
    letterSpacing: 1.0,
  );

  /// Inter: texto de interface (títulos, corpo, botões, campos).
  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// IBM Plex Mono: números, códigos e rótulos técnicos.
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Registra as licenças (SIL OFL 1.1, que exige acompanhar a fonte) na
  /// tela de licenças do app. Chamar uma vez no bootstrap.
  static void registrarLicencas() {
    LicenseRegistry.addLicense(() async* {
      for (final (familia, arquivo) in const [
        ('Inter', 'OFL-Inter.txt'),
        ('IBM Plex Mono', 'OFL-IBMPlexMono.txt'),
      ]) {
        final texto = await rootBundle.loadString('assets/fonts/$arquivo');
        yield LicenseEntryWithLineBreaks([familia], texto);
      }
    });
  }
}
