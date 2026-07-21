import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../data/repositories/comentario_repository.dart';
import '../data/repositories/ocorrencia_repository.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/comentario_model.dart';
import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';
import '../services/usuario_service.dart';
import '../models/occurrence_types.dart';
import '../utils/autor_ocorrencia.dart';
import '../utils/cloudinary_image.dart';
import '../utils/imagem_cacheada.dart';
import '../utils/compartilhamento.dart';
import '../utils/navegacao_externa.dart';
import '../theme/app_theme.dart';
import '../utils/reacao_ocorrencia.dart';
import '../widgets/occurrence_comments_sheet.dart';

// ─────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────

class _C {
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
  ComentarioRepository get _comentarioRepository =>
      ref.read(comentarioRepositoryProvider);

  late int _likes;
  late int _dislikes;
  late bool _userLiked;
  late bool _userDisliked;
  String? _authorName;
  String? _authorPhoto;

  // Verificação oficial
  late bool _verificada;
  String? _verificadaPorNome;
  DateTime? _verificadaEm;
  String? _statusOficial;
  bool _processandoVerif = false;

  @override
  void initState() {
    super.initState();
    final o = widget.occurrence;
    _likes = o.likes;
    _dislikes = o.dislikes;
    _userLiked = o.userLiked;
    _userDisliked = o.userDisliked;
    _verificada = o.verificada;
    _verificadaPorNome = o.verificadaPorNome;
    _verificadaEm = o.verificadaEm;
    _statusOficial = o.statusOficial;
    _fetchAuthorData();
  }

