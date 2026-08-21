import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/denuncia_moderacao_model.dart';
import '../services/moderacao_service.dart';
import '../theme/app_theme.dart';
import '../utils/mensagem_erro.dart';
import 'detalhe_ocorrencia_page.dart';

/// Fila de moderação (autoridade): denúncias de conteúdo abusivo pendentes.
/// Espelha o padrão de FilaVerificacaoPage, mas trata a coleção
/// `denuncias_moderacao` e oferece ações de moderação.
class FilaModeracaoPage extends StatefulWidget {
  const FilaModeracaoPage({super.key});

  @override
  State<FilaModeracaoPage> createState() => _FilaModeracaoPageState();
}

class _FilaModeracaoPageState extends State<FilaModeracaoPage> {
  // Filtros: alvo (null = todos, 'comentario' ou 'ocorrencia') e termo de
  // busca livre (motivo + detalhe). Aplicados no cliente sobre o stream.
  String? _alvoFiltro;
  String _busca = '';
  final _buscaController = TextEditingController();

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<DenunciaModeracaoModel> _filtrar(List<DenunciaModeracaoModel> lista) {
    final termo = _busca.trim().toLowerCase();
    return lista.where((d) {
      if (_alvoFiltro != null && d.alvoTipo != _alvoFiltro) return false;
      if (termo.isNotEmpty) {
        final alvo = '${d.motivo} ${d.detalhe ?? ''}'.toLowerCase();
        if (!alvo.contains(termo)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final service = ModeracaoService.instance;

    return Scaffold(
      backgroundColor: context.pal.background,
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

          final filtrada = _filtrar(lista);

          return Column(
            children: [
              _ContadorBanner(total: lista.length, visiveis: filtrada.length),
              _BarraFiltro(
                controller: _buscaController,
                alvoSelecionado: _alvoFiltro,
                onBusca: (v) => setState(() => _busca = v),
                onAlvo: (a) => setState(() => _alvoFiltro = a),
              ),
              Expanded(
                child: filtrada.isEmpty
                    ? const _SemResultado()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtrada.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ItemModeracao(
                          denuncia: filtrada[i],
                          service: service,
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
  final int visiveis;
  const _ContadorBanner({required this.total, required this.visiveis});

  @override
  Widget build(BuildContext context) {
    final filtrando = visiveis != total;
    return Container(
      width: double.infinity,
      color: context.pal.surface,
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
              filtrando
                  ? '$visiveis de $total'
                  : '$total pendente${total == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              filtrando
                  ? 'Resultados do filtro aplicado'
                  : 'Denúncias de conteúdo abusivo, mais antigas primeiro',
              style: const TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  BARRA DE FILTRO (busca + alvo)
// ─────────────────────────────────────────

class _BarraFiltro extends StatelessWidget {
  final TextEditingController controller;
  final String? alvoSelecionado;
  final ValueChanged<String> onBusca;
  final ValueChanged<String?> onAlvo;

  const _BarraFiltro({
    required this.controller,
    required this.alvoSelecionado,
    required this.onBusca,
    required this.onAlvo,
  });

  // Menu (bottom sheet) com os alvos: Todos / Comentários / Ocorrências.
  Future<void> _abrirMenuAlvo(BuildContext context) async {
    final pal = context.pal;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: pal.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'Filtrar por tipo de conteúdo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: pal.ink,
                    ),
                  ),
                ],
              ),
            ),
            _OpcaoAlvo(
              label: 'Todos',
              icon: Icons.filter_list,
              selecionado: alvoSelecionado == null,
              onTap: () {
                onAlvo(null);
                Navigator.pop(sheetContext);
              },
            ),
            _OpcaoAlvo(
              label: 'Comentários',
              icon: Icons.mode_comment_outlined,
              selecionado: alvoSelecionado == 'comentario',
              onTap: () {
                onAlvo('comentario');
                Navigator.pop(sheetContext);
              },
            ),
            _OpcaoAlvo(
              label: 'Ocorrências',
              icon: Icons.report_gmailerrorred_outlined,
              selecionado: alvoSelecionado == 'ocorrencia',
              onTap: () {
                onAlvo('ocorrencia');
                Navigator.pop(sheetContext);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final temFiltro = alvoSelecionado != null;
    return Container(
      color: pal.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: controller,
                onChanged: onBusca,
                style: TextStyle(fontSize: 14, color: pal.ink),
                decoration: InputDecoration(
                  hintText: 'Buscar por motivo',
                  hintStyle: TextStyle(fontSize: 14, color: pal.hint),
                  prefixIcon: Icon(Icons.search, size: 20, color: pal.hint),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, size: 18, color: pal.hint),
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            controller.clear();
                            onBusca('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: pal.background,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: pal.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: pal.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: pal.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 42,
            width: 48,
            child: Material(
              color: temFiltro ? AppColors.info : pal.background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _abrirMenuAlvo(context),
                child: Tooltip(
                  message: 'Filtrar por tipo de conteúdo',
                  child: Icon(
                    Icons.tune,
                    size: 20,
                    color: temFiltro ? Colors.white : pal.hint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de opção no menu de alvos da moderação.
class _OpcaoAlvo extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selecionado;
  final VoidCallback onTap;

  const _OpcaoAlvo({
    required this.label,
    required this.icon,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return ListTile(
      leading: Icon(icon, color: AppColors.info),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
          color: pal.ink,
        ),
      ),
      trailing: selecionado
          ? Icon(Icons.check, color: pal.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────
//  SEM RESULTADO (filtro sem correspondência)
// ─────────────────────────────────────────

class _SemResultado extends StatelessWidget {
  const _SemResultado();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: pal.hint),
          const SizedBox(height: 12),
          Text(
            'Nenhuma denúncia encontrada',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ajuste os filtros ou a busca.',
            style: TextStyle(fontSize: 13, color: pal.hint),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ITEM DA FILA
// ─────────────────────────────────────────

class _ItemModeracao extends ConsumerStatefulWidget {
  final DenunciaModeracaoModel denuncia;
  final ModeracaoService service;

  const _ItemModeracao({required this.denuncia, required this.service});

  @override
  ConsumerState<_ItemModeracao> createState() => _ItemModeracaoState();
}

class _ItemModeracaoState extends ConsumerState<_ItemModeracao> {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro(e, acao: 'concluir a ação'))),
      );
    }
  }

  Future<void> _abrirAlvo() async {
    final ocorrencia = await ref
        .read(ocorrenciaRepositoryProvider)
        .buscarPorId(widget.denuncia.ocorrenciaId);
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
    final pal = context.pal;
    final d = widget.denuncia;
    final alvoLabel = d.isComentario ? 'Comentário' : 'Ocorrência';
    final idadeStr = _idade(d.criadoEm);
    final dataStr = d.criadoEm != null
        ? DateFormat('dd/MM/yyyy').format(d.criadoEm!)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: pal.ink,
              ),
            ),
          ),

          // ── Detalhe (se houver)
          if (d.detalhe != null && d.detalhe!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text(
                d.detalhe!.trim(),
                style: TextStyle(fontSize: 12, color: pal.muted),
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
            padding: const EdgeInsets.all(12),
            child: _processando
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _executar(
                                () => widget.service.ocultarAlvo(d),
                                'Conteúdo ocultado.',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                              ),
                              child: const Text('Ocultar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _executar(
                                () => widget.service.resolver(
                                  d.id,
                                  decisao: 'rejeitada',
                                ),
                                'Denúncia marcada como improcedente.',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: pal.muted,
                              ),
                              child: const Text('Rejeitar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _executar(
                                () => widget.service.resolver(
                                  d.id,
                                  decisao: 'revisada',
                                ),
                                'Conteúdo mantido.',
                              ),
                              child: const Text('Manter'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _abrirAlvo,
                              child: const Text('Ver'),
                            ),
                          ),
                        ],
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
    final pal = context.pal;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 72,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          Text(
            'Nada a moderar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Não há denúncias de conteúdo pendentes.',
            style: TextStyle(fontSize: 14, color: pal.hint),
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
    final pal = context.pal;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 72, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Não foi possível carregar a fila de moderação.',
            style: TextStyle(fontSize: 14, color: pal.hint),
          ),
        ],
      ),
    );
  }
}
