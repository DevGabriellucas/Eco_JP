import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router/routes.dart';
import '../widgets/auth_brand.dart';

class InicialPage extends StatelessWidget {
  const InicialPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double baseWidth = 430.0;
    final double paddingLateral = (38.0 / baseWidth) * screenWidth;

    return Scaffold(
      backgroundColor: AuthBrand.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackground(onboarding: true)),

          // 3. Conteúdo
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  const Expanded(
                    child: Center(
                      key: ValueKey('onboarding-logo-area'),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: EcoHubWordmark(trimPadding: true),
                        ),
                      ),
                    ),
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
                              foregroundColor: AuthBrand.background,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
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
                              fontFamily: 'Inter',
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
