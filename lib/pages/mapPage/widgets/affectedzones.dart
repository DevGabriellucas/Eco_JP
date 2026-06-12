import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:flutter/material.dart';

class MostAffectedZones extends StatelessWidget {
  final MapController controller;

  const MostAffectedZones(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final zonaMaisAfetada = controller.zonaMaisAfetada;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text(
            'ZONA MAIS AFETADA',
            style: Theme.of(context).textTheme.labelSmall,
          ),

          const SizedBox(height: 6),

          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on),

                    const SizedBox(width: 8),

                    Text(zonaMaisAfetada.bairro),

                    const Spacer(),

                    Text('${zonaMaisAfetada.quantidade} casos'),

                    const SizedBox(width: 8),

                    const Icon(Icons.bar_chart),
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
