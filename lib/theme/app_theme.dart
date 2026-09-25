import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cores de marca / acento — iguais nos temas claro e escuro.
///
/// Os tokens neutros (ink/surface/background/border/hint/muted) continuam aqui
/// por compatibilidade, mas telas que precisam reagir ao tema devem usar
/// [AppPalette] via `context.pal`, que troca de valor entre claro e escuro.
abstract final class AppColors {
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF757575);
  static const hint = Color(0xFFA8A8A8);
  static const background = Color(0xFFFFFFFF);
  static const backgroundAlt = Color(0xFFF7F9F8);
  static const surface = Colors.white;
  static const border = Color(0xFFEEEEEE);
  static const primary = Color(0xFF099C5E);
  static const primarySoft = Color(0xFFE8F7EF);
  static const primaryDarkText = Color(0xFF066840);
  static const accent = Color(0xFFE58A3A);
  static const accentSoft = Color(0xFFFDF0E3);
  // Verde de marca aclarado para o tema escuro (o primary padrão fica escuro
  // demais sobre superfícies escuras). Exposto via `context.pal.primary`.
  static const primaryLight = Color(0xFF43C589);
  static const primaryDark = Color(0xFF066840);
  static const success = Color(0xFF099C5E);
  // Verde de marca mais fechado — usado em selos "verificado/resolvido" e em
  // ações de confirmação (enviar comentário, seguir). Igual nos dois temas.
  static const successStrong = Color(0xFF066840);
  static const warning = Color(0xFFE58A3A);
  static const danger = Color(0xFFC43D3D);
  static const info = Color(0xFF3478F6);
  static const iconMuted = Color(0xFF858585);
  static const statusPending = Color(0xFFF2B84B);
  static const statusResolved = Color(0xFF3CCB7F);
  static const statusUnresolved = Color(0xFFE05B5B);
  static const likeActive = Color(0xFFE0435B);
  static const likeInactive = Color(0xFF9AA0A6);
  static const imageOverlayEnd = Color(0xB3000000);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const screen = 16.0;
  static const section = 24.0;
  static const compact = 8.0;
  static const item = 12.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const cardLarge = 18.0;
  static const card = 16.0;
  static const cardSmall = 14.0;
  static const button = 12.0;
  static const badge = 8.0;
  static const chip = 20.0;
}

abstract final class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get fab => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

abstract final class AppTextStyles {
  static const screenTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );
  static const metadata = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );
  static const micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );
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
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF7F9F8),
    ink: Color(0xFF1A1A1A),
    muted: Color(0xFF757575),
    hint: Color(0xFFA8A8A8),
    border: Color(0xFFEEEEEE),
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
  static final TextTheme _textThemeLight = _buildTextTheme(
    Typography.material2021().black,
    AppPalette.light.ink,
  );
  static final TextTheme _textThemeDark = _buildTextTheme(
    Typography.material2021().white,
    AppPalette.dark.ink,
  );

  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    return GoogleFonts.interTextTheme(base).apply(
      bodyColor: color,
      displayColor: color,
    );
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
        titleTextStyle: GoogleFonts.inter(
          color: palette.ink,
          fontSize: 22,
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
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      // Botão de alto contraste que inverte com o tema: fundo "ink" com texto
      // "surface". No claro fica preto/branco; no escuro, claro/escuro —
      // legível nos dois casos.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: palette.surface,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.primary),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: palette.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentTextStyle: TextStyle(color: palette.surface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
    );
  }
}
