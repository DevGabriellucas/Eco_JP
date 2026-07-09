import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../services/ocorrencia_service.dart';
import 'detalhe_ocorrencia_page.dart';

class FilaVerificacaoPage extends StatelessWidget {
  const FilaVerificacaoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = OcorrenciaService();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Fila de verificação',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DetalheOcorrenciaPage(occurrence: lista[i]),
                      ),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$total aguardando',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF97316),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ordenadas da mais antiga para a mais recente',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
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
          color: Colors.white,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
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
                      color: Color(0xFF8A8A8A),
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
    if (dt == null) return const Color(0xFF8A8A8A);
    final dias = DateTime.now().difference(dt).inDays;
    if (dias >= 7) return const Color(0xFFEF4444);
    if (dias >= 3) return const Color(0xFFF97316);
    return const Color(0xFF8A8A8A);
  }
}

// ─────────────────────────────────────────
//  FILA VAZIA
// ─────────────────────────────────────────

class _FilaVazia extends StatelessWidget {
  const _FilaVazia();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 72, color: Color(0xFF22C55E)),
          SizedBox(height: 16),
          Text(
            'Tudo verificado!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Não há denúncias pendentes de verificação.',
            style: TextStyle(fontSize: 14, color: Color(0xFF8A8A8A)),
          ),
        ],
      ),
    );
  }
}
