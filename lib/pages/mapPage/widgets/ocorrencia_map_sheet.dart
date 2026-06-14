import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/theme/app_theme.dart';
import 'package:flutter/material.dart';

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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _OcorrenciaMapSheet(ocorrencia: ocorrencia),
  );
}

class _OcorrenciaMapSheet extends StatelessWidget {
  final OcorrenciaModel ocorrencia;

  const _OcorrenciaMapSheet({required this.ocorrencia});

  @override
  Widget build(BuildContext context) {
    final o = ocorrencia;
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
                  color: AppColors.border,
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
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  // BoxFit.contain (igual ao feed) para não cortar fotos
                  // verticais — BoxFit.cover preenchia a caixa cortando as
                  // bordas da imagem.
                  child: Image.network(
                    imagem,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              o.titulo.isEmpty ? 'Sem título' : o.titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    o.localizacao.isEmpty
                        ? 'Localização não informada'
                        : o.localizacao,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ver detalhes'),
              ),
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
