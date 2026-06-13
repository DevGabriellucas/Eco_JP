import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Painel lateral (desliza da direita) com TODAS as categorias de ocorrência.
/// Reaproveita as mesmas cores/ícones/rótulos do feed (OccurrenceType) e os
/// métodos do controller para mostrar/ocultar cada tipo no mapa.
class CategoryDrawer extends StatelessWidget {
  final MapController controller;

  const CategoryDrawer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'Categorias',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Toque para mostrar ou ocultar no mapa.',
                    style: TextStyle(color: AppColors.hint, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final tipo in OccurrenceType.values)
                        _CategoryTile(
                          tipo: tipo,
                          visivel: controller.categoriaVisivel(tipo),
                          onTap: () => controller.alternarCategoria(tipo),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final OccurrenceType tipo;
  final bool visivel;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.tipo,
    required this.visivel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = tipo.color;
    return ListTile(
      onTap: onTap,
      leading: Icon(tipo.icon, color: visivel ? cor : AppColors.hint),
      title: Text(
        tipo.label,
        style: TextStyle(
          color: visivel ? AppColors.ink : AppColors.hint,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        visivel ? Icons.visibility : Icons.visibility_off_outlined,
        size: 20,
        color: visivel ? cor : AppColors.hint,
      ),
    );
  }
}
