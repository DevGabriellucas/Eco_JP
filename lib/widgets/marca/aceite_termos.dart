import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';
import '../../theme/brand_fonts.dart';

/// "Li e aceito a Política de Privacidade e os Termos de Uso", com caixa de
/// marcação. A linha inteira marca a caixa (a caixa sozinha tem 24 dp, abaixo
/// do mínimo de 48); os links abrem os documentos. Com [onChanged] nulo fica
/// desabilitado (ex.: enquanto o cadastro está em andamento).
class AceiteTermos extends StatefulWidget {
  const AceiteTermos({
    super.key,
    required this.valor,
    required this.onChanged,
    required this.onAbrirPolitica,
    required this.onAbrirTermos,
  });

  final bool valor;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onAbrirPolitica;
  final VoidCallback onAbrirTermos;

  @override
  State<AceiteTermos> createState() => _AceiteTermosState();
}

class _AceiteTermosState extends State<AceiteTermos> {
  // Reconhecedores dos links: criados uma vez e descartados no dispose (um
  // TapGestureRecognizer novo a cada build vazaria).
  late final _politica = TapGestureRecognizer()
    ..onTap = () => widget.onAbrirPolitica();
  late final _termos = TapGestureRecognizer()
    ..onTap = () => widget.onAbrirTermos();

  @override
  void dispose() {
    _politica.dispose();
    _termos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    final link = BrandFonts.label.copyWith(
      fontSize: 15,
      color: BrandColors.primary,
    );

    return InkWell(
      onTap: onChanged == null ? null : () => onChanged(!widget.valor),
      // O toque na linha é só atalho visual; para o leitor de tela quem
      // marca é o Checkbox (com rótulo). Antes a linha virava um "botão"
      // sem nome, anunciado junto com a caixa.
      excludeFromSemantics: true,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: widget.valor,
                semanticLabel:
                    'Aceito a Política de Privacidade e os Termos de Uso',
                onChanged:
                    onChanged == null ? null : (v) => onChanged(v ?? false),
                activeColor: BrandColors.primary,
                checkColor: BrandColors.onPrimary,
                side: const BorderSide(
                  color: BrandColors.textOnLightMuted,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: BrandFonts.body.copyWith(
                    fontSize: 15,
                    color: BrandColors.textOnLightMuted,
                  ),
                  children: [
                    const TextSpan(text: 'Li e aceito a '),
                    TextSpan(
                      text: 'Política de Privacidade',
                      style: link,
                      recognizer: _politica,
                    ),
                    const TextSpan(text: ' e os '),
                    TextSpan(
                      text: 'Termos de Uso',
                      style: link,
                      recognizer: _termos,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
