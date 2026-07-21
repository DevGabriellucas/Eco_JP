import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router/routes.dart';
import '../theme/app_theme.dart';

/// Landing + onboarding de primeiro uso (pré-login). Antes era uma única tela
/// de marketing; agora um intro deslizável de 3 slides apresenta o que o app
/// faz para quem chega pela primeira vez, mantendo os CTAs de cadastro/login
/// sempre visíveis no rodapé. É pré-login, então não precisa persistir "já
/// visto" — quem já tem conta entra direto por "Já tenho uma conta".
class InicialPage extends StatefulWidget {
  const InicialPage({super.key});

  @override
  State<InicialPage> createState() => _InicialPageState();
}

class _SlideIntro {
  final IconData icone;
  final String titulo;
  final String descricao;
  const _SlideIntro({
    required this.icone,
    required this.titulo,
    required this.descricao,
  });
}

class _InicialPageState extends State<InicialPage> {
  final _controller = PageController();
  int _pagina = 0;

  static const _slides = <_SlideIntro>[
    _SlideIntro(
      icone: Icons.add_a_photo_outlined,
      titulo: 'Registre problemas da sua cidade',
      descricao:
          'Fotografe e denuncie lixo, buracos, queimadas e outros problemas '
          'ambientais direto do seu bairro.',
    ),
    _SlideIntro(
      icone: Icons.timeline_outlined,
      titulo: 'Acompanhe cada denúncia',
      descricao:
          'Veja o status oficial das ocorrências, curta e comente as da sua '
          'região — você fica por dentro do que muda.',
    ),
    _SlideIntro(
      icone: Icons.verified_outlined,
      titulo: 'Autoridades no mesmo app',
      descricao:
          'Órgãos públicos verificam e atualizam as denúncias. Transparência '
          'de ponta a ponta, da queixa à solução.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double baseWidth = 430.0;
    final double paddingLateral = (38.0 / baseWidth) * screenWidth;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1018),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          // 1. Imagem de Fundo (20% opacidade)
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/images/joaopessoa.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) =>
                    Container(color: const Color(0xFF0A1018)),
              ),
            ),
          ),

          // 2. Gradiente
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33FFFFFF), Color(0x4D000000)],
                  stops: [0.28, 0.80],
                ),
              ),
            ),
          ),

          // 3. Conteúdo
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: (screenWidth * 0.34).clamp(110.0, 150.0),
                    height: (screenWidth * 0.34).clamp(110.0, 150.0),
                    child: Image.asset(
                      'assets/images/logo_ecojp.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Slides deslizáveis
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      onPageChanged: (i) => setState(() => _pagina = i),
                      itemBuilder: (_, i) => _SlideView(
                        slide: _slides[i],
                        paddingLateral: paddingLateral,
                      ),
                    ),
                  ),

                  // Indicadores de página
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final ativo = i == _pagina;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: ativo ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ativo
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Parte inferior: botão + link fixos no rodapé
                  Padding(
                    padding: EdgeInsets.only(
                      left: paddingLateral,
                      right: paddingLateral,
                      top: 28,
                      bottom: 40,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => context.push(Routes.cadastro),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.ink,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const Text('Começar'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => context.push(Routes.login),
                          child: const Text(
                            'Já tenho uma conta',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _SlideIntro slide;
  final double paddingLateral;

  const _SlideView({required this.slide, required this.paddingLateral});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: paddingLateral),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icone, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 28),
          Text(
            slide.titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.descricao,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
