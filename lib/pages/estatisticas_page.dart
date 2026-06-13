import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ocorrencia_model.dart';
import '../services/ocorrencia_service.dart';
import '../models/occurrence_types.dart';

// ─────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────

const _resolvedColor = Color(0xFF22C55E);
const _pendingColor = Color(0xFFF97316);
const _unresolvedColor = Color(0xFFEF4444);
const _chartPurple = Color(0xFF8B7CF6);
const _gridColor = Color(0xFFE5E7EB);
const _axisLabelColor = Color(0xFF9CA3AF);
const _legendTextColor = Color(0xFF6B7280);

// ─────────────────────────────────────────
//  ESTATÍSTICAS PAGE
// ─────────────────────────────────────────

class EstatisticasPage extends StatefulWidget {
  const EstatisticasPage({super.key});

  @override
  State<EstatisticasPage> createState() => _EstatisticasPageState();
}

class _EstatisticasPageState extends State<EstatisticasPage> {
  final _ocorrenciaService = OcorrenciaService();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Row(
          children: [
            Text(
              'EcoJP',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Estatísticas',
              style: TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFD8D8D8)),
        ),
      ),
      body: StreamBuilder<List<OcorrenciaModel>>(
        stream: _ocorrenciaService.listarOcorrencias(),
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

          final statusCounts = _statusCounts(ocorrencias);
          final weeklyCounts = _weeklyCounts(ocorrencias);
          final categoryCounts = _categoryCounts(ocorrencias);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _StatusPieCard(
                resolved: statusCounts[OccurrenceStatus.resolved] ?? 0,
                inProgress: statusCounts[OccurrenceStatus.inProgress] ?? 0,
                unresolved: statusCounts[OccurrenceStatus.unresolved] ?? 0,
              ),
              const SizedBox(height: 16),
              _WeeklyLineCard(data: weeklyCounts, labels: _weekDayLabels),
              const SizedBox(height: 16),
              _CategoryBarCard(data: categoryCounts),
            ],
          );
        },
      ),
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
        color: Colors.white,
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
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Status das ocorrências',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
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
                label: 'Em andamento',
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
              style: const TextStyle(fontSize: 11, color: _legendTextColor),
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
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CustomPaint(
                size: Size(24, 12),
                painter: _LineLegendIconPainter(),
              ),
              const SizedBox(width: 6),
              const Text(
                'Quantidade de Ocorrências',
                style: TextStyle(
                  fontSize: 12,
                  color: _legendTextColor,
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
  const _LineLegendIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final linePaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final center = Offset(size.width / 2, y);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
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

  const _LineChartPainter({
    required this.data,
    required this.labels,
    required this.axisMax,
  });

  static const _ySteps = 5;
  static const _labelStyle = TextStyle(color: _axisLabelColor, fontSize: 10);
  static const _lineStrokeColor = Color(0xFF374151);
  static const _leftPadding = 28.0;
  static const _bottomPadding = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartWidth = size.width - _leftPadding;
    final chartHeight = size.height - _bottomPadding;

    final gridPaint = Paint()
      ..color = _gridColor
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
        ..color = _lineStrokeColor
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
    final markerFill = Paint()..color = Colors.white;
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
          const Divider(height: 1, color: _gridColor),
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
              const Flexible(
                child: Text(
                  'Quantidade de ocorrências (mês) por categoria',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _legendTextColor,
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
              style: const TextStyle(fontSize: 12, color: _legendTextColor),
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
                    color: const Color(0xFFF3F4F6),
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
