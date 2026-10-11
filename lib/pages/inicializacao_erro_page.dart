import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';
import '../theme/brand_fonts.dart';

/// Mostrada quando a inicialização (Firebase etc.) falha ou passa do tempo.
/// Antes o app pedia para fechar e abrir de novo; agora dá para tentar daqui.
class InicializacaoErroPage extends StatelessWidget {
  const InicializacaoErroPage({super.key, required this.onTentarNovamente});

  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.brandDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Não foi possível iniciar o app',
                  textAlign: TextAlign.center,
                  style: BrandFonts.sans(
                    fontSize: 18,
                    fontWeight: BrandFonts.semiBold,
                    color: BrandColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Confira sua conexão com a internet e tente de novo.',
                  textAlign: TextAlign.center,
                  style: BrandFonts.sans(
                    fontSize: 14,
                    height: 1.4,
                    color: BrandColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: onTentarNovamente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.accent,
                    foregroundColor: BrandColors.onAccent,
                    minimumSize: const Size(200, 48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: BrandFonts.sans(fontWeight: BrandFonts.semiBold),
                  ),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
