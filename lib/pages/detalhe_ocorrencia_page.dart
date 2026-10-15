import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../data/repositories/comentario_repository.dart';
import '../data/repositories/ocorrencia_repository.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/comentario_model.dart';
import '../models/ocorrencia_model.dart';
import '../models/occurrence_types.dart';
import '../pages/mapPage/map_page.dart';
import '../pages/mapPage/map_style.dart';
import '../services/auth_service.dart';
import '../services/moderacao_service.dart';
import '../services/notificacao_service.dart';
import '../services/usuario_service.dart';
import '../theme/app_theme.dart';
import '../utils/autor_ocorrencia.dart';
import '../utils/cloudinary_image.dart';
import '../utils/compartilhamento.dart';
import '../utils/imagem_cacheada.dart';
import '../utils/mensagem_erro.dart';
import '../utils/reacao_ocorrencia.dart';
import '../utils/tempo_relativo.dart';
import '../widgets/occurrence_comments_sheet.dart';
import '../widgets/report_content_sheet.dart';

// ─────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────

class _Cores {
  // Acentos — iguais nos dois temas. Os neutros (fundo/superfície/borda/
  // texto/dica) vêm de `context.pal`.
  static const orange = Color(0xFFFF8A1F);
  static const green = AppColors.success;
  static const red = AppColors.danger;
  static const blue = Color(0xFF3B82F6);
}

// ─────────────────────────────────────────
//  DETALHE OCORRÊNCIA PAGE
// ─────────────────────────────────────────

class DetalheOcorrenciaPage extends ConsumerStatefulWidget {
  final OcorrenciaModel occurrence;

  const DetalheOcorrenciaPage({super.key, required this.occurrence});

  @override
  ConsumerState<DetalheOcorrenciaPage> createState() =>
      _DetalheOcorrenciaPageState();
}

class _DetalheOcorrenciaPageState extends ConsumerState<DetalheOcorrenciaPage> {
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _notificacaoService = NotificacaoService();

  OcorrenciaRepository get _service => ref.read(ocorrenciaRepositoryProvider);
  // Criada uma vez: uma stream nova a cada build fazia o StreamBuilder voltar
  // a "waiting" (spinner) e reabrir o listener a cada rebuild.
  late final Stream<List<ComentarioModel>> _comentariosStream =
      _comentarioRepository.listarComentarios(widget.occurrence.id);
  late final Stream<List<({String status, String? por, DateTime? data})>>
      _historicoStream = _service.listarHistorico(widget.occurrence.id);

  ComentarioRepository get _comentarioRepository =>
      ref.read(comentarioRepositoryProvider);

  late int _likes;
  late bool _userLiked;
  String? _authorName;
  String? _authorPhoto;

  // Verificação oficial
  late bool _verificada;
  String? _verificadaPorNome;
  DateTime? _verificadaEm;
  StatusOficial? _statusOficial;
  bool _processandoVerif = false;

  @override
  void initState() {
    super.initState();
    final o = widget.occurrence;
    _likes = o.likes;
    _userLiked = o.userLiked;
    _verificada = o.verificada;
    _verificadaPorNome = o.verificadaPorNome;
    _verificadaEm = o.verificadaEm;
    _statusOficial = o.statusOficial;
    _fetchAuthorData();
  }

