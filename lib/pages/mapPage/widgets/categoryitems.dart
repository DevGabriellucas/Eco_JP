import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Legenda interativa das categorias. Usa as MESMAS cores e rótulos do feed
/// (OccurrenceType) e permite mostrar/ocultar cada tipo no mapa ao tocar.
///
/// Mostra apenas os chips que cabem na largura disponível; quando sobra
/// categoria, exibe um botão "..." ao final que abre a lista lateral completa
/// (endDrawer com [CategoryDrawer]).
class CategoryItems extends StatelessWidget {
  final MapController controller;

  const CategoryItems({super.key, required this.controller});

  // Constantes do layout do chip (mantidas em sincronia com _chip).
  static const double _hPadding = 10; // padding horizontal interno (cada lado)
  static const double _iconSize = 14;
  static const double _iconGap = 6;
  static const double _chipGap = 8; // espaço entre chips
  static const double _listPadding = 12; // padding horizontal da faixa
  static const double _moreButtonWidth = 44; // largura reservada para o "..."

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final disponivel = constraints.maxWidth - _listPadding * 2;

        final tipos = OccurrenceType.values;
        final larguras = [for (final t in tipos) _larguraChip(t, textScaler)];

        final totalTodos = larguras.fold<double>(
          0,
          (soma, w) => soma + w + _chipGap,
        );
        final cabemTodos = totalTodos <= disponivel;

        // Reserva espaço para o botão "..." apenas quando há overflow.
        final limite = cabemTodos ? disponivel : disponivel - _moreButtonWidth;

        final visiveis = <OccurrenceType>[];
        var acumulado = 0.0;
        for (var i = 0; i < tipos.length; i++) {
          final proxima = acumulado + larguras[i] + _chipGap;
          if (proxima > limite) break;
          visiveis.add(tipos[i]);
          acumulado = proxima;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _listPadding),
          child: Row(
            children: [
              for (final t in visiveis)
                Padding(
                  padding: const EdgeInsets.only(right: _chipGap),
                  child: Center(
                    child: _chip(t, controller.categoriaVisivel(t)),
                  ),
                ),
              if (!cabemTodos) Center(child: _botaoMais(context)),
            ],
          ),
        );
      },
    );
  }

  /// Largura estimada de um chip (conteúdo, sem o espaço entre chips).
  ///
  /// Inclui os 2px da borda (1px de cada lado) e arredonda a largura do texto
  /// para cima: subestimar fazia a fileira estourar ~18px na horizontal em
  /// paisagem (overflow), quando todos os chips eram renderizados.
  static const double _bordaChip = 2;

  double _larguraChip(OccurrenceType tipo, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: tipo.label, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return _hPadding * 2 +
        _iconSize +
        _iconGap +
        painter.width.ceilToDouble() +
        _bordaChip;
  }

  Widget _botaoMais(BuildContext context) {
    return GestureDetector(
      onTap: () => Scaffold.of(context).openEndDrawer(),
      child: Container(
        width: 36,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.more_horiz, size: 18, color: AppColors.muted),
      ),
    );
  }

  Widget _chip(OccurrenceType tipo, bool visivel) {
    final cor = tipo.color;
    return GestureDetector(
      onTap: () => controller.alternarCategoria(tipo),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visivel ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _hPadding,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: visivel
                ? cor.withValues(alpha: 0.12)
                : const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: visivel ? cor.withValues(alpha: 0.4) : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                visivel ? tipo.icon : Icons.visibility_off_outlined,
                size: _iconSize,
                color: visivel ? cor : AppColors.hint,
              ),
              const SizedBox(width: _iconGap),
              Text(
                tipo.label,
                style: _labelStyle.copyWith(
                  color: visivel ? cor : AppColors.hint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
