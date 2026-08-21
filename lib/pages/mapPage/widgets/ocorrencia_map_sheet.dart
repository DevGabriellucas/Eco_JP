import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:eco_jp/utils/cloudinary_image.dart';
import 'package:eco_jp/utils/imagem_cacheada.dart';
import 'package:eco_jp/utils/distancia.dart';
import 'package:eco_jp/utils/navegacao_externa.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Mostra um resumo da ocorrência (foto, categoria, status, título e local)
/// ao tocar em um marcador do mapa. Retorna `true` se o usuário pediu para
/// abrir a tela de detalhes — a navegação fica a cargo de quem chamou, para
/// evitar empilhar rotas dentro do builder do bottom sheet.
Future<bool?> mostrarOcorrenciaSheet(
  BuildContext context,
  OcorrenciaModel ocorrencia,
) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.pal.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _OcorrenciaMapSheet(ocorrencia: ocorrencia),
  );
}

class _OcorrenciaMapSheet extends StatefulWidget {
  final OcorrenciaModel ocorrencia;

  const _OcorrenciaMapSheet({required this.ocorrencia});

  @override
  State<_OcorrenciaMapSheet> createState() => _OcorrenciaMapSheetState();
}

class _OcorrenciaMapSheetState extends State<_OcorrenciaMapSheet> {
  // Distância até a ocorrência, em metros. Null enquanto carrega ou quando
  // não há posição conhecida do usuário.
  double? _distanciaMetros;

  @override
  void initState() {
    super.initState();
    _calcularDistancia();
  }

  Future<void> _calcularDistancia() async {
    // getLastKnownPosition é instantâneo (cache) e não dispara novo prompt —
    // o usuário já está no mapa com permissão concedida. Se não houver cache,
    // simplesmente não mostramos a distância.
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null || !mounted) return;
      final o = widget.ocorrencia;
      final metros = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        o.latitude,
        o.longitude,
      );
      setState(() => _distanciaMetros = metros);
    } catch (_) {
      // Sem posição → sem distância; não é erro que precise de aviso.
    }
  }

  Future<void> _comoChegar(BuildContext context, OcorrenciaModel o) async {
    final ok = await abrirRotaNoMapa(
      latitude: o.latitude,
      longitude: o.longitude,
      rotulo: o.titulo,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o app de mapas.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final o = widget.ocorrencia;
    final tipo = OccurrenceTypeParser.fromString(o.tipoLixo);
    final status = OccurrenceStatusParser.fromString(o.status);
    final imagem = o.imagensUrls.isNotEmpty ? o.imagensUrls.first : o.imagemUrl;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: pal.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _CategoriaChip(tipo: tipo),
                const Spacer(),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 14),
            if (imagem != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: pal.surfaceAlt,
                  alignment: Alignment.center,
                  // Mantem a foto inteira no preview pequeno do mapa.
                  child: Image(
                    // Só largura no cloudinary: passar altura junto adiciona
                    // `g_auto`, que é inválido com o crop `limit` (padrão) e
                    // fazia o Cloudinary devolver erro — a foto sumia. O
                    // BoxFit.contain + altura fixa do container enquadram.
                    image: imagemCacheada(
                      cloudinaryOtimizada(
                        imagem,
                        larguraLogica: MediaQuery.sizeOf(context).width,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                      ),
                      cacheWidth: cacheLarguraPx(
                        MediaQuery.sizeOf(context).width,
                        MediaQuery.devicePixelRatioOf(context),
                      ),
                    ),
                    fit: BoxFit.contain,
                    semanticLabel: 'Foto da denúncia',
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              o.titulo.isEmpty ? 'Sem título' : o.titulo,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: pal.ink,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on, size: 15, color: pal.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    o.localizacao.isEmpty
                        ? 'Localização não informada'
                        : o.localizacao,
                    style: TextStyle(fontSize: 13, color: pal.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_distanciaMetros != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.near_me_outlined, size: 15, color: pal.primary),
                  const SizedBox(width: 4),
                  Text(
                    'A ${formatarDistancia(_distanciaMetros!)} de você',
                    style: TextStyle(
                      fontSize: 13,
                      color: pal.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _comoChegar(context, o),
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: const Text('Como chegar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ver detalhes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriaChip extends StatelessWidget {
  final OccurrenceType tipo;

  const _CategoriaChip({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final cor = tipo.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tipo.icon, size: 13, color: cor),
          const SizedBox(width: 4),
          Text(
            tipo.label,
            style: TextStyle(
              color: cor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OccurrenceStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
