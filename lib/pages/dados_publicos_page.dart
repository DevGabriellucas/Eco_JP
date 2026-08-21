import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/ocorrencia_repository.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/ocorrencia_model.dart';
import '../models/occurrence_types.dart';
import '../models/rota_coleta_model.dart';
import '../services/rota_coleta_service.dart';
import '../theme/app_theme.dart';
import '../utils/dicas_reciclagem.dart';
import '../utils/texto.dart';
import 'mapPage/controller/calc_mostaffectedzones.dart';
import 'mapPage/widgets/rota_coleta_sheet.dart';

/// Painel público para o cidadão (aba "Dados"). Enquanto a autoridade vê a
/// ferramenta de triagem, o cidadão vê informação útil sobre o lixo da cidade:
/// 1. Dashboard da Cidade — números agregados das denúncias;
/// 2. Guia de Coleta — dias de coleta por bairro (cronograma da Emlur);
/// 3. Dicas de Reciclagem — como separar cada tipo de material.
class DadosPublicosView extends ConsumerStatefulWidget {
  const DadosPublicosView({super.key});

  @override
  ConsumerState<DadosPublicosView> createState() => _DadosPublicosViewState();
}

class _DadosPublicosViewState extends ConsumerState<DadosPublicosView> {
  // Stream fixo (criado uma vez): evita re-subscrição e flicker de loading a
  // cada setState da busca por bairro.
  late final Stream<List<OcorrenciaModel>> _ocorrenciasStream;

  List<RotaColetaModel> _rotas = [];
  bool _carregandoRotas = true;
  String _buscaBairro = '';

  @override
  void initState() {
    super.initState();
    _ocorrenciasStream = ref
        .read(ocorrenciaRepositoryProvider)
        .listarOcorrenciasLimitadas(OcorrenciaRepository.tetoAgregado);
    _carregarRotas();
  }

