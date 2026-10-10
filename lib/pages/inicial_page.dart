import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/router/routes.dart';
import '../theme/app_icons.dart';
import '../theme/brand_colors.dart';
import '../theme/brand_fonts.dart';

/// Onboarding de primeiro uso (pré-login): topo com a ilustração da trilha e
/// um sheet branco com 3 slides deslizáveis e os CTAs de cadastro/login,
/// sempre visíveis. É pré-login, então não persiste "já visto": quem já tem
/// conta entra por "Já tenho uma conta".
///
/// Medidas tiradas do mockup do Figma (frame 390x844).
class InicialPage extends StatefulWidget {
  const InicialPage({super.key});

  @override
  State<InicialPage> createState() => _InicialPageState();
}

class _SlideIntro {
  const _SlideIntro({
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  final String icone;
  final String titulo;
  final String descricao;
}

const _slides = <_SlideIntro>[
  _SlideIntro(
    icone: AppIcons.camera,
    titulo: 'Registre problemas da sua cidade',
    descricao: 'Fotografe e denuncie lixo, buracos, queimadas e outros '
        'problemas ambientais direto do seu bairro.',
  ),
  _SlideIntro(
    icone: AppIcons.clock,
    titulo: 'Acompanhe cada denúncia',
    descricao: 'Veja o status oficial das ocorrências, curta e comente as da '
        'sua região — você fica por dentro do que muda.',
  ),
  _SlideIntro(
    icone: AppIcons.safeShield,
    titulo: 'Autoridades no mesmo app',
    descricao: 'Órgãos públicos verificam e atualizam as denúncias. '
        'Transparência de ponta a ponta, da queixa à solução.',
  ),
];

// Medidas do mockup.
const _margemLateral = 28.0;
const _raioSheet = 28.0;
const _ladoIcone = 50.0;
const _espacoIconeTitulo = 21.0;
const _espacoTituloDescricao = 14.0;

class _InicialPageState extends State<InicialPage> {
  final _controller = PageController();
  // Só o indicador escuta a página: deslizar não reconstrói o resto da tela.
  final _pagina = ValueNotifier<int>(0);

  @override
  void dispose() {
    _controller.dispose();
    _pagina.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: BrandColors.surfaceLight,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Scaffold(
          backgroundColor: BrandColors.brandDeep,
          body: LayoutBuilder(
            builder: (context, c) {
              // O topo nunca some: o sheet rola antes de cobrir o logo
              // (tela baixa, paisagem ou fonte grande).
              final reservaTopo = MediaQuery.paddingOf(context).top + 96;
              return Column(
                children: [
                  const Expanded(child: _Topo()),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          (c.maxHeight - reservaTopo).clamp(0.0, c.maxHeight),
                    ),
                    child: _Sheet(controller: _controller, pagina: _pagina),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Área verde: curvas de nível, trilha e logo. Decorativa.
class _Topo extends StatelessWidget {
  const _Topo();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final larguraLogo = (c.maxWidth * 0.38).clamp(120.0, 170.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Fundo em tela cheia alinhado pelo topo: o topo da tela é o topo
            // do frame do Figma, então a escala fica perto de 1x.
            const RepaintBoundary(
              child: SvgPicture(
                SvgAssetLoader(AppIllustrations.contourLines),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                excludeFromSemantics: true,
                placeholderBuilder: _vazio,
                errorBuilder: _vazioErro,
              ),
            ),
            // Trilha na largura da tela, com a proporção do próprio SVG,
            // apoiada no sheet. Se não couber, o Stack corta na borda de
            // cima da tela e a trilha "sai" da tela como no mockup. Antes ela
            // ficava numa caixa a partir de 23% do topo com cover, e em tela
            // baixa era cortada no meio do verde, terminando no ar.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: SvgPicture(
                  const SvgAssetLoader(AppIllustrations.initialPageBranch),
                  width: c.maxWidth,
                  fit: BoxFit.fitWidth,
                  excludeFromSemantics: true,
                  placeholderBuilder: _vazio,
                  errorBuilder: _vazioErro,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _margemLateral,
                    16,
                    _margemLateral,
                    0,
                  ),
                  child: SvgPicture.asset(
                    AppLogos.ecohub,
                    width: larguraLogo,
                    semanticsLabel: 'ecohub',
                    placeholderBuilder: _vazio,
                    errorBuilder: _vazioErro,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Enquanto o SVG carrega (ou se falhar), não desenha nada: o verde do
// Scaffold fica por trás, sem flash branco.
Widget _vazio(BuildContext context) => const SizedBox.shrink();
Widget _vazioErro(BuildContext context, Object erro, StackTrace stack) =>
    const SizedBox.shrink();

class _Sheet extends StatelessWidget {
  const _Sheet({required this.controller, required this.pagina});

  final PageController controller;
  final ValueNotifier<int> pagina;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BrandColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_raioSheet)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          // Sem padding embaixo: a área de toque do link (48 dp) e a SafeArea
          // já dão o respiro; com mais 8 o link ficava longe da borda.
          padding: const EdgeInsets.fromLTRB(
            _margemLateral,
            31,
            _margemLateral,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Slides(controller: controller, pagina: pagina),
              const SizedBox(height: 21),
              _Indicador(pagina: pagina, total: _slides.length),
              const SizedBox(height: 19),
              const _BotaoComecar(),
              const SizedBox(height: 8),
              const Center(child: _LinkJaTenhoConta()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slides extends StatelessWidget {
  const _Slides({required this.controller, required this.pagina});

  final PageController controller;
  final ValueNotifier<int> pagina;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        // O PageView precisa de altura fixa: usa a do slide mais alto, para
        // nenhum cortar texto e o sheet não mudar de tamanho ao deslizar.
        height: _alturaDoMaiorSlide(context, c.maxWidth),
        child: PageView.builder(
          controller: controller,
          itemCount: _slides.length,
          onPageChanged: (i) => pagina.value = i,
          itemBuilder: (_, i) => _Slide(slide: _slides[i]),
        ),
      ),
    );
  }

  static double _alturaDoMaiorSlide(BuildContext context, double largura) {
    final padrao = DefaultTextStyle.of(context).style;
    final escala = MediaQuery.textScalerOf(context);
    double altura(String texto, TextStyle estilo) {
      final painter = TextPainter(
        text: TextSpan(text: texto, style: padrao.merge(estilo)),
        textDirection: TextDirection.ltr,
        textScaler: escala,
      )..layout(maxWidth: largura);
      final h = painter.height;
      painter.dispose();
      return h;
    }

    var maior = 0.0;
    for (final s in _slides) {
      final h = _ladoIcone +
          _espacoIconeTitulo +
          altura(s.titulo, BrandFonts.heading) +
          _espacoTituloDescricao +
          altura(s.descricao, BrandFonts.body);
      if (h > maior) maior = h;
    }
    // Folga para arredondamento de subpixel.
    return maior.ceilToDouble() + 2;
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide});

  final _SlideIntro slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: _ladoIcone,
            height: _ladoIcone,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BrandColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            // Os SVGs vêm do Figma em cores diferentes; no mockup o ícone é
            // sempre o verde primário.
            child: SvgPicture.asset(
              slide.icone,
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                BrandColors.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: _espacoIconeTitulo),
        Text(
          slide.titulo,
          style: BrandFonts.heading.copyWith(color: BrandColors.textOnLight),
        ),
        const SizedBox(height: _espacoTituloDescricao),
        Text(
          slide.descricao,
          style: BrandFonts.body.copyWith(color: BrandColors.textOnLightMuted),
        ),
      ],
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.pagina, required this.total});

  final ValueNotifier<int> pagina;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: pagina,
      builder: (context, atual, _) => Semantics(
        label: 'Página ${atual + 1} de $total',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                width: i == atual ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == atual
                      ? BrandColors.primary
                      : BrandColors.neutralSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BotaoComecar extends StatelessWidget {
  const _BotaoComecar();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => context.push(Routes.cadastro),
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.primary,
        foregroundColor: BrandColors.onPrimary,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: BrandFonts.label,
      ),
      child: const Text('Começar'),
    );
  }
}

class _LinkJaTenhoConta extends StatelessWidget {
  const _LinkJaTenhoConta();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.push(Routes.login),
      style: TextButton.styleFrom(
        foregroundColor: BrandColors.primary,
        minimumSize: const Size(48, 48),
        textStyle: BrandFonts.label.copyWith(fontSize: 15),
      ),
      child: const Text('Já tenho uma conta'),
    );
  }
}
