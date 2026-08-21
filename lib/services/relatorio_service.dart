import 'dart:async';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ocorrencia_model.dart';
import '../models/occurrence_types.dart';
import '../models/usuario_model.dart';
import '../pages/mapPage/controller/calc_mostaffectedzones.dart';
import 'analytics_service.dart';

/// Gera um relatório PDF das denúncias (triagem) para a autoridade levar a
/// reuniões. O conteúdo é agregado — não expõe dados pessoais do denunciante.
class RelatorioService {
  static final RelatorioService instance = RelatorioService();

  final AnalyticsService _analytics = AnalyticsService();
  Future<void> gerarECompartilhar({
    required List<OcorrenciaModel> ocorrencias,
    required String periodoLabel,
  }) async {
    final doc = pw.Document();
    final agora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // ── Agregados ──
    final total = ocorrencias.length;

    final statusCount = <OccurrenceStatus, int>{};
    for (final o in ocorrencias) {
      final s = OccurrenceStatusParser.fromString(o.status);
      statusCount[s] = (statusCount[s] ?? 0) + 1;
    }

    final estagioCount = <EstagioOficial, int>{};
    for (final o in ocorrencias) {
      final e = EstagioOficialInfo.calcular(o.verificada, o.statusOficial);
      estagioCount[e] = (estagioCount[e] ?? 0) + 1;
    }

    final categoriaCount = <OccurrenceType, int>{};
    for (final o in ocorrencias) {
      final c = OccurrenceTypeParser.fromString(o.tipoLixo);
      categoriaCount[c] = (categoriaCount[c] ?? 0) + 1;
    }
    final categorias = categoriaCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bairros = CalcMostAffectedZones(
      ocorrencias,
    ).zonasMaisAfetadas(limite: 10);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EcoJP — Relatório de Denúncias',
                  style: const pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Período: $periodoLabel  •  Gerado em $agora',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Total de denúncias no período: $total',
            style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),

          _secao('Ciclo de triagem oficial'),
          _tabela([
            for (final e in EstagioOficial.values)
              [e.label, '${estagioCount[e] ?? 0}'],
          ]),
          pw.SizedBox(height: 16),

          _secao('Status das denúncias'),
          _tabela([
            for (final s in OccurrenceStatus.values)
              [s.label, '${statusCount[s] ?? 0}'],
          ]),
          pw.SizedBox(height: 16),

          _secao('Denúncias por categoria'),
          _tabela([
            for (final c in categorias) [c.key.label, '${c.value}'],
          ]),
          pw.SizedBox(height: 16),

          _secao('Bairros mais afetados'),
          if (bairros.isEmpty)
            pw.Text(
              'Sem dados de bairro disponíveis.',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            )
          else
            _tabela([
              for (final b in bairros) [b.bairro, '${b.quantidade}'],
            ]),

          pw.SizedBox(height: 24),
          pw.Text(
            'Relatório gerado automaticamente pelo aplicativo EcoJP. Dados '
            'agregados, sem identificação dos denunciantes.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'relatorio_ecojp_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Exporta os dados pessoais do próprio usuário (LGPD art. 18 — acesso e
  /// portabilidade): perfil, consentimento e as denúncias que ele registrou.
  Future<void> exportarMeusDados({
    required UsuarioModel perfil,
    required List<OcorrenciaModel> ocorrencias,
    String? email,
    DateTime? consentimentoEm,
  }) async {
    final doc = pw.Document();
    final agora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final fmtData = DateFormat('dd/MM/yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EcoJP — Meus Dados',
                  style: const pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Exportado em $agora',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          _secao('Perfil'),
          _tabela([
            ['Nome', perfil.nome.isEmpty ? '—' : perfil.nome],
            if (email != null && email.isNotEmpty) ['E-mail', email],
            ['Bairro', perfil.bairro.isEmpty ? '—' : perfil.bairro],
            ['Bio', perfil.bio.isEmpty ? '—' : perfil.bio],
            if (consentimentoEm != null)
              ['Consentimento em', fmtData.format(consentimentoEm)],
          ]),
          pw.SizedBox(height: 16),

          _secao('Minhas denúncias (${ocorrencias.length})'),
          if (ocorrencias.isEmpty)
            pw.Text(
              'Você ainda não registrou denúncias.',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            )
          else
            for (final o in ocorrencias) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      o.titulo.isEmpty ? 'Sem título' : o.titulo,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${o.tipoLixo} • ${o.localizacao}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (o.dataCriacao != null)
                      pw.Text(
                        'Registrada em ${fmtData.format(o.dataCriacao!)}'
                        '${o.anonima ? ' (anônima)' : ''}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                  ],
                ),
              ),
            ],

          pw.SizedBox(height: 24),
          pw.Text(
            'Documento gerado a seu pedido, contendo os dados pessoais '
            'associados à sua conta no EcoJP (LGPD art. 18).',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'meus_dados_ecojp_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    unawaited(_analytics.dadosExportados());
  }

  pw.Widget _secao(String titulo) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      titulo,
      style: const pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.green800,
      ),
    ),
  );

  pw.Widget _tabela(List<List<String>> linhas) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        for (final linha in linhas)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                child: pw.Text(linha[0], style: const pw.TextStyle(fontSize: 11)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                child: pw.Text(
                  linha[1],
                  style: const pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
