import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/denuncia_moderacao_model.dart';
import '../services/moderacao_service.dart';
import '../services/ocorrencia_service.dart';
import '../theme/app_theme.dart';
import 'detalhe_ocorrencia_page.dart';

/// Fila de moderação (autoridade): denúncias de conteúdo abusivo pendentes.
/// Espelha o padrão de FilaVerificacaoPage, mas trata a coleção
/// `denuncias_moderacao` e oferece ações de moderação.
class FilaModeracaoPage extends StatelessWidget {
  const FilaModeracaoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ModeracaoService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Fila de moderação',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: StreamBuilder<List<DenunciaModeracaoModel>>(
        stream: service.listarPendentes(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const _FilaErro();
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
                  itemBuilder: (_, i) =>
                      _ItemModeracao(denuncia: lista[i], service: service),
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
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$total pendente${total == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Denúncias de conteúdo abusivo, mais antigas primeiro',
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

class _ItemModeracao extends StatefulWidget {
  final DenunciaModeracaoModel denuncia;
  final ModeracaoService service;

  const _ItemModeracao({required this.denuncia, required this.service});

  @override
  State<_ItemModeracao> createState() => _ItemModeracaoState();
}

class _ItemModeracaoState extends State<_ItemModeracao> {
  final _ocorrenciaService = OcorrenciaService.instance;
  bool _processando = false;

  String _idade(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d atrás';
    if (diff.inHours >= 1) return '${diff.inHours}h atrás';
    return '${diff.inMinutes}min atrás';
  }

  Future<void> _executar(Future<void> Function() acao, String sucesso) async {
    setState(() => _processando = true);
    try {
      await acao();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(sucesso)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível concluir a ação.')),
      );
    }
  }

  Future<void> _abrirAlvo() async {
    final ocorrencia = await _ocorrenciaService.buscarPorId(
      widget.denuncia.ocorrenciaId,
    );
    if (!mounted) return;
    if (ocorrencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A ocorrência não existe mais.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalheOcorrenciaPage(occurrence: ocorrencia),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.denuncia;
    final alvoLabel = d.isComentario ? 'Comentário' : 'Ocorrência';
    final idadeStr = _idade(d.criadoEm);
    final dataStr = d.criadoEm != null
        ? DateFormat('dd/MM/yyyy').format(d.criadoEm!)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        d.isComentario
                            ? Icons.mode_comment_outlined
                            : Icons.report_gmailerrorred_outlined,
                        size: 12,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        alvoLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(Icons.schedule, size: 13, color: AppColors.hint),
                const SizedBox(width: 4),
                Text(
                  idadeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.hint,
                  ),
                ),
              ],
            ),
          ),

          // ── Motivo
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(
              d.motivo.isEmpty ? 'Sem motivo informado' : d.motivo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),

          // ── Detalhe (se houver)
          if (d.detalhe != null && d.detalhe!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text(
                d.detalhe!.trim(),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // ── Data
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text(
              dataStr,
              style: const TextStyle(fontSize: 11, color: AppColors.hint),
            ),
          ),

          const Divider(height: 20),

          // ── Ações
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: _processando
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: [
                      TextButton.icon(
                        onPressed: _abrirAlvo,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Ver'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _executar(
                          () => widget.service.resolver(
                            d.id,
                            decisao: 'rejeitada',
                          ),
                          'Denúncia marcada como improcedente.',
                        ),
                        child: const Text(
                          'Rejeitar',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _executar(
                          () => widget.service.resolver(
                            d.id,
                            decisao: 'revisada',
                          ),
                          'Conteúdo mantido.',
                        ),
                        child: const Text('Manter'),
                      ),
                      TextButton(
                        onPressed: () => _executar(
                          () => widget.service.ocultarAlvo(d),
                          'Conteúdo ocultado.',
                        ),
                        child: const Text(
                          'Ocultar',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ESTADOS VAZIO / ERRO
// ─────────────────────────────────────────

class _FilaVazia extends StatelessWidget {
  const _FilaVazia();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined, size: 72, color: AppColors.success),
          SizedBox(height: 16),
          Text(
            'Nada a moderar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Não há denúncias de conteúdo pendentes.',
            style: TextStyle(fontSize: 14, color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}

class _FilaErro extends StatelessWidget {
  const _FilaErro();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 72, color: AppColors.danger),
          SizedBox(height: 16),
          Text(
            'Erro ao carregar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Não foi possível carregar a fila de moderação.',
            style: TextStyle(fontSize: 14, color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}