  Future<void> _comoChegar() async {
    final o = widget.occurrence;
    final ok = await abrirRotaNoMapa(
      latitude: o.latitude,
      longitude: o.longitude,
      rotulo: o.titulo,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o app de mapas.')),
      );
    }
  }

  Future<void> _toggleVerificacao() async {
    if (_processandoVerif) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final novo = !_verificada;

    setState(() => _processandoVerif = true);

    // Nome exibido no selo: usa o nome do perfil da autoridade.
    String nome = 'Autoridade';
    if (novo) {
      final perfil = await _usuarioService.carregarPerfil(uid);
      nome = perfil?.nome.trim().isNotEmpty == true
          ? perfil!.nome.trim()
          : (_authService.currentUser?.displayName ?? 'Autoridade');
    }

    try {
      await _service.definirVerificacao(
        widget.occurrence.id,
        verificar: novo,
        nomeAutoridade: nome,
        autoridadeUid: uid,
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

  /// Define o status de triagem (em_analise / nao_confirmada / null = reverter).
  Future<void> _handleStatusOficial(String? novoStatus) async {
    if (_processandoVerif) return;
    setState(() => _processandoVerif = true);

    // Nome da autoridade só é necessário quando vamos notificar o cidadão
    // (não notificamos reversões — são correção interna, não avanço real).
    String? nomeAutoridade;
    if (novoStatus != null) {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final perfil = await _usuarioService.carregarPerfil(uid);
        nomeAutoridade = perfil?.nome.trim().isNotEmpty == true
            ? perfil!.nome.trim()
            : (_authService.currentUser?.displayName ?? 'Autoridade');
      }
    }

    try {
      await _service.definirStatusOficial(widget.occurrence.id, novoStatus);
      if (!mounted) return;
      setState(() {
        _statusOficial = novoStatus;
        _processandoVerif = false;
      });
      if (novoStatus != null && nomeAutoridade != null) {
        _notificarStatusOficial('status_$novoStatus', nomeAutoridade);
      }
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
    _dislikes = o.dislikes;
    _userLiked = o.userLiked;
    _userDisliked = o.userDisliked;
  }

  Future<void> _handleLike() async {
    if (_uid.isEmpty) return;
    final eu = _authService.currentUser;
    final nome = eu?.displayName ?? eu?.email?.split('@').first;
    await reagirOcorrencia(
      context: context,
      ocorrencia: widget.occurrence,
      uid: _uid,
      isLike: true,
      ocorrenciaRepository: _service,
      notificacaoService: _notificacaoService,
      nomeAutor: nome,
      onMudou: () => setState(_sincronizarComOcorrencia),
    );
  }

  Future<void> _handleDislike() async {
    if (_uid.isEmpty) return;
    final eu = _authService.currentUser;
    final nome = eu?.displayName ?? eu?.email?.split('@').first;
    await reagirOcorrencia(
      context: context,
      ocorrencia: widget.occurrence,
      uid: _uid,
      isLike: false,
      ocorrenciaRepository: _service,
      notificacaoService: _notificacaoService,
      nomeAutor: nome,
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
    final typeEnum = OccurrenceTypeParser.fromString(o.tipoLixo);
    final statusEnum = OccurrenceStatusParser.fromString(o.status);
    final isAutoridade = ref.watch(isAutoridadeProvider).value == true;

    return Scaffold(
      backgroundColor: pal.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header
            _buildHeader(o, statusEnum),

            // ── Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Área da imagem com badge de tipo
                    Stack(
                      children: [
                        _ImageArea(occurrence: o, type: typeEnum),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _TypeBadge(type: typeEnum),
                        ),
                      ],
                    ),

                    if (o.videoUrl != null) _VideoPlayerCard(url: o.videoUrl!),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_verificada && _statusOficial == 'resolvida') ...[
                            _StatusOficialBanner(
                              label:
                                  'Resolvida — tratada pelo órgão responsável',
                              icon: Icons.check_circle,
                              color: _C.green,
                            ),
                            const SizedBox(height: 10),
                          ] else if (_verificada &&
                              _statusOficial == 'encaminhada') ...[
                            _StatusOficialBanner(
                              label: 'Encaminhada ao órgão responsável',
                              icon: Icons.send,
                              color: _C.blue,
                            ),
                            const SizedBox(height: 10),
                          ] else if (_verificada) ...[
                            _VerificadaBanner(
                              nome: _verificadaPorNome,
                              data: _verificadaEm,
                            ),
                            const SizedBox(height: 10),
                          ] else if (_statusOficial == 'em_analise') ...[
                            _StatusOficialBanner(
                              label: 'Em análise pela autoridade',
                              icon: Icons.search,
                              color: _C.orange,
                            ),
                            const SizedBox(height: 10),
                          ] else if (_statusOficial == 'nao_confirmada') ...[
                            _StatusOficialBanner(
                              label:
                                  'Não confirmada — problema não encontrado no local',
                              icon: Icons.cancel_outlined,
                              color: _C.red,
                            ),
                            const SizedBox(height: 10),
                          ],
                          // Título
                          _FieldCard(
                            child: Text(
                              o.titulo.isEmpty ? 'Sem título' : o.titulo,
                              style: TextStyle(fontSize: 14, color: pal.ink),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Descrição
                          _FieldCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Descrição',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: pal.hint,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  o.descricao.isEmpty
                                      ? 'Sem descrição'
                                      : o.descricao,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: pal.ink,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botões de ação
                          Row(
                            children: [
                              _ReactionChip(
                                icon: _userLiked
                                    ? Icons.thumb_up_alt
                                    : Icons.thumb_up_alt_outlined,
                                count: _likes,
                                active: _userLiked,
                                activeColor: _C.green,
                                onTap: _handleLike,
                              ),
                              const SizedBox(width: 8),
                              _ReactionChip(
                                icon: _userDisliked
                                    ? Icons.thumb_down_alt
                                    : Icons.thumb_down_alt_outlined,
                                count: _dislikes,
                                active: _userDisliked,
                                activeColor: _C.red,
                                onTap: _handleDislike,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _AddCommentButton(
                                  onTap: _abrirComentarios,
                                ),
                              ),
                            ],
                          ),
                          if (isAutoridade) ...[
                            const SizedBox(height: 16),
                            _PainelAutoridade(
                              verificada: _verificada,
                              statusOficial: _statusOficial,
                              processando: _processandoVerif,
                              onConfirmar: _toggleVerificacao,
                              onEmAnalise: () =>
                                  _handleStatusOficial('em_analise'),
                              onNaoConfirmada: () =>
                                  _handleStatusOficial('nao_confirmada'),
                              onEncaminhar: () =>
                                  _handleStatusOficial('encaminhada'),
                              onResolver: () =>
                                  _handleStatusOficial('resolvida'),
                              onReverter: () => _handleStatusOficial(null),
                            ),
                          ],
                          const SizedBox(height: 28),

                          // Seção de acompanhamento (linha do tempo de status)
                          Text(
                            'Acompanhamento',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: pal.ink,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _StatusTimeline(occurrence: o, service: _service),
                          const SizedBox(height: 28),

                          // Seção de comentários: abre o mesmo sheet do feed
                          // (OccurrenceCommentsSheet), evitando reimplementar
                          // a lógica de adicionar/curtir/excluir aqui também.
                          StreamBuilder<List<ComentarioModel>>(
                            stream: _comentarioRepository.listarComentarios(
                              o.id,
                            ),
                            builder: (context, snap) {
                              final total = (snap.data ?? const [])
                                  .where((c) => !c.oculto)
                                  .length;
                              return InkWell(
                                onTap: () => _abrirComentarios(),
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Comentários',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: pal.ink,
                                      ),
                                    ),
                                    if (total > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          '$total',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Icon(Icons.chevron_right, color: pal.hint),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: _abrirComentarios,
                            icon: const Icon(Icons.mode_comment_outlined),
                            label: const Text('Ver e comentar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(OcorrenciaModel o, OccurrenceStatus statusEnum) {
    final pal = context.pal;
    final authorLabel = _authorName ?? 'Usuário';

    return Container(
      color: pal.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Voltar',
                  icon: Icon(Icons.arrow_back, color: pal.ink),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      authorLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.share_outlined, color: pal.ink),
                  tooltip: 'Compartilhar',
                  onPressed: () => compartilharOcorrencia(widget.occurrence),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  backgroundImage: _authorPhoto != null
                      ? imagemCacheada(_authorPhoto!)
                      : null,
                  child: _authorPhoto == null
                      ? Text(
                          (_authorName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: _C.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    o.localizacao.isEmpty
                        ? 'Localização não informada'
                        : o.localizacao,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _C.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: statusEnum),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _comoChegar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.green,
                  side: const BorderSide(color: _C.green),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.directions_outlined, size: 18),
                label: const Text(
                  'Como chegar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: pal.border),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ÁREA DE IMAGEM
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
    if (images.isEmpty) {
      return _Placeholder(type: widget.type);
    }
    final pal = context.pal;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final larguraImg = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Container(
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
                // Descrição para leitores de tela (sem isto vira só "imagem").
                semanticLabel: images.length > 1
                    ? 'Foto ${i + 1} de ${images.length} da denúncia: ${widget.type.label}'
                    : 'Foto da denúncia: ${widget.type.label}',
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
                errorBuilder: (_, _, _) => _Placeholder(type: widget.type),
              ),
            ),
          ),
          if (images.length > 1) ...[
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(images.length, (i) {
                        final active = i == _current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1}/${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
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

class _VideoPlayerCard extends StatefulWidget {
  final String url;
  const _VideoPlayerCard({required this.url});

  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  late final VideoPlayerController _controller;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((_) {
            if (mounted) setState(() => _erro = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    if (_erro) {
      return Container(
        height: 120,
        width: double.infinity,
        color: pal.surfaceAlt,
        alignment: Alignment.center,
        child: Text(
          'Não foi possível carregar o vídeo.',
          style: TextStyle(color: pal.hint, fontSize: 12),
        ),
      );
    }

    if (!_controller.value.isInitialized) {
      return Container(
        height: 200,
        width: double.infinity,
        color: pal.surfaceAlt,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            AnimatedOpacity(
              opacity: _controller.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TYPE BADGE  (sobre a imagem)
// ─────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final OccurrenceType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  STATUS BADGE
// ─────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OccurrenceStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(status.icon, color: Colors.white, size: 14),
    );
  }
}

// ─────────────────────────────────────────
//  FIELD CARD (título / descrição)
// ─────────────────────────────────────────

class _FieldCard extends StatelessWidget {
  final Widget child;
  const _FieldCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────
//  REACTION CHIP  (like / dislike)
// ─────────────────────────────────────────

class _ReactionChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.icon,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.08) : pal.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? activeColor : pal.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? activeColor : pal.hint),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : pal.hint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ADD COMMENT BUTTON
// ─────────────────────────────────────────

class _AddCommentButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCommentButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pal.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 16, color: pal.hint),
            const SizedBox(width: 6),
            Text(
              'Adicionar comentário',
              style: TextStyle(
                fontSize: 13,
                color: pal.hint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  VERIFICAÇÃO OFICIAL
// ─────────────────────────────────────────

class _VerificadaBanner extends StatelessWidget {
  final String? nome;
  final DateTime? data;

  const _VerificadaBanner({required this.nome, required this.data});

  @override
  Widget build(BuildContext context) {
    final quando = data != null ? DateFormat('dd/MM/yyyy').format(data!) : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.green.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: _C.green, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome != null && nome!.isNotEmpty
                      ? 'Verificada por $nome'
                      : 'Denúncia verificada',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
                if (quando != null)
                  Text(
                    'Confirmada em $quando',
                    style: TextStyle(fontSize: 11, color: context.pal.hint),
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
//  BANNER STATUS OFICIAL (em análise / não confirmada)
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
  final String? statusOficial;
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
            child: CircularProgressIndicator(strokeWidth: 2, color: _C.green),
          ),
        ),
      );
    }

    // ── Estados pós-confirmação (verificada == true) ──
    if (verificada) {
      // Estado: Resolvida
      if (statusOficial == 'resolvida') {
        return _botaoTexto(
          label: 'Reverter para encaminhada',
          onTap: onEncaminhar,
        );
      }

      // Estado: Encaminhada
      if (statusOficial == 'encaminhada') {
        return Column(
          children: [
            _botao(
              label: 'Marcar como resolvida',
              icon: Icons.check_circle_outline,
              color: _C.green,
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
            color: _C.blue,
            onTap: onEncaminhar,
          ),
          const SizedBox(height: 8),
          _botaoTexto(label: 'Remover verificação', onTap: onConfirmar),
        ],
      );
    }

    // ── Estados pré-confirmação (verificada == false) ──

    // Estado: Em análise
    if (statusOficial == 'em_analise') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _botao(
                  label: 'Confirmar',
                  icon: Icons.verified_outlined,
                  color: _C.green,
                  onTap: onConfirmar,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _botao(
                  label: 'Não confirmada',
                  icon: Icons.cancel_outlined,
                  color: _C.red,
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
    if (statusOficial == 'nao_confirmada') {
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
            color: _C.orange,
            onTap: onEmAnalise,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _botao(
            label: 'Confirmar',
            icon: Icons.verified_outlined,
            color: _C.green,
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
  final OcorrenciaRepository service;
  const _StatusTimeline({required this.occurrence, required this.service});

  String _fmt(DateTime? d) =>
      d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d);

  // Estilo (ícone/cor/rótulo) de um evento de auditoria. 'verificada' não é um
  // StatusOficial, então tem tratamento próprio; os demais reusam o enum.
  ({IconData icone, Color cor, String label}) _estiloEvento(
    BuildContext context,
    String chave,
  ) {
    if (chave == 'verificada') {
      return (
        icone: Icons.verified,
        cor: context.pal.primary,
        label: 'Confirmada pela autoridade',
      );
    }
    final s = StatusOficialInfo.fromString(chave);
    if (s != null) {
      return (icone: s.icon, cor: s.color, label: s.label);
    }
    return (icone: Icons.circle_outlined, cor: context.pal.muted, label: chave);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return StreamBuilder<List<({String status, String? por, DateTime? data})>>(
      stream: service.listarHistorico(occurrence.id),
      builder: (context, snap) {
        final eventos = snap.data ?? [];
        final linhas =
            <
              ({
                IconData icone,
                Color cor,
                String label,
                String? por,
                DateTime? data,
              })
            >[
              (
                icone: Icons.add_location_alt_outlined,
                cor: context.pal.muted,
                label: 'Registrada',
                por: null,
                data: occurrence.dataCriacao,
              ),
            ];
        for (final e in eventos) {
          final est = _estiloEvento(context, e.status);
          linhas.add((
            icone: est.icone,
            cor: est.cor,
            label: est.label,
            por: e.por,
            data: e.data,
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < linhas.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: linhas[i].cor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            linhas[i].icone,
                            size: 15,
                            color: linhas[i].cor,
                          ),
                        ),
                        if (i != linhas.length - 1)
                          Expanded(
                            child: Container(width: 2, color: pal.border),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: i == linhas.length - 1 ? 0 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            linhas[i].label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: linhas[i].cor,
                            ),
                          ),
                          if (linhas[i].data != null)
                            Text(
                              _fmt(linhas[i].data),
                              style: TextStyle(fontSize: 12, color: pal.hint),
                            ),
                          if (linhas[i].por != null)
                            Text(
                              'por ${linhas[i].por}',
                              style: TextStyle(fontSize: 12, color: pal.hint),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
