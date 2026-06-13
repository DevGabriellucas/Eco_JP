import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Ranking dos bairros com mais ocorrências registradas (top 3).
class MostAffectedZones extends StatelessWidget {
  final MapController controller;

  const MostAffectedZones(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final zonas = controller.zonasMaisAfetadas;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ZONAS MAIS AFETADAS',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Card(
              color: AppColors.surface,
              surfaceTintColor: AppColors.surface,
              elevation: 1.5,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: zonas.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma ocorrência localizada ainda.',
                          style: TextStyle(color: AppColors.hint, fontSize: 13),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < zonas.length; i++) ...[
                            if (i > 0) const SizedBox(height: 5),
                            _LinhaZona(
                              posicao: i + 1,
                              bairro: zonas[i].bairro,
                              quantidade: zonas[i].quantidade,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaZona extends StatelessWidget {
  final int posicao;
  final String bairro;
  final int quantidade;

  const _LinhaZona({
    required this.posicao,
    required this.bairro,
    required this.quantidade,
  });

  Color get _corPosicao => switch (posicao) {
    1 => AppColors.warning,
    2 => AppColors.muted,
    _ => AppColors.hint,
  };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _corPosicao.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$posicao',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _corPosicao,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.location_on, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              bairro,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$quantidade ${quantidade == 1 ? 'caso' : 'casos'}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