  Future<void> _toggleVerificacao() async {
    if (_processandoVerif) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final novo = !_verificada;

    setState(() => _processandoVerif = true);

    try {
      // O repositório usa o nome do perfil da autoridade (exigido pelas
      // regras) e devolve o que foi gravado no selo.
      final nome = await _service.definirVerificacao(
        widget.occurrence.id,
        verificar: novo,
      );
      if (!mounted) return;
      setState(() {
        _verificada = novo;
        _verificadaPorNome = novo ? nome : _verificadaPorNome;
        _verificadaEm = novo ? DateTime.now() : _verificadaEm;
        _processandoVerif = false;
      });
      // Só notifica ao confirmar — reverter é correção interna, não avanço.
      if (novo) _notificarStatusOficial('status_confirmada', nome);
    } catch (_) {
      if (!mounted) return;
      setState(() => _processandoVerif = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível alterar a verificação. Tente de novo.',
          ),
        ),
      );
    }
  }

  /// Avança o ciclo oficial (em análise / não confirmada / encaminhada /
  /// resolvida) e notifica o cidadão.
  Future<void> _handleStatusOficial(StatusOficial novoStatus) async {
    if (_processandoVerif) return;
    setState(() => _processandoVerif = true);

    try {
      await _service.definirStatusOficial(widget.occurrence.id, novoStatus);
      final uid = _authService.currentUser?.uid;
      final perfil =
          uid == null ? null : await _usuarioService.carregarPerfil(uid);
      if (!mounted) return;
      setState(() {
        _statusOficial = novoStatus;
        _processandoVerif = false;
      });
      _notificarStatusOficial(
        'status_${novoStatus.valor}',
        perfil?.nome ?? 'Autoridade',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _processandoVerif = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o status.')),
      );
    }
  }

  /// Desfaz o último passo do ciclo oficial. Correção interna: registra o
  /// evento "revertida" e não notifica o cidadão.
  Future<void> _reverterStatusOficial() async {
    final atual = _statusOficial;
    if (_processandoVerif || atual == null) return;
    setState(() => _processandoVerif = true);
    try {
      await _service.reverterStatusOficial(widget.occurrence.id, atual: atual);
      if (!mounted) return;
      setState(() {
        _statusOficial =
            atual == StatusOficial.resolvida ? StatusOficial.encaminhada : null;
        _processandoVerif = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _processandoVerif = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o status.')),
      );
    }
  }

  // Avisa o cidadão (no próprio inbox dele) que o status oficial avançou.
  // Não revela identidade de ninguém — é uma notificação privada ao dono.
  void _notificarStatusOficial(String tipo, String nomeAutoridade) {
    final dono = widget.occurrence.usuarioId;
    if (dono == null) return;
    _notificacaoService.notificar(
      donoId: dono,
      tipo: tipo,
      deUsuarioNome: nomeAutoridade,
      ocorrenciaId: widget.occurrence.id,
      ocorrenciaTitulo: widget.occurrence.titulo,
    );
  }

  Future<void> _fetchAuthorData() async {
    final o = widget.occurrence;

    // Proteção do denunciante: nunca resolve nome/foto reais, nem para
    // autoridade — a identidade não é exibida em nenhuma tela.
    if (o.anonima) {
      setState(() {
        _authorName = 'Denunciante anônimo';
        _authorPhoto = null;
      });
      return;
    }

    if (o.usuarioId == null) {
      final hasSavedName =
          o.usuarioNome != null && o.usuarioNome!.trim().isNotEmpty;
      if (hasSavedName) setState(() => _authorName = o.usuarioNome);
      return;
    }

    final autor = await resolverAutorOcorrencia(
      usuarioId: o.usuarioId!,
      nomeSalvo: o.usuarioNome,
      fotoSalva: o.usuarioFotoUrl,
      usuarioService: _usuarioService,
      authService: _authService,
    );

    if (!mounted) return;
    setState(() {
      _authorName = autor.nome;
      _authorPhoto = autor.foto;
    });
  }

  String get _uid => _authService.currentUser?.uid ?? '';

  // Sincroniza os campos locais (usados pela UI desta tela) a partir do
  // OcorrenciaModel compartilhado, após reagirOcorrencia mutá-lo.
  void _sincronizarComOcorrencia() {
    final o = widget.occurrence;
    _likes = o.likes;
    _userLiked = o.userLiked;
  }

  Future<void> _handleLike() async {
    if (_uid.isEmpty) return;
    await reagirOcorrencia(
      context: context,
      ocorrencia: widget.occurrence,
      uid: _uid,
      isLike: true,
      ocorrenciaRepository: _service,
      notificacaoService: _notificacaoService,
      onMudou: () => setState(_sincronizarComOcorrencia),
    );
  }

  // Mesmo sheet usado no feed (OccurrenceCommentsSheet) — evita reimplementar
  // adicionar/curtir/excluir/responder comentário aqui também.
  void _abrirComentarios() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OccurrenceCommentsSheet(
        occurrence: widget.occurrence,
        comentarioRepository: _comentarioRepository,
        authService: _authService,
        usuarioService: _usuarioService,
        notificacaoService: _notificacaoService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final o = widget.occurrence;
    final type = OccurrenceTypeParser.fromString(o.tipoLixo);
    final autoridade = ref.watch(isAutoridadeProvider).value == true;
    final estagio = EstagioOficialInfo.calcular(_verificada, _statusOficial);
    final etapa = switch (estagio) {
      EstagioOficial.pendente => 1,
      EstagioOficial.emAnalise || EstagioOficial.naoConfirmada => 2,
      EstagioOficial.confirmada => 3,
      EstagioOficial.encaminhada => 4,
      EstagioOficial.resolvida => 5,
    };

    return Scaffold(
      backgroundColor: pal.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ImageArea(occurrence: o, type: type),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: StreamBuilder<List<ComentarioModel>>(
                        stream: _comentariosStream,
                        builder: (context, snapshot) {
                          final comentarios = (snapshot.data ?? const [])
                              .where((comentario) => !comentario.oculto)
                              .toList();
                          final total = snapshot.hasData
                              ? comentarios.length
                              : o.comments;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _DetailTag(
                                    icon: estagio.icon,
                                    label: estagio.label,
                                    color: estagio.colorFor(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                                  _DetailTag(
                                      icon: type.icon,
                                      label: type.label,
                                      color: type.color),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                o.titulo.trim().isEmpty
                                    ? 'Sem título'
                                    : o.titulo.trim(),
                                style: TextStyle(
                                    color: pal.ink,
                                    fontSize: 20,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              _AuthorDetails(
                                name: _authorName ??
                                    (o.anonima
                                        ? 'Denunciante anônimo'
                                        : 'Usuário'),
                                photoUrl: _authorPhoto,
                                publishedAt: o.dataCriacao,
                                location: o.bairro?.trim().isNotEmpty == true
                                    ? o.bairro!.trim()
                                    : 'João Pessoa, PB',
                              ),
                              const SizedBox(height: 12),
                              Text(
                                o.descricao.trim().isEmpty
                                    ? 'Sem descrição.'
                                    : o.descricao.trim(),
                                style: TextStyle(
                                    color: pal.muted,
                                    fontSize: 14,
                                    height: 1.5),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DetailAction(
                                      icon: _userLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      label: 'Curtir · $_likes',
                                      active: _userLiked,
                                      onTap: _handleLike,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _DetailAction(
                                      icon: Icons.chat_bubble_outline,
                                      label: 'Comentar · $total',
                                      onTap: _abrirComentarios,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Builder(
                                    builder: (anchor) => _DetailIconAction(
                                      icon: Icons.share_outlined,
                                      tooltip: 'Compartilhar denúncia',
                                      onTap: () => compartilharOcorrencia(o,
                                          origem: origemDoWidget(anchor)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _DetailActionDivider(color: pal.border),
                              if (autoridade) ...[
                                const SizedBox(height: 16),
                                _PainelAutoridade(
                                  verificada: _verificada,
                                  statusOficial: _statusOficial,
                                  processando: _processandoVerif,
                                  onConfirmar: _toggleVerificacao,
                                  onEmAnalise: () => _handleStatusOficial(
                                      StatusOficial.emAnalise),
                                  onNaoConfirmada: () => _handleStatusOficial(
                                      StatusOficial.naoConfirmada),
                                  onEncaminhar: () => _handleStatusOficial(
                                      StatusOficial.encaminhada),
                                  onResolver: () => _handleStatusOficial(
                                      StatusOficial.resolvida),
                                  onReverter: _reverterStatusOficial,
                                ),
                              ],
                              const SizedBox(height: 24),
                              _DetailSectionTitle(
                                  title: 'Andamento',
                                  trailing: 'ETAPA $etapa DE 5'),
                              const SizedBox(height: 10),
                              _StatusTimeline(
                                occurrence: o,
                                verificada: _verificada,
                                verificadaPorNome: _verificadaPorNome,
                                verificadaEm: _verificadaEm,
                                statusOficial: _statusOficial,
                                historico: _historicoStream,
                              ),
                              const SizedBox(height: 24),
                              const _DetailSectionTitle(title: 'Localização'),
                              const SizedBox(height: 10),
                              _LocationSection(
                                  occurrence: o,
                                  onOpenDirections: _abrirMapaDaRegiao),
                              const SizedBox(height: 24),
                              _DetailSectionTitle(
                                  title: 'Comentários',
                                  trailing: '$total',
                                  onTap: _abrirComentarios),
                              const SizedBox(height: 10),
                              _CommentPreviews(
                                  comments: comentarios,
                                  onOpen: _abrirComentarios),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _abrirComentarios,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Ver todos os $total comentários'),
                                      const Icon(Icons.chevron_right, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const _DetailSectionTitle(
                                title: 'Ações relacionadas',
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: pal.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: pal.border),
                                ),
                                child: Column(
                                  children: [
                                    Builder(
                                      builder: (anchor) => _RelatedActionTile(
                                        icon: Icons.share_outlined,
                                        title: 'Compartilhar denúncia',
                                        subtitle:
                                            'Enviar link para vizinhos e grupos',
                                        onTap: () => compartilharOcorrencia(
                                          o,
                                          origem: origemDoWidget(anchor),
                                        ),
                                      ),
                                    ),
                                    _RelatedActionTile(
                                      icon: Icons.map_outlined,
                                      title: 'Ver denúncias próximas',
                                      subtitle:
                                          'Explore os registros desta região',
                                      onTap: _abrirMapaDaRegiao,
                                    ),
                                    _RelatedActionTile(
                                      icon: Icons.visibility_off_outlined,
                                      title: 'Denunciar conteúdo',
                                      subtitle: 'Informar uso indevido',
                                      showBottomBorder: false,
                                      onTap: _denunciarOcorrencia,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildCommentComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final pal = context.pal;
    return Container(
      color: pal.surface,
      child: Row(
        children: [
          IconButton(
              tooltip: 'Voltar',
              icon: Icon(Icons.arrow_back, color: pal.ink),
              onPressed: () => Navigator.pop(context)),
          Expanded(
            child: Text(
              'Denúncia',
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: pal.ink),
            ),
          ),
          Builder(
            builder: (anchor) => IconButton(
              tooltip: 'Compartilhar',
              icon: Icon(Icons.share_outlined, color: pal.ink),
              onPressed: () => compartilharOcorrencia(widget.occurrence,
                  origem: origemDoWidget(anchor)),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            icon: Icon(Icons.more_horiz, color: pal.ink),
            onSelected: (value) {
              if (value == 'report') _denunciarOcorrencia();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Denunciar conteúdo')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    final pal = context.pal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
          color: pal.surface,
          border: Border(top: BorderSide(color: pal.border))),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _abrirComentarios,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 42,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: pal.surfaceAlt,
                    borderRadius: BorderRadius.circular(24)),
                child: Text('Escreva um comentário…',
                    style: TextStyle(color: pal.hint, fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: isDark ? pal.primary : AppColors.successStrong,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Comentar',
              onPressed: _abrirComentarios,
              icon: const Icon(Icons.send_rounded, size: 18),
              color: isDark ? AppColors.ink : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _denunciarOcorrencia() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final result =
        await showReportContentSheet(context, title: 'Denunciar publicação');
    if (result == null || !mounted) return;
    try {
      await ModeracaoService.instance.denunciarOcorrencia(
        ocorrenciaId: widget.occurrence.id,
        denuncianteId: uid,
        motivo: result.motivo,
        detalhe: result.detalhe,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denúncia enviada para moderação.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro(error, acao: 'enviar a denúncia'))),
      );
    }
  }

  void _abrirMapaDaRegiao() {
    final o = widget.occurrence;
    if (!_coordenadasValidas(o.latitude, o.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Esta denúncia não tem coordenadas válidas.')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapPage(focoInicial: LatLng(o.latitude, o.longitude)),
      ),
    );
  }
}
// ─────────────────────────────────────────

class _ImageArea extends StatefulWidget {
  final OcorrenciaModel occurrence;
  final OccurrenceType type;

  const _ImageArea({required this.occurrence, required this.type});

  @override
  State<_ImageArea> createState() => _ImageAreaState();
}

class _ImageAreaState extends State<_ImageArea> {
  final _pageCtrl = PageController();
  int _current = 0;

  List<String> get _images {
    if (widget.occurrence.imagensUrls.isNotEmpty) {
      return widget.occurrence.imagensUrls;
    }
    if (widget.occurrence.imagemUrl != null) {
      return [widget.occurrence.imagemUrl!];
    }
    return [];
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final videoUrl = widget.occurrence.videoUrl;
    final hasVideo = videoUrl?.trim().isNotEmpty == true;
    final mediaCount = images.length + (hasVideo ? 1 : 0);
    if (mediaCount == 0) {
      return _Placeholder(type: widget.type);
    }
    final pal = context.pal;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final larguraImg = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 240,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageCtrl,
                itemCount: mediaCount,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) {
                  if (hasVideo && i == images.length) {
                    return _VideoPlayerCard(
                      key: ValueKey('video-${widget.occurrence.id}'),
                      url: videoUrl!,
                      active: _current == i,
                    );
                  }
                  return Container(
                    width: double.infinity,
                    color: pal.surfaceAlt,
                    alignment: Alignment.center,
                    child: Image(
                      image: imagemCacheada(
                        cloudinaryOtimizada(
                          images[i],
                          larguraLogica: larguraImg,
                          devicePixelRatio: dpr,
                        ),
                        cacheWidth: cacheLarguraPx(larguraImg, dpr),
                      ),
                      fit: BoxFit.contain,
                      semanticLabel:
                          'Foto ${i + 1} da denúncia: ${widget.type.label}',
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          _Placeholder(type: widget.type),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ViewfinderCorners(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_current + 1}/$mediaCount',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
              if (_coordenadasValidas(
                widget.occurrence.latitude,
                widget.occurrence.longitude,
              ))
                Positioned(
                  left: 28,
                  bottom: 12,
                  child: Text(
                    _coordenadasFormatadas(
                      widget.occurrence.latitude,
                      widget.occurrence.longitude,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (mediaCount > 1)
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: mediaCount,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selecionada = index == _current;
                return GestureDetector(
                  onTap: () => _pageCtrl.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selecionada ? pal.primary : pal.border,
                        width: selecionada ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: index == images.length && hasVideo
                        ? _VideoThumbnail(url: videoUrl!)
                        : Image(
                            image: imagemCacheada(
                              cloudinaryOtimizada(
                                images[index],
                                larguraLogica: 60,
                                devicePixelRatio: dpr,
                              ),
                              cacheWidth: cacheLarguraPx(60, dpr),
                            ),
                            fit: BoxFit.cover,
                            semanticLabel: 'Abrir foto ${index + 1}',
                          ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ViewfinderCorners extends CustomPainter {
  final Color color;

  const _ViewfinderCorners({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const inset = 12.0;
    const length = 14.0;
    final path = Path()
      ..moveTo(inset, inset + length)
      ..lineTo(inset, inset)
      ..lineTo(inset + length, inset)
      ..moveTo(size.width - inset - length, inset)
      ..lineTo(size.width - inset, inset)
      ..lineTo(size.width - inset, inset + length)
      ..moveTo(inset, size.height - inset - length)
      ..lineTo(inset, size.height - inset)
      ..lineTo(inset + length, size.height - inset)
      ..moveTo(size.width - inset - length, size.height - inset)
      ..lineTo(size.width - inset, size.height - inset)
      ..lineTo(size.width - inset, size.height - inset - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCorners oldDelegate) =>
      oldDelegate.color != color;
}

class _Placeholder extends StatelessWidget {
  final OccurrenceType type;
  const _Placeholder({required this.type});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      height: 240,
      width: double.infinity,
      color: pal.surfaceAlt,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(type.icon, size: 48, color: pal.hint),
          const SizedBox(height: 8),
          Text('Sem imagem', style: TextStyle(color: pal.hint, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  VÍDEO DA DENÚNCIA
// ─────────────────────────────────────────

class _VideoThumbnail extends StatelessWidget {
  final String url;

  const _VideoThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final thumbnail = cloudinaryVideoThumbnail(url);
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (thumbnail != null)
          Image.network(
            thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: pal.surfaceAlt),
          )
        else
          ColoredBox(color: pal.surfaceAlt),
        Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }
}

class _VideoPlayerCard extends StatefulWidget {
  final String url;
  final bool active;

  const _VideoPlayerCard({super.key, required this.url, required this.active});

  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  // Só criado quando a pessoa toca em play. Antes o initialize() rodava no
  // initState com a URL original (até 50 MB): cada visita ao detalhe baixava
  // o vídeo e consumia banda do Cloudinary, mesmo sem ninguém assistir.
  VideoPlayerController? _controller;
  bool _carregando = false;
  bool _erro = false;

  @override
  void didUpdateWidget(covariant _VideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    if (_carregando || !widget.active) return;
    setState(() => _carregando = true);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(cloudinaryVideoOtimizado(widget.url)),
    );
    try {
      await controller.initialize();
      if (!mounted || !widget.active) {
        await controller.dispose();
        if (mounted) setState(() => _carregando = false);
        return;
      }
      await controller.play();
      setState(() {
        _controller = controller;
        _carregando = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = true;
        });
      }
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) {
      _iniciar();
      return;
    }
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  Widget _botaoPlay({bool carregando = false}) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: carregando
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow, color: Colors.white, size: 30),
      );

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    if (_erro) {
      return Container(
        height: 240,
        width: double.infinity,
        color: pal.surfaceAlt,
        alignment: Alignment.center,
        child: Text(
          'Não foi possível carregar o vídeo.',
          style: TextStyle(color: pal.hint, fontSize: 12),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      // Miniatura (primeiro quadro) até o play: uma imagem pequena em vez
      // do vídeo inteiro.
      final thumb = cloudinaryVideoThumbnail(widget.url);
      return GestureDetector(
        onTap: _togglePlay,
        child: Container(
          height: 240,
          width: double.infinity,
          color: pal.surfaceAlt,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              if (thumb != null)
                Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (context, erro, stack) =>
                      const SizedBox.shrink(),
                ),
              Center(child: _botaoPlay(carregando: _carregando)),
            ],
          ),
        ),
      );
    }

    final videoSize = controller.value.size;
    return GestureDetector(
      onTap: _togglePlay,
      child: SizedBox(
        height: 240,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            ColoredBox(
              color: Colors.black,
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: videoSize.width,
                    height: videoSize.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: controller.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: _botaoPlay(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailTag(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AuthorDetails extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final DateTime? publishedAt;
  final String location;

  const _AuthorDetails({
    required this.name,
    required this.photoUrl,
    required this.publishedAt,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final published = publishedAt == null
        ? 'Publicado agora'
        : 'Publicado em ${DateFormat('dd/MM').format(publishedAt!)} às ${DateFormat('HH:mm').format(publishedAt!)}';
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: pal.primary.withValues(
            alpha:
                Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.12,
          ),
          backgroundImage: photoUrl == null ? null : imagemCacheada(photoUrl!),
          child: photoUrl == null
              ? Text(name.isEmpty ? 'U' : name.characters.first.toUpperCase(),
                  style: TextStyle(
                      color: pal.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: pal.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$published · $location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pal.hint, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  const _DetailSectionTitle({required this.title, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final row = Row(
      children: [
        Expanded(
            child: Text(title,
                style: TextStyle(
                    color: pal.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700))),
        if (trailing != null)
          Text(trailing!,
              style: TextStyle(
                  color: pal.muted, fontSize: 10, fontWeight: FontWeight.w700)),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: pal.hint, size: 19),
        ],
      ],
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

class _DetailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DetailAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final color = active
        ? (Theme.of(context).brightness == Brightness.dark
            ? pal.primary
            : AppColors.successStrong)
        : pal.muted;
    return Material(
      color: active ? color.withValues(alpha: 0.1) : pal.surfaceAlt,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: active ? color : pal.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailIconAction extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _DetailIconAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final content = Material(
      color: pal.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 17,
            color: pal.muted,
          ),
        ),
      ),
    );
    return tooltip == null
        ? content
        : Tooltip(message: tooltip!, child: content);
  }
}

class _DetailActionDivider extends StatelessWidget {
  final Color color;

  const _DetailActionDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      width: double.infinity,
      child: CustomPaint(painter: _DetailActionDividerPainter(color)),
    );
  }
}

class _DetailActionDividerPainter extends CustomPainter {
  final Color color;

  const _DetailActionDividerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final baselineY = size.height / 2;
    canvas.drawLine(Offset(0, baselineY), Offset(size.width, baselineY), paint);

    final motifPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    var pointsUp = true;
    for (var x = 16.0; x < size.width - 8; x += 32) {
      final endY = baselineY + (pointsUp ? -4 : 4);
      canvas.drawLine(Offset(x, baselineY), Offset(x + 7, endY), motifPaint);
      pointsUp = !pointsUp;
    }
  }

  @override
  bool shouldRepaint(covariant _DetailActionDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LocationSection extends StatelessWidget {
  final OcorrenciaModel occurrence;
  final VoidCallback onOpenDirections;

  const _LocationSection(
      {required this.occurrence, required this.onOpenDirections});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final o = occurrence;
    final valid = _coordenadasValidas(o.latitude, o.longitude);
    final bairro = o.bairro?.trim() ?? '';
    final cidade =
        bairro.isEmpty ? 'João Pessoa, PB' : '$bairro · João Pessoa, PB';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 138,
            child: valid
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                        target: LatLng(o.latitude, o.longitude), zoom: 15),
                    markers: {
                      Marker(
                        markerId: MarkerId('detalhe-${o.id}'),
                        position: LatLng(o.latitude, o.longitude),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure),
                      ),
                    },
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                    style: Theme.of(context).brightness == Brightness.dark
                        ? kEstiloMapaEscuro
                        : null,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  )
                : Container(
                    color: pal.surfaceAlt,
                    alignment: Alignment.center,
                    child: Icon(Icons.map_outlined, color: pal.hint, size: 32),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.location_on_outlined,
                  color: pal.primary, size: 18),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      o.localizacao.trim().isEmpty
                          ? 'Endereço não informado'
                          : o.localizacao.trim(),
                      style: TextStyle(
                          color: pal.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(cidade,
                      style: TextStyle(color: pal.muted, fontSize: 11)),
                  if (valid) ...[
                    const SizedBox(height: 3),
                    Text(_coordenadasFormatadas(o.latitude, o.longitude),
                        style: TextStyle(
                            color: pal.hint,
                            fontSize: 10,
                            fontFamily: 'monospace')),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: valid ? onOpenDirections : null,
          icon: const Icon(Icons.map_outlined, size: 17),
          label: const Text('Abrir no mapa'),
          style: OutlinedButton.styleFrom(
            foregroundColor: pal.primary,
            side: BorderSide(color: pal.primary),
            minimumSize: const Size.fromHeight(40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ],
    );
  }
}

class _CommentPreviews extends StatelessWidget {
  final List<ComentarioModel> comments;
  final VoidCallback onOpen;

  const _CommentPreviews({required this.comments, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final raiz = comments.where((comment) => comment.parentId == null).toList();
    final recentes = raiz.reversed.take(2).toList();
    if (recentes.isEmpty) {
      return Text(
          'Ainda não há comentários. Seja a primeira pessoa a comentar.',
          style: TextStyle(color: pal.muted, fontSize: 13));
    }
    return Column(
      children: [
        for (final comment in recentes)
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: pal.primary.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.14
                          : 0.12,
                    ),
                    backgroundImage: comment.userPhotoUrl == null
                        ? null
                        : imagemCacheada(comment.userPhotoUrl!),
                    child: comment.userPhotoUrl == null
                        ? Text(
                            comment.userName.isEmpty
                                ? 'U'
                                : comment.userName.characters.first
                                    .toUpperCase(),
                            style: TextStyle(
                                color: pal.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700))
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                                child: Text(comment.userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: pal.ink,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            const SizedBox(width: 6),
                            Text(tempoRelativo(comment.dataCriacao),
                                style:
                                    TextStyle(color: pal.hint, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(comment.texto,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: pal.muted, fontSize: 12, height: 1.35)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.favorite_border,
                                size: 12, color: pal.hint),
                            const SizedBox(width: 4),
                            Text('${comment.likes}',
                                style:
                                    TextStyle(color: pal.hint, fontSize: 10)),
                            const SizedBox(width: 12),
                            Text('Responder',
                                style: TextStyle(
                                    color: pal.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RelatedActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showBottomBorder;

  const _RelatedActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showBottomBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
            border: showBottomBorder
                ? Border(bottom: BorderSide(color: pal.border))
                : null),
        child: Row(
          children: [
            Icon(icon, color: pal.muted, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: pal.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: pal.hint, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: pal.hint, size: 19),
          ],
        ),
      ),
    );
  }
}

bool _coordenadasValidas(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180 &&
    latitude != 0 &&
    longitude != 0;

String _coordenadasFormatadas(double latitude, double longitude) =>
    '${_coordenadaDms(latitude, latitude: true)}  ·  ${_coordenadaDms(longitude, latitude: false)}';

String _coordenadaDms(double value, {required bool latitude}) {
  final absolute = value.abs();
  final degrees = absolute.floor();
  final minutesCompletos = (absolute - degrees) * 60;
  final minutes = minutesCompletos.floor();
  final seconds = ((minutesCompletos - minutes) * 60).round();
  final hemisphere =
      latitude ? (value >= 0 ? 'N' : 'S') : (value >= 0 ? 'L' : 'O');
  return '$degrees°${minutes.toString().padLeft(2, '0')}′${seconds.toString().padLeft(2, '0')}″$hemisphere';
}

// ─────────────────────────────────────────
//  TYPE BADGE  (sobre a imagem)
// ─────────────────────────────────────────

class _StatusOficialBanner extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusOficialBanner({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  PAINEL DE AUTORIDADE
//  Fluxo: Pendente → Em análise → Confirmada / Não confirmada
// ─────────────────────────────────────────

class _PainelAutoridade extends StatelessWidget {
  final bool verificada;
  final StatusOficial? statusOficial;
  final bool processando;
  final VoidCallback onConfirmar;
  final VoidCallback onEmAnalise;
  final VoidCallback onNaoConfirmada;
  final VoidCallback onEncaminhar;
  final VoidCallback onResolver;
  final VoidCallback onReverter;

  const _PainelAutoridade({
    required this.verificada,
    required this.statusOficial,
    required this.processando,
    required this.onConfirmar,
    required this.onEmAnalise,
    required this.onNaoConfirmada,
    required this.onEncaminhar,
    required this.onResolver,
    required this.onReverter,
  });

  @override
  Widget build(BuildContext context) {
    if (processando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: _Cores.green),
          ),
        ),
      );
    }

    // ── Estados pós-confirmação (verificada == true) ──
    if (verificada) {
      // Estado: Resolvida
      if (statusOficial == StatusOficial.resolvida) {
        return _botaoTexto(
          label: 'Reverter para encaminhada',
          onTap: onReverter,
        );
      }

      // Estado: Encaminhada
      if (statusOficial == StatusOficial.encaminhada) {
        return Column(
          children: [
            _botao(
              label: 'Marcar como resolvida',
              icon: Icons.check_circle_outline,
              color: _Cores.green,
              onTap: onResolver,
            ),
            const SizedBox(height: 8),
            _botaoTexto(label: 'Reverter para confirmada', onTap: onReverter),
          ],
        );
      }

      // Estado: Confirmada
      return Column(
        children: [
          _botao(
            label: 'Encaminhar ao órgão',
            icon: Icons.send,
            color: _Cores.blue,
            onTap: onEncaminhar,
          ),
          const SizedBox(height: 8),
          _botaoTexto(label: 'Remover verificação', onTap: onConfirmar),
        ],
      );
    }

    // ── Estados pré-confirmação (verificada == false) ──

    // Estado: Em análise
    if (statusOficial == StatusOficial.emAnalise) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _botao(
                  label: 'Confirmar',
                  icon: Icons.verified_outlined,
                  color: _Cores.green,
                  onTap: onConfirmar,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _botao(
                  label: 'Não confirmada',
                  icon: Icons.cancel_outlined,
                  color: _Cores.red,
                  onTap: onNaoConfirmada,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _botaoTexto(label: 'Reverter para pendente', onTap: onReverter),
        ],
      );
    }

    // Estado: Não confirmada
    if (statusOficial == StatusOficial.naoConfirmada) {
      return _botao(
        label: 'Reverter para pendente',
        icon: Icons.undo,
        color: AppColors.hint,
        onTap: onReverter,
      );
    }

    // Estado: Pendente (padrão)
    return Row(
      children: [
        Expanded(
          child: _botao(
            label: 'Em análise',
            icon: Icons.search,
            color: _Cores.orange,
            onTap: onEmAnalise,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _botao(
            label: 'Confirmar',
            icon: Icons.verified_outlined,
            color: _Cores.green,
            onTap: onConfirmar,
          ),
        ),
      ],
    );
  }

  Widget _botao({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoTexto({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.hint,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STATUS TIMELINE (linha do tempo)
// ─────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final OcorrenciaModel occurrence;
  final bool verificada;
  final String? verificadaPorNome;
  final DateTime? verificadaEm;
  final StatusOficial? statusOficial;
  final Stream<List<({String status, String? por, DateTime? data})>> historico;
  const _StatusTimeline({
    required this.occurrence,
    required this.verificada,
    required this.verificadaPorNome,
    required this.verificadaEm,
    required this.statusOficial,
    required this.historico,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return StreamBuilder<List<({String status, String? por, DateTime? data})>>(
      stream: historico,
      builder: (context, snap) {
        final eventos = snap.data ??
            const <({String status, String? por, DateTime? data})>[];
        DateTime? dataEvento(String status) {
          for (final evento in eventos.reversed) {
            if (evento.status == status) return evento.data;
          }
          return null;
        }

        final stage = EstagioOficialInfo.calcular(verificada, statusOficial);
        final stageColor = stage.colorFor(Theme.of(context).brightness);
        final pendingColor = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFF2B65D)
            : AppColors.primary;
        final etapaAtual = switch (stage) {
          EstagioOficial.pendente => 0,
          EstagioOficial.emAnalise || EstagioOficial.naoConfirmada => 1,
          EstagioOficial.confirmada => 2,
          EstagioOficial.encaminhada => 3,
          EstagioOficial.resolvida => 4,
        };
        final steps = <_TimelineStep>[
          _TimelineStep(
            title: 'Pendente',
            description: 'Denúncia publicada',
            icon: Icons.circle,
            date: occurrence.dataCriacao,
          ),
          _TimelineStep(
            title: 'Em análise',
            description: 'O órgão responsável está avaliando esta denúncia.',
            icon: Icons.search,
            date: dataEvento('em_analise'),
          ),
          _TimelineStep(
            title: 'Verificada',
            description: 'Confirmação do problema no local.',
            icon: Icons.verified_outlined,
            date: verificadaEm ??
                occurrence.verificadaEm ??
                dataEvento('verificada'),
          ),
          _TimelineStep(
            title: 'Encaminhada',
            description: 'Enviada ao órgão responsável.',
            icon: Icons.send_outlined,
            date: occurrence.encaminhadaEm ?? dataEvento('encaminhada'),
          ),
          _TimelineStep(
            title: 'Resolvida',
            description: 'Problema tratado e encerrado.',
            icon: Icons.check_circle_outline,
            date: occurrence.resolvidaEm ?? dataEvento('resolvida'),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: pal.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pal.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 22,
                            child: Column(
                              children: [
                                Container(
                                  width: 13,
                                  height: 13,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i < etapaAtual
                                        ? (i == 0 ? pendingColor : pal.primary)
                                        : i == etapaAtual
                                            ? stageColor
                                            : pal.surface,
                                    border: i > etapaAtual
                                        ? Border.all(
                                            color: pal.border, width: 2)
                                        : null,
                                  ),
                                  child: i == etapaAtual
                                      ? Icon(steps[i].icon,
                                          size: 8, color: Colors.white)
                                      : null,
                                ),
                                if (i != steps.length - 1)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      color: i < etapaAtual
                                          ? (i == 0
                                              ? pendingColor
                                              : pal.primary)
                                          : pal.border,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  bottom: i == steps.length - 1 ? 0 : 13),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    steps[i].title,
                                    style: TextStyle(
                                      color: i == etapaAtual
                                          ? stageColor
                                          : i < etapaAtual
                                              ? pal.ink
                                              : pal.muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    i <= etapaAtual
                                        ? steps[i].description
                                        : 'Aguardando etapa anterior.',
                                    style: TextStyle(
                                        color: pal.muted,
                                        fontSize: 11,
                                        height: 1.35),
                                  ),
                                  if (i <= etapaAtual && steps[i].date != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        DateFormat('dd/MM · HH:mm')
                                            .format(steps[i].date!),
                                        style: TextStyle(
                                            color: pal.hint,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  if (i == 2 &&
                                      i <= etapaAtual &&
                                      verificadaPorNome?.trim().isNotEmpty ==
                                          true)
                                    Text(
                                      'por ${verificadaPorNome!.trim()}',
                                      style: TextStyle(
                                          color: pal.hint, fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (stage == EstagioOficial.naoConfirmada) ...[
              const SizedBox(height: 8),
              const _StatusOficialBanner(
                label: 'A autoridade não encontrou o problema no local.',
                icon: Icons.info_outline,
                color: _Cores.red,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TimelineStep {
  final String title;
  final String description;
  final IconData icon;
  final DateTime? date;

  const _TimelineStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.date,
  });
}