  Future<void> _carregarRotas() async {
    try {
      final rotas = await RotaColetaService.instance.carregarRotas();
      if (!mounted) return;
      setState(() {
        _rotas = rotas;
        _carregandoRotas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregandoRotas = false);
    }
  }

  List<RotaColetaModel> _agendasDoBairro(String bairro) =>
      _rotas.where((r) => r.bairro == bairro).toList();

  List<String> get _bairrosOrdenados {
    final nomes = _rotas.map((r) => r.bairro).toSet().toList();
    nomes.sort(
      (a, b) => removerAcentos(
        a,
      ).toLowerCase().compareTo(removerAcentos(b).toLowerCase()),
    );
    return nomes;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _secaoDashboard(),
        const SizedBox(height: 24),
        _secaoGuiaColeta(),
        const SizedBox(height: 24),
        _secaoDicas(),
      ],
    );
  }

  // ── Seção 1: Dashboard da Cidade ─────────────────────────────────────────

  Widget _secaoDashboard() {
    return StreamBuilder<List<OcorrenciaModel>>(
      stream: _ocorrenciasStream,
      builder: (context, snapshot) {
        final ocorrencias = snapshot.data ?? const [];
        final carregando = snapshot.connectionState == ConnectionState.waiting;
        return _DashboardCidade(
          ocorrencias: ocorrencias,
          carregando: carregando,
        );
      },
    );
  }

  // ── Seção 2: Guia de Coleta por Bairro ───────────────────────────────────

  Widget _secaoGuiaColeta() {
    final pal = context.pal;
    final termo = removerAcentos(_buscaBairro).toLowerCase().trim();
    final filtrados = termo.isEmpty
        ? const <String>[]
        : _bairrosOrdenados
              .where((b) => removerAcentos(b).toLowerCase().contains(termo))
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSecao(
          icone: Icons.local_shipping_outlined,
          titulo: 'Coleta de lixo por bairro',
          subtitulo: 'Descubra os dias de coleta domiciliar da Emlur',
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _buscaBairro = v),
          style: TextStyle(color: pal.ink),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Digite o nome do seu bairro',
            hintStyle: TextStyle(color: pal.hint),
            prefixIcon: Icon(Icons.search, color: pal.hint),
            isDense: true,
            filled: true,
            fillColor: pal.surface,
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
        const SizedBox(height: 12),
        if (_carregandoRotas)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (termo.isEmpty)
          const _AvisoGuia(
            texto:
                'Digite o nome do seu bairro acima para ver os dias e turnos '
                'de coleta.',
          )
        else if (filtrados.isEmpty)
          _AvisoGuia(
            texto:
                'Nenhum bairro encontrado com "$_buscaBairro". Confira a '
                'grafia ou consulte joaopessoa.pb.gov.br.',
          )
        else
          for (final bairro in filtrados.take(12))
            _BairroTile(
              bairro: bairro,
              agendas: _agendasDoBairro(bairro),
              onTap: () => mostrarAgendaBairroSheet(
                context,
                bairro,
                _agendasDoBairro(bairro),
              ),
            ),
      ],
    );
  }

  // ── Seção 3: Dicas de Reciclagem ─────────────────────────────────────────

  Widget _secaoDicas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSecao(
          icone: Icons.recycling_outlined,
          titulo: 'Dicas de reciclagem',
          subtitulo: 'Como separar cada tipo de material corretamente',
        ),
        const SizedBox(height: 12),
        for (final dica in dicasReciclagem) ...[
          _DicaCard(dica: dica),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  DASHBOARD DA CIDADE
// ─────────────────────────────────────────────────────────────────────────

class _DashboardCidade extends StatelessWidget {
  final List<OcorrenciaModel> ocorrencias;
  final bool carregando;

  const _DashboardCidade({required this.ocorrencias, required this.carregando});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;

    final total = ocorrencias.length;
    final resolvidas = ocorrencias
        .where((o) => o.verificada && o.statusOficial == StatusOficial.resolvida)
        .length;
    final taxa = total == 0 ? 0 : (resolvidas * 100 / total).round();

    final categorias = _categorias(ocorrencias).take(4).toList();
    final bairros = CalcMostAffectedZones(
      ocorrencias,
    ).zonasMaisAfetadas(limite: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSecao(
          icone: Icons.insights_outlined,
          titulo: 'Panorama da cidade',
          subtitulo: 'Denúncias ambientais em João Pessoa',
        ),
        const SizedBox(height: 12),

        if (carregando && total == 0)
          const _CardPublico(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (total == 0)
          _CardPublico(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Ainda não há denúncias registradas na cidade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted, fontSize: 13),
                ),
              ),
            ),
          )
        else ...[
          // Números principais
          Row(
            children: [
              Expanded(
                child: _NumeroCard(
                  valor: '$total',
                  rotulo: 'Denúncias',
                  cor: pal.primary,
                  icone: Icons.campaign_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumeroCard(
                  valor: '$resolvidas',
                  rotulo: 'Resolvidas',
                  cor: AppColors.success,
                  icone: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumeroCard(
                  valor: '$taxa%',
                  rotulo: 'Taxa',
                  cor: const Color(0xFF3B82F6),
                  icone: Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Categorias mais reportadas
          if (categorias.isNotEmpty)
            _CardPublico(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipos mais reportados',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: pal.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final e in categorias) ...[
                    _BarraCategoria(tipo: e.key, valor: e.value, total: total),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Bairros mais afetados
          if (bairros.isNotEmpty)
            _CardPublico(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bairros mais afetados',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: pal.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < bairros.length; i++) ...[
                    _LinhaBairroRanking(
                      posicao: i + 1,
                      bairro: bairros[i].bairro,
                      quantidade: bairros[i].quantidade,
                      ratio: bairros.first.quantidade == 0
                          ? 0
                          : bairros[i].quantidade / bairros.first.quantidade,
                    ),
                    if (i != bairros.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }

  List<MapEntry<OccurrenceType, int>> _categorias(List<OcorrenciaModel> lista) {
    final counts = <OccurrenceType, int>{};
    for (final o in lista) {
      final t = OccurrenceTypeParser.fromString(o.tipoLixo);
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

class _NumeroCard extends StatelessWidget {
  final String valor;
  final String rotulo;
  final Color cor;
  final IconData icone;

  const _NumeroCard({
    required this.valor,
    required this.rotulo,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: pal.muted),
          ),
        ],
      ),
    );
  }
}

class _BarraCategoria extends StatelessWidget {
  final OccurrenceType tipo;
  final int valor;
  final int total;

  const _BarraCategoria({
    required this.tipo,
    required this.valor,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final cor = tipo.color;
    final ratio = total == 0 ? 0.0 : valor / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(tipo.icon, size: 14, color: cor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tipo.label,
                style: TextStyle(
                  fontSize: 12,
                  color: pal.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$valor',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: pal.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(cor),
          ),
        ),
      ],
    );
  }
}

class _LinhaBairroRanking extends StatelessWidget {
  final int posicao;
  final String bairro;
  final int quantidade;
  final double ratio;

  const _LinhaBairroRanking({
    required this.posicao,
    required this.bairro,
    required this.quantidade,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const roxo = Color(0xFF8B7CF6);
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: roxo.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$posicao',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: roxo,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pal.ink,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: pal.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation(roxo),
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
            color: roxo,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  GUIA DE COLETA
// ─────────────────────────────────────────────────────────────────────────

class _BairroTile extends StatelessWidget {
  final String bairro;
  final List<RotaColetaModel> agendas;
  final VoidCallback onTap;

  const _BairroTile({
    required this.bairro,
    required this.agendas,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final coletaHoje = agendas.any((a) => a.coletaHoje);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Row(
          children: [
            Flexible(
              child: Text(
                bairro,
                style: TextStyle(fontWeight: FontWeight.w600, color: pal.ink),
              ),
            ),
            if (coletaHoje) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Hoje',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: agendas.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in agendas)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 4,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: a.turno.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${a.descricaoDias} · '
                                '${a.turno == TurnoColeta.diurno ? 'diurno' : 'noturno'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: pal.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
        trailing: Icon(Icons.chevron_right, color: pal.hint),
      ),
    );
  }
}

class _AvisoGuia extends StatelessWidget {
  final String texto;

  const _AvisoGuia({required this.texto});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: pal.hint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 13, color: pal.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  DICAS DE RECICLAGEM (card expansível)
// ─────────────────────────────────────────────────────────────────────────

class _DicaCard extends StatefulWidget {
  final DicaReciclagem dica;

  const _DicaCard({required this.dica});

  @override
  State<_DicaCard> createState() => _DicaCardState();
}

class _DicaCardState extends State<_DicaCard> {
  bool _aberto = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final d = widget.dica;

    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _aberto = !_aberto),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: d.cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(d.icone, size: 20, color: d.cor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d.titulo,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pal.ink,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _aberto ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: pal.hint),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _aberto
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.descarte,
                    style: TextStyle(
                      fontSize: 13,
                      color: pal.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final ex in d.exemplos)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: d.cor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ex,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: d.cor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  COMPARTILHADOS
// ─────────────────────────────────────────────────────────────────────────

class _TituloSecao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;

  const _TituloSecao({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Row(
      children: [
        Icon(icone, size: 20, color: pal.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: pal.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitulo, style: TextStyle(fontSize: 12, color: pal.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardPublico extends StatelessWidget {
  final Widget child;

  const _CardPublico({required this.child});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: child,
    );
  }
}
