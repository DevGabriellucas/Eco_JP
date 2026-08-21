import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cores de marca / acento — iguais nos temas claro e escuro.
///
/// Os tokens neutros (ink/surface/background/border/hint/muted) continuam aqui
/// por compatibilidade, mas telas que precisam reagir ao tema devem usar
/// [AppPalette] via `context.pal`, que troca de valor entre claro e escuro.
abstract final class AppColors {
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6B7280);
  static const hint = Color(0xFF8A8A8A);
  static const background = Color(0xFFF4F6F3);
  static const surface = Colors.white;
  static const border = Color(0xFFD8DED6);
  static const primary = Color(0xFF1F7A4D);
  // Verde de marca aclarado para o tema escuro (o primary padrão fica escuro
  // demais sobre superfícies escuras). Exposto via `context.pal.primary`.
  static const primaryLight = Color(0xFF43C589);
  static const primaryDark = Color(0xFF145A38);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF97316);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF2563EB);
}

/// Tokens neutros que mudam entre claro e escuro. Acesse via `context.pal`.
///
/// As cores de acento (primary, success, warning, danger, info) ficam em
/// [AppColors] porque são iguais nos dois temas.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background; // fundo da página / scaffold
  final Color surface; // cartões, app bar, áreas "brancas"
  final Color surfaceAlt; // cartões secundários / slots / chips neutros
  final Color ink; // texto principal
  final Color muted; // texto secundário
  final Color hint; // dicas / placeholders
  final Color border; // divisórias e contornos
  final Color primary; // acento de marca (aclara no escuro)

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.muted,
    required this.hint,
    required this.border,
    required this.primary,
  });

  static const light = AppPalette(
    background: Color(0xFFF4F6F3),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDEDED),
    ink: Color(0xFF1A1A1A),
    muted: Color(0xFF6B7280),
    hint: Color(0xFF8A8A8A),
    border: Color(0xFFD8DED6),
    primary: AppColors.primary,
  );

  static const dark = AppPalette(
    background: Color(0xFF0E1311),
    surface: Color(0xFF171C19),
    surfaceAlt: Color(0xFF1F2521),
    ink: Color(0xFFECEFEC),
    muted: Color(0xFFA6AEA8),
    hint: Color(0xFF8B938C),
    border: Color(0xFF2B322D),
    primary: AppColors.primaryLight,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? muted,
    Color? hint,
    Color? border,
    Color? primary,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      hint: hint ?? this.hint,
      border: border ?? this.border,
      primary: primary ?? this.primary,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
    );
  }
}

/// Atalho ergonômico: `context.pal.surface`, `context.pal.ink`, etc.
extension AppPaletteContext on BuildContext {
  AppPalette get pal =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

abstract final class AppTheme {
  // Poppins nos títulos (personalidade) e Inter no corpo (legibilidade em
  // telas pequenas). Definido no tema central: qualquer `Text` que só ajusta
  // tamanho/peso herda essas famílias automaticamente.
  static final TextTheme _textThemeLight = _buildTextTheme(
    Typography.material2021().black,
    AppPalette.light.ink,
  );
  static final TextTheme _textThemeDark = _buildTextTheme(
    Typography.material2021().white,
    AppPalette.dark.ink,
  );

  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    final heading = GoogleFonts.poppinsTextTheme(base);
    final body = GoogleFonts.interTextTheme(base);
    return base
        .copyWith(
          displayLarge: heading.displayLarge,
          displayMedium: heading.displayMedium,
          displaySmall: heading.displaySmall,
          headlineLarge: heading.headlineLarge,
          headlineMedium: heading.headlineMedium,
          headlineSmall: heading.headlineSmall,
          titleLarge: heading.titleLarge,
          titleMedium: heading.titleMedium,
          titleSmall: heading.titleSmall,
          bodyLarge: body.bodyLarge,
          bodyMedium: body.bodyMedium,
          bodySmall: body.bodySmall,
          labelLarge: body.labelLarge,
          labelMedium: body.labelMedium,
          labelSmall: body.labelSmall,
        )
        .apply(bodyColor: color, displayColor: color);
  }

  static ThemeData light() => _build(
    brightness: Brightness.light,
    palette: AppPalette.light,
    textTheme: _textThemeLight,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.dark,
    textTheme: _textThemeDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
    required TextTheme textTheme,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: palette.primary,
      secondary: AppColors.warning,
      error: AppColors.danger,
      surface: palette.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      visualDensity: VisualDensity.standard,
      extensions: [palette],
      // Transições de tela mais suaves (o Zoom padrão do Android era abrupto).
      // FadeForwards é a transição moderna do Material 3 — aplicada de forma
      // consistente em todas as plataformas. Vale para navegações do go_router
      // e do Navigator direto.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          color: palette.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.inter(color: palette.hint, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      // Botão de alto contraste que inverte com o tema: fundo "ink" com texto
      // "surface". No claro fica preto/branco; no escuro, claro/escuro —
      // legível nos dois casos.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.ink,
          foregroundColor: palette.surface,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          side: BorderSide(color: palette.ink),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.ink,
        foregroundColor: palette.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: TextStyle(color: palette.surface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
    );
  }
}
