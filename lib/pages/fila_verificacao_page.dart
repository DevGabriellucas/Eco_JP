import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import 'detalhe_ocorrencia_page.dart';
import '../theme/app_theme.dart';

class FilaVerificacaoPage extends ConsumerWidget {
  const FilaVerificacaoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(ocorrenciaRepositoryProvider);
    final pal = context.pal;

    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        elevation: 0,
        title: const Text(
          'Fila de verificação',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: pal.border),
        ),
      ),
      body: StreamBuilder<List<OcorrenciaModel>>(
        stream: service.listarParaVerificacao(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lista = snap.data ?? [];

          if (lista.isEmpty) {
            return const _FilaVazia();
          }

          return Column(
            children: [
              _ContadorBanner(total: lista.length),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ItemFila(
                    ocorrencia: lista[i],
                    onAbrir: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DetalheOcorrenciaPage(occurrence: lista[i]),
                      ),
                    ),
                    onVerificar: () => _marcarVerificada(
                      context,
                      ref,
                      lista[i],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CONTADOR
// ─────────────────────────────────────────

class _ContadorBanner extends StatelessWidget {
  final int total;
  const _ContadorBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.pal.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$total aguardando',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ordenadas da mais antiga para a mais recente',
              style: TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ITEM DA FILA
// ─────────────────────────────────────────

class _ItemFila extends StatelessWidget {
  final OcorrenciaModel ocorrencia;
  final VoidCallback onTap;

  const _ItemFila({required this.ocorrencia, required this.onTap});

  String _idade(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d atrás';
    if (diff.inHours >= 1) return '${diff.inHours}h atrás';
    return '${diff.inMinutes}min atrás';
  }

  @override
  Widget build(BuildContext context) {
    final o = ocorrencia;
    final typeEnum = OccurrenceTypeParser.fromString(o.tipoLixo);
    final statusOficial = StatusOficialInfo.fromString(o.statusOficial);
    final idadeStr = _idade(o.dataCriacao);
    final dataStr = o.dataCriacao != null
        ? DateFormat('dd/MM/yyyy').format(o.dataCriacao!)
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  // Chip de tipo
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeEnum.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeEnum.icon, size: 12, color: typeEnum.color),
                        const SizedBox(width: 4),
                        Text(
                          typeEnum.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: typeEnum.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Status de triagem (se houver)
                  if (statusOficial != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusOficial.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusOficial.icon,
                              size: 12, color: statusOficial.color),
                          const SizedBox(width: 4),
                          Text(
                            statusOficial.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusOficial.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Idade da denúncia — destaca denúncias antigas em laranja
                  if (statusOficial == null) ...[
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: _idadeCor(o.dataCriacao),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      idadeStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _idadeCor(o.dataCriacao),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Título
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                o.titulo.isEmpty ? 'Sem título' : o.titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.pal.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Localização
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 12,
                    color: Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      o.localizacao,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dataStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.hint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _idadeCor(DateTime? dt) {
    if (dt == null) return AppColors.hint;
    final dias = DateTime.now().difference(dt).inDays;
    if (dias >= 7) return AppColors.danger;
    if (dias >= 3) return AppColors.warning;
    return AppColors.hint;
  }
}

// ─────────────────────────────────────────
//  FILA VAZIA
// ─────────────────────────────────────────

class _FilaVazia extends StatelessWidget {
  const _FilaVazia();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 72,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          Text(
            'Tudo verificado!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Não há denúncias pendentes de verificação.',
            style: TextStyle(fontSize: 14, color: pal.hint),
          ),
        ],
      ),
    );
  }
}
