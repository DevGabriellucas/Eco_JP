import 'package:flutter/material.dart';

class InicialPage extends StatelessWidget {
  const InicialPage({super.key});

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
                  // Parte superior expandida: logo + textos centralizados juntos
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: paddingLateral),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -15),
                            child: SizedBox(
                              width: (screenWidth * 0.52).clamp(170.0, 240.0),
                              height: (screenWidth * 0.52).clamp(170.0, 240.0),
                              child: Image.asset(
                                'assets/images/logo_ecojp.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            'Sua cidade, sua voz,\nsua responsabilidade.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'Cada denúncia faz diferença. Juntos, podemos transformar pequenos alertas em grandes mudanças para a cidade.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Parte inferior: botão + link fixos no rodapé
                  Padding(
                    padding: EdgeInsets.only(
                      left: paddingLateral,
                      right: paddingLateral,
                      bottom: 48,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/cadastro');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1A1A1A),
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
                          onTap: () {
                            Navigator.of(context).pushNamed('/login');
                          },
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
