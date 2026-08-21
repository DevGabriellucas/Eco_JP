import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/ocorrencia_repository.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/ocorrencia_model.dart';
import '../services/relatorio_service.dart';
import '../models/occurrence_types.dart';
import 'dados_publicos_page.dart';
import 'mapPage/controller/calc_mostaffectedzones.dart';
import '../theme/app_theme.dart';

enum _Periodo { semana, mes, ano, tudo }

extension _PeriodoInfo on _Periodo {
  String get label => switch (this) {
    _Periodo.semana => 'Semana',
    _Periodo.mes => 'Mês',
    _Periodo.ano => 'Ano',
    _Periodo.tudo => 'Tudo',
  };

  String get descricao => switch (this) {
    _Periodo.semana => 'últimos 7 dias',
    _Periodo.mes => 'últimos 30 dias',
    _Periodo.ano => 'últimos 12 meses',
    _Periodo.tudo => 'todo o período',
  };

  Duration? get janela => switch (this) {
    _Periodo.semana => const Duration(days: 7),
    _Periodo.mes => const Duration(days: 30),
    _Periodo.ano => const Duration(days: 365),
    _Periodo.tudo => null,
  };
}

// ─────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────

const _resolvedColor = AppColors.success;
const _pendingColor = Color(0xFF9CA3AF);
const _unresolvedColor = AppColors.danger;
const _chartPurple = Color(0xFF8B7CF6);
const _axisLabelColor = Color(0xFF9CA3AF);

// ─────────────────────────────────────────
//  ESTATÍSTICAS PAGE
// ─────────────────────────────────────────

class EstatisticasPage extends ConsumerStatefulWidget {
  const EstatisticasPage({super.key});

  @override
  ConsumerState<EstatisticasPage> createState() => _EstatisticasPageState();
}

class _EstatisticasPageState extends ConsumerState<EstatisticasPage> {
  OcorrenciaRepository get _ocorrenciaRepository =>
      ref.read(ocorrenciaRepositoryProvider);
  final _relatorioService = RelatorioService();

  _Periodo _periodo = _Periodo.tudo;
  bool _exportando = false;

  // Mantém só as ocorrências dentro da janela de tempo selecionada.
  List<OcorrenciaModel> _filtrarPorPeriodo(List<OcorrenciaModel> lista) {
    final janela = _periodo.janela;
    if (janela == null) return lista;
    final limite = DateTime.now().subtract(janela);
    return lista
        .where((o) => o.dataCriacao != null && o.dataCriacao!.isAfter(limite))
        .toList();
  }

  Future<void> _exportarRelatorio(List<OcorrenciaModel> ocorrencias) async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      await _relatorioService.gerarECompartilhar(
        ocorrencias: ocorrencias,
        periodoLabel: _periodo.descricao,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar o relatório.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  static const _weekDayLabels = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sab',
    'Dom',
  ];

