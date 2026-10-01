import 'package:flutter/material.dart';

import '../data/repositories/ocorrencia_repository.dart';
import '../theme/app_theme.dart';

/// Aviso de que uma visão agregada (estatísticas, panorama, PDF) usa só as
/// [OcorrenciaRepository.tetoAgregado] denúncias mais recentes.
///
/// Antes, passando de 500 denúncias, "Tudo", taxas, tempos médios e o mapa
/// de calor ficavam errados sem nenhum aviso. Só aparece quando o teto foi
/// atingido; o total real vem de uma agregação `count()` (uma leitura).
class AvisoRecorte extends StatefulWidget {
  const AvisoRecorte({
    super.key,
    required this.carregadas,
    required this.repositorio,
  });

  final int carregadas;
  final OcorrenciaRepository repositorio;

  static bool atingiuTeto(int carregadas) =>
      carregadas >= OcorrenciaRepository.tetoAgregado;

  @override
  State<AvisoRecorte> createState() => _AvisoRecorteState();
}

class _AvisoRecorteState extends State<AvisoRecorte> {
  Future<int>? _total;

  @override
  Widget build(BuildContext context) {
    if (!AvisoRecorte.atingiuTeto(widget.carregadas)) {
      return const SizedBox.shrink();
    }
    _total ??= widget.repositorio.contarVisiveis();
    final pal = context.pal;
    return FutureBuilder<int>(
      future: _total,
      builder: (context, snap) {
        final total = snap.data;
        final texto = total == null
            ? 'Mostrando as ${OcorrenciaRepository.tetoAgregado} denúncias '
                'mais recentes.'
            : 'Mostrando as ${OcorrenciaRepository.tetoAgregado} denúncias '
                'mais recentes de $total no total.';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: pal.hint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(fontSize: 12, color: pal.hint),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
