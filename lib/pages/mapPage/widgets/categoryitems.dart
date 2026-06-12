import 'package:eco_jp/models/occurrence_types.dart';
import 'package:flutter/material.dart';

/// Legenda das categorias no mapa. Usa as MESMAS cores e rótulos do feed
/// (OccurrenceType), garantindo consistência visual em todo o app.
class CategoryItems extends StatelessWidget {
  const CategoryItems({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in OccurrenceType.values) _chip(t.label, t.color),
        ],
      ),
    );
  }

  Widget _chip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
