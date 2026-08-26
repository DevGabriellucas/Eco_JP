import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../theme/app_theme.dart';

class FilaVerificacaoPage extends ConsumerStatefulWidget {
  const FilaVerificacaoPage({super.key});

  @override
  ConsumerState<FilaVerificacaoPage> createState() =>
      _FilaVerificacaoPageState();
}

class _FilaVerificacaoPageState extends ConsumerState<FilaVerificacaoPage> {
  // Filtros: tipo de ocorrência (null = todos) e termo de busca livre
  // (título + localização). Aplicados sobre a lista do stream no cliente.
  OccurrenceType? _tipoFiltro;
  String _busca = '';
  final _buscaController = TextEditingController();

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _marcarVerificada(OcorrenciaModel ocorrencia) async {
    final service = ref.read(ocorrenciaRepositoryProvider);
    try {
      await service.definirVerificacao(
        ocorrencia.id,
        verificar: true,
        nomeAutoridade: 'Autoridade',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Denúncia marcada como verificada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // "Abrir" leva a denúncia ao feed (em vez da página de detalhe): define-a
  // como foco e fecha a fila, voltando à raiz (o HomeShell). O shell troca para
  // a aba do feed e o feed rola até ela com destaque.
  void _abrirNoFeed(OcorrenciaModel ocorrencia) {
    ref.read(feedFocoOcorrenciaProvider.notifier).state = ocorrencia;
    Navigator.of(context).popUntil((rota) => rota.isFirst);
  }

  // Aplica os filtros ativos (tipo + busca) sobre a lista já ordenada.
  List<OcorrenciaModel> _filtrar(List<OcorrenciaModel> lista) {
    final termo = _busca.trim().toLowerCase();
    return lista.where((o) {
      if (_tipoFiltro != null &&
          OccurrenceTypeParser.fromString(o.tipoLixo) != _tipoFiltro) {
        return false;
      }
      if (termo.isNotEmpty) {
        final alvo = '${o.titulo} ${o.localizacao}'.toLowerCase();
        if (!alvo.contains(termo)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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

          final filtrada = _filtrar(lista);

          return Column(
            children: [
              _ContadorBanner(total: lista.length, visiveis: filtrada.length),
              _BarraFiltro(
                controller: _buscaController,
                tipoSelecionado: _tipoFiltro,
                onBusca: (v) => setState(() => _busca = v),
                onTipo: (t) => setState(() => _tipoFiltro = t),
              ),
              Expanded(
                child: filtrada.isEmpty
                    ? const _SemResultado()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtrada.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ItemFila(
                          ocorrencia: filtrada[i],
                          onAbrir: () => _abrirNoFeed(filtrada[i]),
                          onVerificar: () => _marcarVerificada(filtrada[i]),
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
    // Quando há filtro ativo (visiveis < total), mostra "X de Y".
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
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              filtrando ? '$visiveis de $total' : '$total aguardando',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              filtrando
                  ? 'Resultados do filtro aplicado'
                  : 'Ordenadas da mais antiga para a mais recente',
              style: const TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  BARRA DE FILTRO (busca + botão de tipo em menu)
// ─────────────────────────────────────────

class _BarraFiltro extends StatelessWidget {
  final TextEditingController controller;
  final OccurrenceType? tipoSelecionado;
  final ValueChanged<String> onBusca;
  final ValueChanged<OccurrenceType?> onTipo;

  const _BarraFiltro({
    required this.controller,
    required this.tipoSelecionado,
    required this.onBusca,
    required this.onTipo,
  });

  // Abre um menu (bottom sheet) com a lista vertical de tipos. Mais limpo que
  // a régua horizontal de chips e não ocupa espaço fixo na tela.
  Future<void> _abrirMenuTipo(BuildContext context) async {
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
                    'Filtrar por tipo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: pal.ink,
                    ),
                  ),
                ],
              ),
            ),
            _OpcaoTipo(
              label: 'Todos os tipos',
              icon: Icons.filter_list,
              cor: pal.primary,
              selecionado: tipoSelecionado == null,
              onTap: () {
                onTipo(null);
                Navigator.pop(sheetContext);
              },
            ),
            ...OccurrenceType.values.map(
              (t) => _OpcaoTipo(
                label: t.label,
                icon: t.icon,
                cor: t.color,
                selecionado: tipoSelecionado == t,
                onTap: () {
                  onTipo(t);
                  Navigator.pop(sheetContext);
                },
              ),
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
    final temFiltro = tipoSelecionado != null;
    return Container(
      color: pal.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          // Campo de busca
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: controller,
                onChanged: onBusca,
                style: TextStyle(fontSize: 14, color: pal.ink),
                decoration: InputDecoration(
                  hintText: 'Buscar por título ou local',
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
          // Botão de filtro por tipo (abre menu). Fica destacado quando ativo.
          SizedBox(
            height: 42,
            width: 48,
            child: Material(
              color: temFiltro ? pal.primary : pal.background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _abrirMenuTipo(context),
                child: Tooltip(
                  message: 'Filtrar por tipo',
                  child: Icon(
                    temFiltro ? tipoSelecionado!.icon : Icons.tune,
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

/// Linha de opção no menu de tipos: ícone colorido + rótulo + check se ativo.
class _OpcaoTipo extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color cor;
  final bool selecionado;
  final VoidCallback onTap;

  const _OpcaoTipo({
    required this.label,
    required this.icon,
    required this.cor,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return ListTile(
      leading: Icon(icon, color: cor),
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

class _ItemFila extends StatelessWidget {
  final OcorrenciaModel ocorrencia;
  final VoidCallback onAbrir;
  final VoidCallback onVerificar;

  const _ItemFila({
    required this.ocorrencia,
    required this.onAbrir,
    required this.onVerificar,
  });

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
    final statusOficial = o.statusOficial;
    final idadeStr = _idade(o.dataCriacao);
    final dataStr = o.dataCriacao != null
        ? DateFormat('dd/MM/yyyy').format(o.dataCriacao!)
        : '';

    return Container(
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
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
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

            // ── Botões de Ação
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onVerificar,
                      child: const Text('Verificar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAbrir,
                      child: const Text('Abrir'),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
