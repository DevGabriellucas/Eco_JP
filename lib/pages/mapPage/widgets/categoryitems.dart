import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Legenda interativa das categorias. Usa as MESMAS cores e rótulos do feed
/// (OccurrenceType) e permite mostrar/ocultar cada tipo no mapa ao tocar.
class CategoryItems extends StatelessWidget {
  final MapController controller;

  const CategoryItems({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final t in OccurrenceType.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: _chip(t, controller.categoriaVisivel(t))),
          ),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                size: 14,
                color: visivel ? cor : AppColors.hint,
              ),
              const SizedBox(width: 6),
              Text(
                tipo.label,
                style: TextStyle(
                  color: visivel ? cor : AppColors.hint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