  Map<OccurrenceStatus, int> _statusCounts(List<OcorrenciaModel> ocorrencias) {
    final counts = <OccurrenceStatus, int>{};
    for (final o in ocorrencias) {
      final status = OccurrenceStatusParser.fromString(o.status);
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  List<int> _weeklyCounts(List<OcorrenciaModel> ocorrencias) {
    final counts = List<int>.filled(7, 0);
    for (final o in ocorrencias) {
      final data = o.dataCriacao;
      if (data == null) continue;
      counts[data.weekday - 1]++;
    }
    return counts;
  }

  List<MapEntry<OccurrenceType, int>> _categoryCounts(
    List<OcorrenciaModel> ocorrencias,
  ) {
    final counts = <OccurrenceType, int>{};
    for (final o in ocorrencias) {
      final type = OccurrenceTypeParser.fromString(o.tipoLixo);
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final entries = counts.entries.where((e) => e.value > 0).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Consolida o funil de triagem oficial e os tempos médios de resposta.
  _MetricasTriagem _metricasTriagem(List<OcorrenciaModel> ocorrencias) {
    int pendentes = 0,
        emAnalise = 0,
        confirmadas = 0,
        encaminhadas = 0,
        resolvidas = 0,
        naoConfirmadas = 0;
    final tempoConfirmacao = <Duration>[];
    final tempoResolucao = <Duration>[];

    for (final o in ocorrencias) {
      if (o.verificada) {
        if (o.statusOficial == 'resolvida') {
          resolvidas++;
        } else if (o.statusOficial == 'encaminhada') {
          encaminhadas++;
        } else {
          confirmadas++;
        }
        if (o.verificadaEm != null && o.dataCriacao != null) {
          final d = o.verificadaEm!.difference(o.dataCriacao!);
          if (!d.isNegative) tempoConfirmacao.add(d);
        }
        if (o.resolvidaEm != null && o.dataCriacao != null) {
          final d = o.resolvidaEm!.difference(o.dataCriacao!);
          if (!d.isNegative) tempoResolucao.add(d);
        }
      } else if (o.statusOficial == 'em_analise') {
        emAnalise++;
      } else if (o.statusOficial == 'nao_confirmada') {
        naoConfirmadas++;
      } else {
        pendentes++;
      }
    }

    Duration? media(List<Duration> ds) {
      if (ds.isEmpty) return null;
      final totalMs = ds.fold<int>(0, (a, b) => a + b.inMilliseconds);
      return Duration(milliseconds: totalMs ~/ ds.length);
    }

    return _MetricasTriagem(
      total: ocorrencias.length,
      pendentes: pendentes,
      emAnalise: emAnalise,
      confirmadas: confirmadas,
      encaminhadas: encaminhadas,
      resolvidas: resolvidas,
      naoConfirmadas: naoConfirmadas,
      tempoMedioConfirmacao: media(tempoConfirmacao),
      tempoMedioResolucao: media(tempoResolucao),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    // Cidadão vê "Dados" (guia + panorama); autoridade vê "Estatísticas".
    final ehAutoridade = ref.watch(isAutoridadeProvider).value == true;
    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        backgroundColor: pal.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Text(
              'EcoJP',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: pal.ink,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              ehAutoridade ? 'Estatísticas' : 'Dados',
              style: TextStyle(fontSize: 15, color: pal.hint),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: pal.border),
        ),
      ),
      body: _construirCorpo(),
    );
  }

  Widget _construirCorpo() {
    // Autoridade vê a ferramenta de triagem; o cidadão vê o painel público
    // (panorama da cidade + guia de coleta + dicas de reciclagem).
    final isAutoridade = ref.watch(isAutoridadeProvider);
    if (isAutoridade.isLoading || !isAutoridade.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (isAutoridade.value == false) {
      return const DadosPublicosView();
    }

    return StreamBuilder<List<OcorrenciaModel>>(
      stream: _ocorrenciaRepository.listarOcorrenciasLimitadas(
        OcorrenciaRepository.tetoAgregado,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }

        final ocorrencias = snapshot.data ?? [];

        if (ocorrencias.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: const [
              SizedBox(height: 16),
              Center(
                child: Text(
                  'Ainda não há dados suficientes\npara gerar estatísticas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          );
        }

        final filtradas = _filtrarPorPeriodo(ocorrencias);
        final statusCounts = _statusCounts(filtradas);
        final weeklyCounts = _weeklyCounts(filtradas);
        final categoryCounts = _categoryCounts(filtradas);
        final bairros = CalcMostAffectedZones(
          filtradas,
        ).zonasMaisAfetadas(limite: 5);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _PeriodoSelector(
              periodo: _periodo,
              onSelecionar: (p) => setState(() => _periodo = p),
            ),
            const SizedBox(height: 12),
            _BotaoExportar(
              exportando: _exportando,
              onTap: filtradas.isEmpty
                  ? null
                  : () => _exportarRelatorio(filtradas),
            ),
            const SizedBox(height: 16),
            if (filtradas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Nenhuma denúncia neste período.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              _DashboardAutoridade(metricas: _metricasTriagem(filtradas)),
              const SizedBox(height: 16),
              _StatusPieCard(
                resolved: statusCounts[OccurrenceStatus.resolved] ?? 0,
                inProgress: statusCounts[OccurrenceStatus.inProgress] ?? 0,
                unresolved: statusCounts[OccurrenceStatus.unresolved] ?? 0,
              ),
              const SizedBox(height: 16),
              _WeeklyLineCard(data: weeklyCounts, labels: _weekDayLabels),
              const SizedBox(height: 16),
              _CategoryBarCard(data: categoryCounts),
              const SizedBox(height: 16),
              _RankingBairrosCard(bairros: bairros),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  CARD BASE
// ─────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.pal.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────
//  SELETOR DE PERÍODO + EXPORTAR
// ─────────────────────────────────────────

class _PeriodoSelector extends StatelessWidget {
  final _Periodo periodo;
  final ValueChanged<_Periodo> onSelecionar;

  const _PeriodoSelector({required this.periodo, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Row(
      children: [
        for (final p in _Periodo.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelecionar(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: periodo == p ? pal.ink : pal.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: periodo == p ? pal.ink : pal.border,
                  ),
                ),
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: periodo == p ? pal.surface : pal.muted,
                  ),
                ),
              ),
            ),
          ),
          if (p != _Periodo.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _BotaoExportar extends StatelessWidget {
  final bool exportando;
  final VoidCallback? onTap;

  const _BotaoExportar({required this.exportando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: exportando ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF16A34A),
          side: const BorderSide(color: Color(0xFF16A34A)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: exportando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: Text(
          exportando ? 'Gerando relatório...' : 'Exportar relatório (PDF)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  RANKING DE BAIRROS
// ─────────────────────────────────────────

class _RankingBairrosCard extends StatelessWidget {
  final List<({String bairro, int quantidade})> bairros;

  const _RankingBairrosCard({required this.bairros});

  @override
  Widget build(BuildContext context) {
    if (bairros.isEmpty) {
      return const _Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sem dados de bairro disponíveis.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final maxQtd = bairros.first.quantidade;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bairros mais afetados',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.pal.ink,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < bairros.length; i++) ...[
            _LinhaBairro(
              posicao: i + 1,
              bairro: bairros[i].bairro,
              quantidade: bairros[i].quantidade,
              ratio: maxQtd == 0 ? 0 : bairros[i].quantidade / maxQtd,
            ),
            if (i != bairros.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LinhaBairro extends StatelessWidget {
  final int posicao;
  final String bairro;
  final int quantidade;
  final double ratio;

  const _LinhaBairro({
    required this.posicao,
    required this.bairro,
    required this.quantidade,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF8B7CF6).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$posicao',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8B7CF6),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bairro,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.pal.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: context.pal.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF8B7CF6)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$quantidade',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8B7CF6),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  DASHBOARD DA AUTORIDADE (item 2)
//  Funil de triagem + tempos de resposta.
//  Visível apenas para contas com papel 'autoridade'.
// ─────────────────────────────────────────

class _MetricasTriagem {
  final int total;
  final int pendentes;
  final int emAnalise;
  final int confirmadas;
  final int encaminhadas;
  final int resolvidas;
  final int naoConfirmadas;
  final Duration? tempoMedioConfirmacao;
  final Duration? tempoMedioResolucao;

  const _MetricasTriagem({
    required this.total,
    required this.pendentes,
    required this.emAnalise,
    required this.confirmadas,
    required this.encaminhadas,
    required this.resolvidas,
    required this.naoConfirmadas,
    required this.tempoMedioConfirmacao,
    required this.tempoMedioResolucao,
  });

  // Total de denúncias reconhecidas como reais (confirmadas em qualquer estágio).
  int get verificadasTotal => confirmadas + encaminhadas + resolvidas;

  // Quantas já passaram por triagem (saíram de "pendente").
  int get triadas => total - pendentes;
}

class _DashboardAutoridade extends StatelessWidget {
  final _MetricasTriagem metricas;

  const _DashboardAutoridade({required this.metricas});

  String _fmtDuracao(Duration? d) {
    if (d == null) return '—';
    if (d.inDays >= 1) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    if (d.inMinutes >= 1) return '${d.inMinutes}min';
    return '<1min';
  }

  String _pct(int parte, int total) {
    if (total == 0) return '0%';
    return '${(parte / total * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final m = metricas;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: pal.ink),
              const SizedBox(width: 8),
              Text(
                'Painel da autoridade',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: pal.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Funil de triagem das denúncias',
            style: TextStyle(fontSize: 12, color: context.pal.muted),
          ),
          const SizedBox(height: 16),

          // ── Funil: 6 estados do ciclo oficial
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Pendentes',
                  value: m.pendentes,
                  color: const Color(0xFF9CA3AF),
                  icon: Icons.schedule,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Em análise',
                  value: m.emAnalise,
                  color: _pendingColor,
                  icon: Icons.search,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Confirmadas',
                  value: m.confirmadas,
                  color: _resolvedColor,
                  icon: Icons.verified_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Encaminhadas',
                  value: m.encaminhadas,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.send,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Resolvidas',
                  value: m.resolvidas,
                  color: _resolvedColor,
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Não confirm.',
                  value: m.naoConfirmadas,
                  color: _unresolvedColor,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: pal.border),
          const SizedBox(height: 16),

          // ── Tempos médios e taxas
          Row(
            children: [
              Expanded(
                child: _IndicadorLinha(
                  label: 'Tempo médio até confirmar',
                  valor: _fmtDuracao(m.tempoMedioConfirmacao),
                ),
              ),
              Expanded(
                child: _IndicadorLinha(
                  label: 'Tempo médio até resolver',
                  valor: _fmtDuracao(m.tempoMedioResolucao),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _IndicadorLinha(
                  label: 'Taxa de confirmação',
                  valor: _pct(m.verificadasTotal, m.triadas),
                ),
              ),
              Expanded(
                child: _IndicadorLinha(
                  label: 'Taxa de resolução',
                  valor: _pct(m.resolvidas, m.verificadasTotal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: context.pal.muted),
          ),
        ],
      ),
    );
  }
}

class _IndicadorLinha extends StatelessWidget {
  final String label;
  final String valor;

  const _IndicadorLinha({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.pal.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: context.pal.muted)),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  PIE CHART CARD (status: resolvido x pendente)
// ─────────────────────────────────────────

class _StatusPieCard extends StatelessWidget {
  final int resolved;
  final int inProgress;
  final int unresolved;

  const _StatusPieCard({
    required this.resolved,
    required this.inProgress,
    required this.unresolved,
  });

  @override
  Widget build(BuildContext context) {
    final total = resolved + inProgress + unresolved;
    double pct(int v) => total == 0 ? 0.0 : v / total * 100;

    return _Card(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Status das ocorrências',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.pal.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: Center(
              child: CustomPaint(
                size: const Size(150, 150),
                painter: _PieChartPainter(
                  values: [
                    resolved.toDouble(),
                    inProgress.toDouble(),
                    unresolved.toDouble(),
                  ],
                  colors: const [
                    _resolvedColor,
                    _pendingColor,
                    _unresolvedColor,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PieLegendLabel(
                label: 'Concluído',
                color: _resolvedColor,
                value: resolved,
                percent: pct(resolved),
              ),
              _PieLegendLabel(
                label: 'Pendente',
                color: _pendingColor,
                value: inProgress,
                percent: pct(inProgress),
              ),
              _PieLegendLabel(
                label: 'Não resolvido',
                color: _unresolvedColor,
                value: unresolved,
                percent: pct(unresolved),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PieLegendLabel extends StatelessWidget {
  final String label;
  final Color color;
  final int value;
  final double percent;

  const _PieLegendLabel({
    required this.label,
    required this.color,
    required this.value,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: context.pal.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  const _PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    final rect = Offset.zero & size;
    var startAngle = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweepAngle = values[i] / total * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

// ─────────────────────────────────────────
//  LINE CHART CARD (ocorrências por dia da semana)
// ─────────────────────────────────────────

class _WeeklyLineCard extends StatelessWidget {
  final List<int> data;
  final List<String> labels;

  const _WeeklyLineCard({required this.data, required this.labels});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final maxValue = data.isEmpty ? 0 : data.reduce(math.max);
    final axisMax = _niceAxisMax(maxValue);

    return _Card(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(
                data: data,
                labels: labels,
                axisMax: axisMax,
                gridColor: pal.border,
                lineColor: pal.ink,
                markerFillColor: pal.surface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(24, 12),
                painter: _LineLegendIconPainter(
                  lineColor: pal.ink,
                  markerFillColor: pal.surface,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Quantidade de Ocorrências',
                style: TextStyle(
                  fontSize: 12,
                  color: context.pal.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineLegendIconPainter extends CustomPainter {
  final Color lineColor;
  final Color markerFillColor;
  const _LineLegendIconPainter({
    required this.lineColor,
    required this.markerFillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final center = Offset(size.width / 2, y);
    canvas.drawCircle(center, 3, Paint()..color = markerFillColor);
    canvas.drawCircle(
      center,
      3,
      Paint()
        ..color = _chartPurple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _LineLegendIconPainter oldDelegate) => false;
}

class _LineChartPainter extends CustomPainter {
  final List<int> data;
  final List<String> labels;
  final int axisMax;
  final Color gridColor;
  final Color lineColor;
  final Color markerFillColor;

  const _LineChartPainter({
    required this.data,
    required this.labels,
    required this.axisMax,
    required this.gridColor,
    required this.lineColor,
    required this.markerFillColor,
  });

  static const _ySteps = 5;
  static const _labelStyle = TextStyle(color: _axisLabelColor, fontSize: 10);
  static const _leftPadding = 28.0;
  static const _bottomPadding = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartWidth = size.width - _leftPadding;
    final chartHeight = size.height - _bottomPadding;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Linhas de grade horizontais + rótulos do eixo Y
    for (var i = 0; i <= _ySteps; i++) {
      final value = (axisMax / _ySteps * i).round();
      final y =
          chartHeight - (axisMax == 0 ? 0 : value / axisMax) * chartHeight;
      _drawDashedLine(
        canvas,
        Offset(_leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );

      final tp = TextPainter(
        text: TextSpan(text: '$value', style: _labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPadding - tp.width - 6, y - tp.height / 2));
    }

    // Pontos do gráfico
    final n = data.length;
    final stepX = n > 1 ? chartWidth / (n - 1) : 0.0;
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = _leftPadding + stepX * i;
      final ratio = axisMax == 0 ? 0.0 : data[i] / axisMax;
      final y = chartHeight - ratio * chartHeight;
      points.add(Offset(x, y));
    }

    // Linha conectando os pontos
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Marcadores (círculos vazados)
    final markerFill = Paint()..color = markerFillColor;
    final markerBorder = Paint()
      ..color = _chartPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in points) {
      canvas.drawCircle(p, 4, markerFill);
      canvas.drawCircle(p, 4, markerBorder);
    }

    // Rótulos do eixo X
    for (var i = 0; i < n && i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: _labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, chartHeight + 8));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final totalLength = (end - start).distance;
    if (totalLength == 0) return;
    final dx = (end.dx - start.dx) / totalLength;
    final dy = (end.dy - start.dy) / totalLength;
    var covered = 0.0;
    while (covered < totalLength) {
      final from = Offset(start.dx + dx * covered, start.dy + dy * covered);
      final segmentEnd = math.min(covered + dashWidth, totalLength);
      final to = Offset(start.dx + dx * segmentEnd, start.dy + dy * segmentEnd);
      canvas.drawLine(from, to, paint);
      covered += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.axisMax != axisMax;
  }
}

// ─────────────────────────────────────────
//  BAR CHART CARD (ocorrências por categoria)
// ─────────────────────────────────────────

class _CategoryBarCard extends StatelessWidget {
  final List<MapEntry<OccurrenceType, int>> data;

  const _CategoryBarCard({required this.data});

  static const _labelWidth = 110.0;
  static const _valueWidth = 28.0;
  static const _axisSteps = 5;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Sem ocorrências registradas neste período.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final maxValue = data.map((e) => e.value).reduce(math.max);
    final axisMax = _niceAxisMax(maxValue);
    final axisValues = List.generate(
      _axisSteps + 1,
      (i) => (axisMax / _axisSteps * i).round(),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: _labelWidth + 8,
              right: _valueWidth + 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: axisValues
                  .map(
                    (v) => Text(
                      '$v',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _axisLabelColor,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: context.pal.border),
          const SizedBox(height: 4),
          ...data.map(
            (entry) => _CategoryBarRow(
              type: entry.key,
              value: entry.value,
              axisMax: axisMax == 0 ? 1 : axisMax,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _chartPurple,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Total de ocorrências por categoria',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.pal.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBarRow extends StatelessWidget {
  final OccurrenceType type;
  final int value;
  final int axisMax;

  const _CategoryBarRow({
    required this.type,
    required this.value,
    required this.axisMax,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (value / axisMax).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: _CategoryBarCard._labelWidth,
            child: Text(
              type.label,
              style: TextStyle(fontSize: 12, color: context.pal.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.pal.surfaceAlt,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: _chartPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _CategoryBarCard._valueWidth,
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _chartPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────

/// Calcula um valor "redondo" para o topo do eixo (ex.: 5, 10, 20, 50, 100...)
/// de forma que os dados sempre caibam confortavelmente dentro da escala.
int _niceAxisMax(int maxValue) {
  if (maxValue <= 0) return 5;

  final magnitude = math
      .pow(10, (math.log(maxValue) / math.ln10).floor())
      .toInt();
  final residual = maxValue / magnitude;

  late final int niceResidual;
  if (residual <= 1) {
    niceResidual = 1;
  } else if (residual <= 2) {
    niceResidual = 2;
  } else if (residual <= 5) {
    niceResidual = 5;
  } else {
    niceResidual = 10;
  }

  final result = niceResidual * magnitude;
  return result < 4 ? 4 : result;
}
