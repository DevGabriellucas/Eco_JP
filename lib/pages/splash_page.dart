import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_icons.dart';
import '../theme/brand_colors.dart';
import '../theme/brand_fonts.dart';
import '../utils/precache_svg.dart';

/// Splash do app. Aparece duas vezes seguidas com o mesmo visual: primeiro
/// enquanto o Firebase inicializa (sem router) e depois na rota /splash,
/// enquanto o router resolve sessão, perfil e consentimento. Só a primeira
/// anima a entrada ([animarEntrada]); a segunda já nasce visível, então a
/// troca entre as duas não aparece.
///
/// O fundo é igual ao da splash nativa (ver `splash_background` em
/// android/app/src/main/res/values/colors.xml e o LaunchScreen.storyboard).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.animarEntrada = true});

  final bool animarEntrada;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const _tagline = 'NATUREZA CONECTADA';
  static const _localizacao = 'JOÃO PESSOA · 7°06\'54"S 34°51\'47"O';

  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: widget.animarEntrada ? 0 : 1,
  );
  bool _preparado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparado) return;
    _preparado = true;
    _precarregarProximasTelas();
    if (widget.animarEntrada) unawaited(_mostrarQuandoPronto());
  }

  /// Só mostra o conteúdo depois que os SVGs e as fontes desta tela estão
  /// carregados; antes o logo e os textos apareciam "pulando". Limite de 1 s
  /// para um asset lento não deixar a tela vazia.
  Future<void> _mostrarQuandoPronto() async {
    try {
      await Future.wait([
        precacheSvg(AppIllustrations.stylePattern),
        precacheSvg(AppLogos.ecohub),
        precacheSvg(AppIllustrations.splashBottom),
        GoogleFonts.pendingFonts([BrandFonts.tagline, BrandFonts.caption]),
      ]).timeout(const Duration(seconds: 1));
    } catch (_) {
      // Mostra assim mesmo: o pior caso é o asset aparecer um frame depois.
    }
    // Começa depois de um frame desenhado, para a animação não competir com o
    // primeiro frame (que substitui a splash nativa). endOfFrame, e não
    // addPostFrameCallback: numa tela parada nenhum frame novo seria pedido e
    // o conteúdo ficaria invisível.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _entrada.forward();
  }

  /// Telas que vêm logo depois (inicial, login): sem esperar, só para não
  /// carregarem as imagens na hora.
  void _precarregarProximasTelas() {
    unawaited(precacheImage(
      const AssetImage('assets/images/joaopessoa.jpg'),
      context,
    ));
    unawaited(precacheImage(
      const AssetImage('assets/images/logo_ecojp.png'),
      context,
    ));
    unawaited(precacheSvg(AppIcons.arrowLeft).catchError((_) {}));
    unawaited(precacheSvg(AppLogos.google).catchError((_) {}));
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: BrandColors.brandDeep,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: BrandColors.brandDeep,
        body: FadeTransition(
          opacity: _entrada,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: SvgPicture.asset(
                    AppIllustrations.stylePattern,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SafeArea(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: LayoutBuilder(builder: _conteudo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Proporções medidas na imagem do Figma (360x800): centro do logo a ~48%
  // da altura, régua a ~87% e localização a ~93%. Tudo relativo ao espaço
  // disponível, para valer em telas pequenas, tablets e paisagem.
  Widget _conteudo(BuildContext context, BoxConstraints c) {
    final larguraLogo = (c.maxWidth * 0.61).clamp(160.0, 280.0);
    final larguraRegua = (c.maxWidth * 0.33).clamp(100.0, 160.0);

    return Column(
      children: [
        const Spacer(flex: 59),
        SvgPicture.asset(
          AppLogos.ecohub,
          width: larguraLogo,
          semanticsLabel: 'ecohub',
        ),
        SizedBox(height: c.maxHeight * 0.025),
        _linha(
          _tagline,
          BrandFonts.tagline.copyWith(color: BrandColors.accent),
          c.maxWidth,
        ),
        const Spacer(flex: 41),
        SvgPicture.asset(
          AppIllustrations.splashBottom,
          width: larguraRegua,
          excludeFromSemantics: true,
        ),
        SizedBox(height: c.maxHeight * 0.045),
        _linha(
          _localizacao,
          BrandFonts.caption.copyWith(color: BrandColors.textTertiary),
          c.maxWidth,
        ),
        SizedBox(height: c.maxHeight * 0.06),
      ],
    );
  }

  /// Texto de uma linha que encolhe em vez de quebrar ou estourar (tela
  /// estreita ou fonte do sistema grande).
  Widget _linha(String texto, TextStyle estilo, double larguraMax) {
    return SizedBox(
      width: larguraMax * 0.9,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(texto, style: estilo, maxLines: 1),
      ),
    );
  }
}
