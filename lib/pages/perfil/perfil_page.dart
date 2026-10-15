import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/ocorrencia_repository.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/denuncias/providers/denuncia_providers.dart';
import '../../models/ocorrencia_model.dart';
import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/notificacao_service.dart';
import '../../utils/cloudinary_image.dart';
import '../../utils/imagem_cacheada.dart';
import '../../utils/conquistas.dart';
import '../../services/usuario_service.dart';
import '../detalhe_ocorrencia_page.dart';
import 'configuracoes_conta_page.dart';
import '../../models/occurrence_types.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ocorrencia_actions.dart';
import 'editar_perfil_page.dart';

class _Cores {
  // Placeholder de denúncia; os neutros vêm de `context.pal`.
  static const avatarBg = Color(0xFF9E9E9E);
}

class PerfilPage extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const PerfilPage({super.key, this.scrollController});

  @override
  ConsumerState<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends ConsumerState<PerfilPage> {
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _notificacaoService = NotificacaoService();

  OcorrenciaRepository get _ocorrenciaRepository =>
      ref.read(ocorrenciaRepositoryProvider);

  bool _mostrarTodasDenuncias = false;

  // Criadas uma vez: streams novas a cada build faziam o StreamBuilder voltar
  // a "waiting" (spinner) e abrir outro listener a cada rebuild.
  String? _uid;
  Stream<UsuarioModel?>? _perfilStream;
  Stream<List<OcorrenciaModel>>? _minhasDenunciasStream;

  // Última combinação de conquistas já conferida contra o Firestore. A
  // checagem rodava a cada rebuild do perfil (2 leituras cada, mesmo
  // negadas); agora só roda quando o conjunto desbloqueado muda.
  Set<String>? _conquistasConferidas;

  // Perfil real vindo do Firestore (null enquanto carrega).
  UsuarioModel? _perfilCarregado;

  @override
  void initState() {
    super.initState();
    _uid = _authService.currentUser?.uid;
    final uid = _uid;
    if (uid != null) {
      _perfilStream = _usuarioService.observarPerfil(uid);
      _minhasDenunciasStream = _ocorrenciaRepository.listarMinhasDenuncias(uid);
    }
  }

  static const _meses = [
    '01',
    '02',
    '03',
    '04',
    '05',
    '06',
    '07',
    '08',
    '09',
    '10',
    '11',
    '12',
  ];

  /// Só abre com o perfil real carregado. Antes abria com um perfil
  /// provisório (prefixo do e-mail, sem foto/bio/bairro): salvar gravava o
  /// prefixo como nome público e apagava o resto.
  void _abrirEdicao(UsuarioModel? perfil) {
    if (perfil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Carregando seu perfil. Tente em instantes.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditarPerfilPage(perfilAtual: perfil)),
    );
  }

  // Pull-to-refresh: os dados vêm de streams (atualizam sozinhos), então só
  // reconstruímos a tela e damos um pequeno tempo para o gesto completar.
  Future<void> _recarregar() async {
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _verificarConquistasNovas(
      _Stats stats, bool isAutoridade) async {
    final uid = _uid;
    if (uid == null) return;

    final conquistasAtuais = calcularConquistas(
      denuncias: stats.total,
      resolvidas: stats.resolvidasOficial,
      curtidas: stats.curtidas,
      isAutoridade: isAutoridade,
    );

    final conquistasDesbloqueadas = conquistasAtuais
        .where((c) => c.desbloqueada)
        .map((c) => c.titulo)
        .toSet();
    final conferidas = _conquistasConferidas;
    if (conferidas != null &&
        conferidas.length == conquistasDesbloqueadas.length &&
        conferidas.containsAll(conquistasDesbloqueadas)) {
      return;
    }
    _conquistasConferidas = conquistasDesbloqueadas;

    try {
      final conquistasNotificadas =
          await _usuarioService.conquistasNotificadas(uid);

      final novasConquistas =
          conquistasDesbloqueadas.difference(conquistasNotificadas);

      for (final titulo in novasConquistas) {
        await _notificacaoService.notificarConquista(
          userId: uid,
          conquistaTitulo: titulo,
        );
      }

      if (novasConquistas.isNotEmpty) {
        await _usuarioService.salvarConquistasNotificadas(
          uid,
          conquistasDesbloqueadas,
        );
      }
    } catch (e) {
      // Tenta de novo na próxima mudança de dados.
      _conquistasConferidas = null;
      debugPrint('Erro ao verificar conquistas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final uid = _uid;
    // Órgão não usa as seções de cidadão (impacto, conquistas, minhas
    // denúncias, salvos) — são recursos de gamificação/participação do cidadão.
    final isAutoridade = ref.watch(isAutoridadeProvider).value == true;

    if (uid == null) {
      return Scaffold(
        backgroundColor: pal.background,
        body: Center(
          child: Text(
            'Faça login para ver seu perfil.',
            style: TextStyle(color: pal.ink),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pal.background,
      body: StreamBuilder<UsuarioModel?>(
        stream: _perfilStream,
        builder: (context, perfilSnap) {
          // Enquanto carrega, mostra o cartão sem nome — nunca o prefixo do
          // e-mail. A edição só abre com o perfil real (ver _abrirEdicao).
          _perfilCarregado = perfilSnap.data;
          final perfil = perfilSnap.data ?? UsuarioModel(uid: uid, nome: '');

          return StreamBuilder<List<OcorrenciaModel>>(
            stream: _minhasDenunciasStream,
            builder: (context, ocSnap) {
              final ocorrencias = ocSnap.data ?? [];
              final stats = _calcularStats(ocorrencias);
              if (ocSnap.hasData) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _verificarConquistasNovas(stats, isAutoridade),
                );
              }

              return RefreshIndicator(
                onRefresh: _recarregar,
                child: ListView(
                  controller: widget.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _cabecalhoPerfil(perfil),
                    // Seções de cidadão: só para contas comuns. O órgão vê
                    // apenas o cartão de perfil (dados da conta) — sem
                    // gamificação nem abas de participação.
                    if (!isAutoridade) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          children: [
                            _cardImpacto(stats),
                            const SizedBox(height: 16),
                            _cardConquistas(stats),
                            const SizedBox(height: 16),
                            _secaoMinhasDenuncias(ocorrencias),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _cabecalhoPerfil(UsuarioModel perfil) {
    final pal = context.pal;
    final bairro = perfil.bairro.trim();
    final bio = perfil.bio.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAutoridade = ref.watch(isAutoridadeProvider).value == true;
    return Container(
      color: pal.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PerfilContourPainter(
                color: pal.border.withValues(alpha: isDark ? 0.3 : 0.8),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Perfil',
                          style: TextStyle(
                            color: pal.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Conta e privacidade',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ConfiguracoesContaPage(),
                          ),
                        ),
                        icon: Icon(Icons.more_horiz, color: pal.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _avatar(perfil, radius: 29),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              perfil.nome.trim().isEmpty
                                  ? 'Sem nome'
                                  : perfil.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: pal.ink,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: pal.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    bairro.isEmpty
                                        ? 'João Pessoa'
                                        : '$bairro, João Pessoa',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: pal.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isAutoridade) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    size: 13,
                                    color: pal.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Autoridade',
                                    style: TextStyle(
                                      color: pal.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    bio.isEmpty
                        ? 'Conte um pouco sobre você no seu perfil.'
                        : bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pal.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirEdicao(_perfilCarregado),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: pal.ink,
                        side: BorderSide(color: pal.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: const Text(
                        'Editar perfil',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(UsuarioModel perfil, {double radius = 29}) {
    final pal = context.pal;
    if (perfil.fotoUrl != null && perfil.fotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: pal.surfaceAlt,
        backgroundImage: imagemCacheada(
          cloudinaryAvatar(perfil.fotoUrl!, radius: radius),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: pal.primary.withValues(alpha: 0.14),
      child: Text(
        perfil.iniciais,
        style: TextStyle(
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w600,
          color: pal.primary,
        ),
      ),
    );
  }

  Widget _impactoItem(String valor, String label, {bool marcador = false}) {
    final pal = context.pal;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (marcador)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: pal.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 6, height: 6),
                  ),
                ),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, height: 1.2, color: pal.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardImpacto(_Stats stats) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Meu impacto',
              style: TextStyle(
                color: pal.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.95,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _impactoItem('${stats.total}', 'Denúncias'),
              _impactoItem(
                '${stats.verificadas}',
                'Verificadas pela autoridade',
                marcador: true,
              ),
              _impactoItem(
                '${stats.resolvidasOficial}',
                'Resolvidas oficialmente',
                marcador: true,
              ),
              _impactoItem('${stats.curtidas}', 'Curtidas recebidas'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                stats.categoriaTop == null
                    ? Icons.delete_outline
                    : OccurrenceTypeParser.fromString(stats.categoriaTop!).icon,
                size: 16,
                color: pal.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Categoria mais reportada',
                  style: TextStyle(fontSize: 12, color: pal.muted),
                ),
              ),
              Text(
                stats.categoriaTop == null
                    ? 'Nenhuma'
                    : '${stats.categoriaTop} · ${stats.categoriaTopTotal}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: pal.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Conquistas (gamificação): badges derivados das estatísticas do usuário.
  // As desbloqueadas aparecem coloridas; as pendentes, esmaecidas com o
  // progresso atual (ex.: "3/5").
  Widget _cardConquistas(_Stats stats) {
    final pal = context.pal;
    final isAutoridade = ref.watch(isAutoridadeProvider).value == true;
    final conquistas = calcularConquistas(
      denuncias: stats.total,
      resolvidas: stats.resolvidasOficial,
      curtidas: stats.curtidas,
      isAutoridade: isAutoridade,
    );
    final desbloqueadas = conquistas.where((c) => c.desbloqueada).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Conquistas',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: pal.ink,
                ),
              ),
              const Spacer(),
              Text(
                '$desbloqueadas/${conquistas.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: pal.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GradeConquistas(conquistas: conquistas),
        ],
      ),
    );
  }

  // ── Seção: Minhas denúncias ───────────────────────────────────────────────

  Widget _secaoMinhasDenuncias(List<OcorrenciaModel> ocorrencias) {
    final pal = context.pal;
    final ordenadas = [...ocorrencias]..sort((a, b) {
        final da = a.dataCriacao;
        final db = b.dataCriacao;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    final exibidas = _mostrarTodasDenuncias || ordenadas.length <= 3
        ? ordenadas
        : ordenadas.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Minhas denúncias',
                  style: TextStyle(
                    color: pal.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (ordenadas.length > 3)
                TextButton(
                  onPressed: () => setState(
                    () => _mostrarTodasDenuncias = !_mostrarTodasDenuncias,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: pal.primary,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(
                    _mostrarTodasDenuncias ? 'Mostrar menos' : 'Ver todas',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (exibidas.isEmpty)
            _denunciasVazio()
          else
            for (var i = 0; i < exibidas.length; i++) ...[
              if (i > 0) Divider(height: 1, color: pal.border),
              _denunciaCard(exibidas[i]),
            ],
        ],
      ),
    );
  }

  Widget _denunciasVazio() {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 24),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 36, color: pal.hint),
          const SizedBox(height: 8),
          Text(
            'Você ainda não fez nenhuma denúncia',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: pal.muted),
          ),
        ],
      ),
    );
  }

  Widget _denunciaCard(OcorrenciaModel o) {
    final pal = context.pal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _mostrarDetalhes(o),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _denunciaThumb(o),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.titulo.trim().isEmpty ? 'Sem título' : o.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _statusBadge(o.statusAtual),
                        const SizedBox(width: 8),
                        Text(
                          _formatarData(o.dataCriacao),
                          style: TextStyle(fontSize: 11, color: pal.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Gerenciar denúncia',
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: Icon(Icons.more_horiz, color: pal.muted),
                onSelected: (_) => showOcorrenciaActions(
                  context: context,
                  ocorrencia: o,
                  service: _ocorrenciaRepository,
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'gerenciar',
                    child: Text('Gerenciar denúncia'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _denunciaThumb(OcorrenciaModel o) {
    final url = o.imagemUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: (url != null && url.isNotEmpty)
          ? Builder(
              builder: (context) {
                final dpr = MediaQuery.devicePixelRatioOf(context);
                return Image(
                  image: imagemCacheada(
                    cloudinaryOtimizada(
                      url,
                      larguraLogica: 56,
                      alturaLogica: 56,
                      devicePixelRatio: dpr,
                      crop: 'fill',
                    ),
                    cacheWidth: cacheLarguraPx(56, dpr),
                  ),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto da denúncia: ${o.titulo}',
                  errorBuilder: (context, error, stackTrace) =>
                      _thumbPlaceholder(),
                );
              },
            )
          : _thumbPlaceholder(),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: _Cores.avatarBg,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 24,
        color: Colors.white,
      ),
    );
  }

  Widget _statusBadge(OccurrenceStatus s) {
    final cor = s.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '';
    final dia = data.day.toString().padLeft(2, '0');
    return '$dia/${_meses[data.month - 1]}';
  }

  void _mostrarDetalhes(OcorrenciaModel o) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalheOcorrenciaPage(occurrence: o)),
    );
  }

  // ── Estatísticas ──────────────────────────────────────────────────────────

  _Stats _calcularStats(List<OcorrenciaModel> ocorrencias) {
    final base = ocorrencias.length;

    // categoria mais reportada (moda de tipoLixo)
    String? categoriaTop;
    var categoriaTopTotal = 0;
    if (ocorrencias.isNotEmpty) {
      final contagem = <String, int>{};
      for (final o in ocorrencias) {
        if (o.tipoLixo.trim().isEmpty) continue;
        contagem[o.tipoLixo] = (contagem[o.tipoLixo] ?? 0) + 1;
      }
      if (contagem.isNotEmpty) {
        final maisReportada =
            contagem.entries.reduce((a, b) => a.value >= b.value ? a : b);
        categoriaTop = maisReportada.key;
        categoriaTopTotal = maisReportada.value;
      }
    }

    // Total de curtidas recebidas somando os likes de todas as denúncias.
    final curtidas = ocorrencias.fold<int>(0, (soma, o) => soma + o.likes);

    // Impacto oficial: verificadas pela autoridade e resolvidas oficialmente.
    final verificadas = ocorrencias.where((o) => o.verificada).length;
    final resolvidasOficial = ocorrencias
        .where(
            (o) => o.verificada && o.statusOficial == StatusOficial.resolvida)
        .length;

    return _Stats(
      total: base,
      curtidas: curtidas,
      categoriaTop: categoriaTop,
      categoriaTopTotal: categoriaTopTotal,
      verificadas: verificadas,
      resolvidasOficial: resolvidasOficial,
    );
  }
}

class _Stats {
  final int total;
  final int curtidas;
  final String? categoriaTop;
  final int categoriaTopTotal;
  final int verificadas;
  final int resolvidasOficial;

  _Stats({
    required this.total,
    required this.curtidas,
    required this.categoriaTop,
    required this.categoriaTopTotal,
    required this.verificadas,
    required this.resolvidasOficial,
  });
}

/// Badge de uma conquista no perfil. Desbloqueada = ícone colorido + título
/// forte; pendente = esmaecida, mostrando o progresso (ex.: "3/5").
/// Grade de conquistas com colunas de mesma largura e linhas de mesma
/// altura. Antes era um Wrap de badges com 96 dp fixos: em telas comuns
/// cabiam 2 por linha com um vão à direita, e os badges tinham alturas
/// diferentes (título de 1 ou 2 linhas, progresso só nos bloqueados).
class _GradeConquistas extends StatelessWidget {
  const _GradeConquistas({required this.conquistas});

  final List<Conquista> conquistas;

  static const _espaco = 10.0;
  static const _larguraMinima = 88.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colunas =
            ((constraints.maxWidth + _espaco) / (_larguraMinima + _espaco))
                .floor()
                .clamp(2, 4);
        final linhas = <Widget>[];
        for (var i = 0; i < conquistas.length; i += colunas) {
          final fim = (i + colunas).clamp(0, conquistas.length);
          final daLinha = conquistas.sublist(i, fim);
          if (linhas.isNotEmpty) linhas.add(const SizedBox(height: _espaco));
          linhas.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < colunas; j++) ...[
                    if (j > 0) const SizedBox(width: _espaco),
                    Expanded(
                      child: j < daLinha.length
                          ? _ConquistaBadge(conquista: daLinha[j])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: linhas);
      },
    );
  }
}

class _ConquistaBadge extends StatelessWidget {
  final Conquista conquista;

  const _ConquistaBadge({required this.conquista});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = conquista;
    final ativa = c.desbloqueada;
    final cor = ativa ? c.cor : pal.hint;

    return Tooltip(
      message: '${c.descricao}${ativa ? '' : ' · ${c.progresso}/${c.meta}'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ativa ? c.cor.withValues(alpha: 0.12) : pal.surfaceAlt,
                shape: BoxShape.circle,
                border: ativa ? Border.all(color: c.cor, width: 1.5) : null,
              ),
              child: Icon(c.icone, size: 22, color: cor),
            ),
            const SizedBox(height: 6),
            Text(
              c.titulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: ativa ? pal.ink : pal.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerfilContourPainter extends CustomPainter {
  const _PerfilContourPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 7; i++) {
      final y = -48.0 + i * 31;
      final path = Path()
        ..moveTo(-24, y)
        ..cubicTo(size.width * 0.18, y + 62, size.width * 0.27, y - 54,
            size.width * 0.48, y + 2)
        ..cubicTo(size.width * 0.68, y + 54, size.width * 0.80, y - 58,
            size.width + 24, y + 8);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerfilContourPainter oldDelegate) =>
      oldDelegate.color != color;
}
