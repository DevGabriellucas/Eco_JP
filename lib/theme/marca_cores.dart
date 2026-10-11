import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'brand_colors.dart';

/// Cores (e assets que dependem do fundo) das telas de entrada de marca:
/// inicial, login, cadastro, confirmação de e-mail e consentimento.
/// Trocam com o tema claro/escuro do app. Acesse via `context.marca`.
///
/// Os nomes são de papel ("fundo", "destaque"), não de cor: a mesma tela
/// funciona nos dois temas lendo daqui. Os valores vêm de [BrandColors].
@immutable
class MarcaCores extends ThemeExtension<MarcaCores> {
  const MarcaCores({
    required this.fundo,
    required this.superficie,
    required this.texto,
    required this.textoApoio,
    required this.rotulo,
    required this.borda,
    required this.destaque,
    required this.sobreDestaque,
    required this.linkSecundario,
    required this.curvasLogin,
    required this.logo,
    required this.ilustracaoEmail,
    required this.brilho,
  });

  /// Fundo da tela (ou do sheet da inicial).
  final Color fundo;

  /// Caixa de ícone, caixa de aviso e círculos da linha do tempo.
  final Color superficie;

  /// Títulos e texto digitado.
  final Color texto;

  /// Subtítulos, descrições e ícones dos campos.
  final Color textoApoio;

  /// Rótulos em caixa alta dos campos (EMAIL, SENHA).
  final Color rotulo;

  /// Bordas, divisórias, indicador inativo e linha do tempo.
  final Color borda;

  /// Botão primário, foco, links, caixa marcada e ícones de destaque.
  final Color destaque;

  /// Texto/ícone sobre [destaque].
  final Color sobreDestaque;

  /// Links secundários ("Esqueceu a senha?") e o relógio do aviso.
  final Color linkSecundario;

  /// Tinta das curvas de nível do login; nula = cor original do SVG.
  final Color? curvasLogin;

  /// Logo da variante de fundo certa.
  final String logo;

  /// Ilustração da confirmação de e-mail da variante de fundo certa.
  final String ilustracaoEmail;

  /// Brilho do fundo: define os ícones da status bar e da barra de
  /// navegação (escuros no claro, claros no escuro).
  final Brightness brilho;

  static const light = MarcaCores(
    fundo: BrandColors.surfaceLight,
    superficie: BrandColors.primarySoft,
    texto: BrandColors.textOnLight,
    textoApoio: BrandColors.textOnLightMuted,
    rotulo: BrandColors.textOnLight,
    borda: BrandColors.neutralSoft,
    destaque: BrandColors.primary,
    sobreDestaque: BrandColors.onPrimary,
    linkSecundario: BrandColors.linkSecondary,
    curvasLogin: null,
    logo: AppLogos.ecohubOnLight,
    ilustracaoEmail: AppIllustrations.emailBranchLight,
    brilho: Brightness.light,
  );

  static const dark = MarcaCores(
    fundo: BrandColors.background,
    superficie: BrandColors.surfaceDarkRaised,
    texto: BrandColors.textPrimary,
    textoApoio: BrandColors.textSecondary,
    rotulo: BrandColors.textSecondary,
    borda: BrandColors.borderDark,
    destaque: BrandColors.accent,
    sobreDestaque: BrandColors.onAccent,
    linkSecundario: BrandColors.linkSecondaryDark,
    curvasLogin: BrandColors.contourOnDark,
    logo: AppLogos.ecohub,
    ilustracaoEmail: AppIllustrations.emailBranch,
    brilho: Brightness.dark,
  );

  bool get escuro => brilho == Brightness.dark;

  /// Status bar e barra de navegação coerentes com o fundo: ícones escuros
  /// no claro, claros no escuro. [statusSobreFundoEscuro] para telas cujo
  /// topo é escuro nos dois temas (a inicial, com o topo verde).
  SystemUiOverlayStyle barrasDoSistema({bool statusSobreFundoEscuro = false}) {
    final base = (escuro || statusSobreFundoEscuro)
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return base.copyWith(
      systemNavigationBarColor: fundo,
      systemNavigationBarIconBrightness:
          escuro ? Brightness.light : Brightness.dark,
    );
  }

  @override
  MarcaCores copyWith({
    Color? fundo,
    Color? superficie,
    Color? texto,
    Color? textoApoio,
    Color? rotulo,
    Color? borda,
    Color? destaque,
    Color? sobreDestaque,
    Color? linkSecundario,
    Color? curvasLogin,
    String? logo,
    String? ilustracaoEmail,
    Brightness? brilho,
  }) {
    return MarcaCores(
      fundo: fundo ?? this.fundo,
      superficie: superficie ?? this.superficie,
      texto: texto ?? this.texto,
      textoApoio: textoApoio ?? this.textoApoio,
      rotulo: rotulo ?? this.rotulo,
      borda: borda ?? this.borda,
      destaque: destaque ?? this.destaque,
      sobreDestaque: sobreDestaque ?? this.sobreDestaque,
      linkSecundario: linkSecundario ?? this.linkSecundario,
      curvasLogin: curvasLogin ?? this.curvasLogin,
      logo: logo ?? this.logo,
      ilustracaoEmail: ilustracaoEmail ?? this.ilustracaoEmail,
      brilho: brilho ?? this.brilho,
    );
  }

  /// Cores interpoladas na troca de tema; assets e brilho trocam na metade.
  @override
  MarcaCores lerp(ThemeExtension<MarcaCores>? other, double t) {
    if (other is! MarcaCores) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    final metade = t < 0.5 ? this : other;
    return MarcaCores(
      fundo: c(fundo, other.fundo),
      superficie: c(superficie, other.superficie),
      texto: c(texto, other.texto),
      textoApoio: c(textoApoio, other.textoApoio),
      rotulo: c(rotulo, other.rotulo),
      borda: c(borda, other.borda),
      destaque: c(destaque, other.destaque),
      sobreDestaque: c(sobreDestaque, other.sobreDestaque),
      linkSecundario: c(linkSecundario, other.linkSecundario),
      curvasLogin: Color.lerp(curvasLogin, other.curvasLogin, t),
      logo: metade.logo,
      ilustracaoEmail: metade.ilustracaoEmail,
      brilho: metade.brilho,
    );
  }
}

/// Atalho: `context.marca.fundo`, `context.marca.destaque`…
/// Sem a extensão no tema (testes com `ThemeData` cru), usa a clara.
extension MarcaCoresContext on BuildContext {
  MarcaCores get marca =>
      Theme.of(this).extension<MarcaCores>() ?? MarcaCores.light;
}
