import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../models/comentario_model.dart';
import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';
import '../services/ocorrencia_service.dart';
import '../services/role_service.dart';
import '../services/usuario_service.dart';
import '../models/occurrence_types.dart';
import '../utils/compartilhamento.dart';
import '../utils/navegacao_externa.dart';
import '../utils/tempo_relativo.dart';

// ─────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────

class _C {
  static const bg = Color(0xFFF2F2F2);
  static const white = Colors.white;
  static const border = Color(0xFFD8D8D8);
  static const text = Color(0xFF1A1A1A);
  static const hint = Color(0xFF8A8A8A);
  static const orange = Color(0xFFFF8A1F);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6);
}

// ─────────────────────────────────────────
//  DETALHE OCORRÊNCIA PAGE
// ─────────────────────────────────────────

class DetalheOcorrenciaPage extends StatefulWidget {
  final OcorrenciaModel occurrence;

  const DetalheOcorrenciaPage({super.key, required this.occurrence});

  @override
  State<DetalheOcorrenciaPage> createState() => _DetalheOcorrenciaPageState();
}

class _DetalheOcorrenciaPageState extends State<DetalheOcorrenciaPage> {
  final _authService = AuthService();
  final _service = OcorrenciaService();
  final _usuarioService = UsuarioService();
  final _notificacaoService = NotificacaoService();
  final _roleService = RoleService();

  late int _likes;
  late int _dislikes;
  late bool _userLiked;
  late bool _userDisliked;
  late List<String> _likedBy;
  late List<String> _dislikedBy;
  String? _authorName;
  String? _authorPhoto;

  // Verificação oficial
  bool _isAutoridade = false;
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
    _likedBy = List<String>.from(o.likedBy);
    _dislikedBy = List<String>.from(o.dislikedBy);
    _verificada = o.verificada;
    _verificadaPorNome = o.verificadaPorNome;
    _verificadaEm = o.verificadaEm;
    _statusOficial = o.statusOficial;
    _fetchAuthorData();
    _checarPapel();
  }

  Future<void> _checarPapel() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final isAut = await _roleService.isAutoridade(uid);
    if (mounted) setState(() => _isAutoridade = isAut);
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

    final hasSavedName =
        o.usuarioNome != null && o.usuarioNome!.trim().isNotEmpty;
    final hasSavedPhoto =
        o.usuarioFotoUrl != null && o.usuarioFotoUrl!.isNotEmpty;

    if (hasSavedName && hasSavedPhoto) {
      setState(() {
        _authorName = o.usuarioNome;
        _authorPhoto = o.usuarioFotoUrl;
      });
      return;
    }

    if (o.usuarioId == null) {
      if (hasSavedName) setState(() => _authorName = o.usuarioNome);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(o.usuarioId)
        .get();

    if (!mounted) return;

    final data = doc.data();
    final nome = (data?['nome'] as String?)?.trim();
    final foto = data?['fotoUrl'] as String?;

    String? resolvedName;
    if (hasSavedName) {
      resolvedName = o.usuarioNome;
    } else if (nome != null && nome.isNotEmpty) {
      resolvedName = nome;
    } else if (o.usuarioId == _authService.currentUser?.uid) {
      final email = _authService.currentUser?.email;
      resolvedName = email != null ? email.split('@').first : 'Usuário';
    } else {
      resolvedName = 'Usuário';
    }

    setState(() {
      _authorName = resolvedName;
      _authorPhoto = hasSavedPhoto
          ? o.usuarioFotoUrl
          : (foto?.isNotEmpty == true ? foto : null);
    });
  }

  String get _uid => _authService.currentUser?.uid ?? '';

  // Reaplica o estado anterior de reação se a gravação falhar.
  void _restaurarReacao(
    bool userLiked,
    bool userDisliked,
    int likes,
    int dislikes,
    List<String> likedBy,
    List<String> dislikedBy,
  ) {
    _userLiked = userLiked;
    _userDisliked = userDisliked;
    _likes = likes;
    _dislikes = dislikes;
    _likedBy = likedBy;
    _dislikedBy = dislikedBy;
  }

  Future<void> _handleLike() async {
    if (_uid.isEmpty) return;
    final vaiCurtir = !_userLiked;
    final pLiked = _userLiked,
        pDisliked = _userDisliked,
        pLikes = _likes,
        pDislikes = _dislikes;
    final pLikedBy = List<String>.from(_likedBy);
    final pDislikedBy = List<String>.from(_dislikedBy);

    setState(() {
      if (_userLiked) {
        _userLiked = false;
        _likes--;
        _likedBy.remove(_uid);
      } else {
        if (_userDisliked) {
          _userDisliked = false;
          _dislikes--;
          _dislikedBy.remove(_uid);
        }
        _userLiked = true;
        _likes++;
        _likedBy.add(_uid);
      }
    });

    try {
      await _service.toggleLike(widget.occurrence.id, _uid);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _restaurarReacao(
          pLiked,
          pDisliked,
          pLikes,
          pDislikes,
          pLikedBy,
          pDislikedBy,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível curtir agora. Tente novamente.'),
        ),
      );
      return;
    }

    if (vaiCurtir) _notificarCurtida();
  }

  void _notificarCurtida() {
    final dono = widget.occurrence.usuarioId;
    final eu = _authService.currentUser;
    if (dono == null || eu == null || dono == eu.uid) return;
    final nome = eu.displayName ?? eu.email?.split('@').first ?? 'Alguém';
    _notificacaoService.notificar(
      donoId: dono,
      tipo: 'curtida',
      deUsuarioNome: nome,
      ocorrenciaId: widget.occurrence.id,
      ocorrenciaTitulo: widget.occurrence.titulo,
    );
  }

  Future<void> _handleDislike() async {
    if (_uid.isEmpty) return;
    final pLiked = _userLiked,
        pDisliked = _userDisliked,
        pLikes = _likes,
        pDislikes = _dislikes;
    final pLikedBy = List<String>.from(_likedBy);
    final pDislikedBy = List<String>.from(_dislikedBy);

    setState(() {
      if (_userDisliked) {
        _userDisliked = false;
        _dislikes--;
        _dislikedBy.remove(_uid);
      } else {
        if (_userLiked) {
          _userLiked = false;
          _likes--;
          _likedBy.remove(_uid);
        }
        _userDisliked = true;
        _dislikes++;
        _dislikedBy.add(_uid);
      }
    });

    try {
      await _service.toggleDislike(widget.occurrence.id, _uid);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _restaurarReacao(
          pLiked,
          pDisliked,
          pLikes,
          pDislikes,
          pLikedBy,
          pDislikedBy,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível reagir agora. Tente novamente.'),
        ),
      );
    }
  }

  void _openCommentSheet({String? parentId, String? respondendoA}) {
    final authUser = _authService.currentUser;
    if (authUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentInputSheet(
        respondendoA: respondendoA,
        onSubmit: (text) async {
          final perfil = await _usuarioService.carregarPerfil(authUser.uid);
          final nome = perfil?.nome.trim().isNotEmpty == true
              ? perfil!.nome
              : (authUser.displayName ?? 'Usuário');
          final foto = perfil?.fotoUrl ?? authUser.photoURL;

          final comentario = ComentarioModel(
            id: '',
            userId: authUser.uid,
            userName: nome,
            userPhotoUrl: foto,
            texto: text,
            parentId: parentId,
          );
          await _service.adicionarComentario(widget.occurrence.id, comentario);
          // Notifica o dono da denúncia (se não for o próprio autor).
          final dono = widget.occurrence.usuarioId;
          if (dono != null && dono != authUser.uid) {
            await _notificacaoService.notificar(
              donoId: dono,
              tipo: 'comentario',
              deUsuarioNome: nome,
              ocorrenciaId: widget.occurrence.id,
              ocorrenciaTitulo: widget.occurrence.titulo,
            );
          }
        },
      ),
    );
  }

  Future<void> _toggleLikeComentario(ComentarioModel c) async {
    if (_uid.isEmpty) return;
    try {
      await _service.toggleLikeComentario(widget.occurrence.id, c.id, _uid);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível curtir agora.')),
      );
    }
  }

  Future<void> _deleteComment(ComentarioModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir comentário'),
        content: const Text('Tem certeza que deseja excluir este comentário?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _C.hint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.red,
              foregroundColor: _C.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deletarComentario(widget.occurrence.id, c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.occurrence;
    final typeEnum = OccurrenceTypeParser.fromString(o.tipoLixo);
    final statusEnum = OccurrenceStatusParser.fromString(o.status);

    return Scaffold(
      backgroundColor: _C.bg,
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
                              label: 'Resolvida — tratada pelo órgão responsável',
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
                              label: 'Não confirmada — problema não encontrado no local',
                              icon: Icons.cancel_outlined,
                              color: _C.red,
                            ),
                            const SizedBox(height: 10),
                          ],
                          // Título
                          _FieldCard(
                            child: Text(
                              o.titulo.isEmpty ? 'Sem título' : o.titulo,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _C.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Descrição
                          _FieldCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Descrição',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _C.hint,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  o.descricao.isEmpty
                                      ? 'Sem descrição'
                                      : o.descricao,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF374151),
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
                                  onTap: _openCommentSheet,
                                ),
                              ),
                            ],
                          ),
                          if (_isAutoridade) ...[
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
                          const Text(
                            'Acompanhamento',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _C.text,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _StatusTimeline(occurrence: o, service: _service),
                          const SizedBox(height: 28),

                          // Seção de comentários (com contador em tempo real)
                          StreamBuilder<int>(
                            stream: _service.contarComentarios(o.id),
                            initialData: o.comments,
                            builder: (context, snap) {
                              final total = snap.data ?? 0;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Comentários',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: _C.text,
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
                                        borderRadius: BorderRadius.circular(20),
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
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          StreamBuilder<List<ComentarioModel>>(
                            stream: _service.listarComentarios(o.id),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              final comentarios = snap.data ?? [];
                              if (comentarios.isEmpty) {
                                return const _EmptyComments();
                              }
                              // Agrupa respostas sob o comentário raiz.
                              final raizes = comentarios
                                  .where((c) => c.parentId == null)
                                  .toList();
                              final respostasPor =
                                  <String, List<ComentarioModel>>{};
                              for (final c in comentarios) {
                                if (c.parentId != null) {
                                  (respostasPor[c.parentId!] ??= []).add(c);
                                }
                              }
                              return Column(
                                children: [
                                  for (final raiz in raizes) ...[
                                    _CommentItem(
                                      comentario: raiz,
                                      isOwn: raiz.userId == _uid,
                                      onDelete: () => _deleteComment(raiz),
                                      onLike: () => _toggleLikeComentario(raiz),
                                      onReply: () => _openCommentSheet(
                                        parentId: raiz.id,
                                        respondendoA: raiz.userName,
                                      ),
                                    ),
                                    for (final resp
                                        in respostasPor[raiz.id] ?? [])
                                      Padding(
                                        padding: const EdgeInsets.only(left: 38),
                                        child: _CommentItem(
                                          comentario: resp,
                                          isOwn: resp.userId == _uid,
                                          onDelete: () => _deleteComment(resp),
                                          onLike: () =>
                                              _toggleLikeComentario(resp),
                                          // Sem responder em resposta (1 nível).
                                          onReply: null,
                                        ),
                                      ),
                                  ],
                                ],
                              );
                            },
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
    final authorLabel = _authorName ?? 'Usuário';

    return Container(
      color: _C.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _C.text),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      authorLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _C.text,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: _C.text),
                  tooltip: 'Compartilhar',
                  onPressed: () => compartilharOcorrencia(widget.occurrence),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE8F5E9),
                  backgroundImage: _authorPhoto != null
                      ? NetworkImage(_authorPhoto!) as ImageProvider
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
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
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
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: Image.network(
                images[i],
                fit: BoxFit.contain,
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
    return Container(
      height: 240,
      width: double.infinity,
      color: const Color(0xFFD1D5DB),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(type.icon, size: 48, color: Colors.white54),
          const SizedBox(height: 8),
          const Text(
            'Sem imagem',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
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
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {
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
    if (_erro) {
      return Container(
        height: 120,
        width: double.infinity,
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: const Text(
          'Não foi possível carregar o vídeo.',
          style: TextStyle(color: _C.hint, fontSize: 12),
        ),
      );
    }

    if (!_controller.value.isInitialized) {
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.black12,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.08) : _C.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? activeColor : _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? activeColor : _C.hint),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : _C.hint,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.chat_bubble_outline, size: 16, color: _C.hint),
            SizedBox(width: 6),
            Text(
              'Adicionar comentário',
              style: TextStyle(
                fontSize: 13,
                color: _C.hint,
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
//  EMPTY COMMENTS
// ─────────────────────────────────────────

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text(
            'Sem comentários',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFFD1D5DB),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  COMMENT ITEM
// ─────────────────────────────────────────

class _CommentItem extends StatelessWidget {
  final ComentarioModel comentario;
  final bool isOwn;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  final VoidCallback? onReply;

  const _CommentItem({
    required this.comentario,
    required this.isOwn,
    required this.onDelete,
    required this.onLike,
    this.onReply,
  });

  String _formatDate(DateTime? dt) => tempoRelativo(dt);

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = comentario;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage:
                c.userPhotoUrl != null && c.userPhotoUrl!.isNotEmpty
                ? NetworkImage(c.userPhotoUrl!)
                : null,
            child: c.userPhotoUrl == null || c.userPhotoUrl!.isEmpty
                ? Text(
                    _initials(c.userName),
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Conteúdo do comentário
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        c.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _C.text,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(c.dataCriacao),
                      style: const TextStyle(fontSize: 11, color: _C.hint),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: _C.red,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  c.texto,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                // Ações: curtir + responder
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            c.userLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 15,
                            color: c.userLiked ? _C.red : _C.hint,
                          ),
                          if (c.likes > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${c.likes}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.userLiked ? _C.red : _C.hint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onReply != null) ...[
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: onReply,
                        child: const Text(
                          'Responder',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.hint,
                          ),
                        ),
                      ),
                    ],
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
                    style: const TextStyle(fontSize: 11, color: _C.hint),
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
            _botaoTexto(
              label: 'Reverter para confirmada',
              onTap: onReverter,
            ),
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
        color: _C.hint,
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
            color: _C.hint,
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
  final OcorrenciaService service;
  const _StatusTimeline({required this.occurrence, required this.service});

  String _fmt(DateTime? d) =>
      d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<({String status, DateTime? data})>>(
      stream: service.listarHistorico(occurrence.id),
      builder: (context, snap) {
        final eventos = snap.data ?? [];
        final linhas =
            <({IconData icone, Color cor, String label, DateTime? data})>[
              (
                icone: Icons.add_location_alt_outlined,
                cor: const Color(0xFF6B7280),
                label: 'Registrada',
                data: occurrence.dataCriacao,
              ),
            ];
        for (final e in eventos) {
          final s = OccurrenceStatusParser.fromString(e.status);
          linhas.add((
            icone: s.icon,
            cor: s.color,
            label: s.label,
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
                            child: Container(
                              width: 2,
                              color: const Color(0xFFE5E7EB),
                            ),
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.hint,
                              ),
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

// ─────────────────────────────────────────
//  COMMENT INPUT SHEET
// ─────────────────────────────────────────

class _CommentInputSheet extends StatefulWidget {
  final Future<void> Function(String text) onSubmit;
  final String? respondendoA;

  const _CommentInputSheet({required this.onSubmit, this.respondendoA});

  @override
  State<_CommentInputSheet> createState() => _CommentInputSheetState();
}

class _CommentInputSheetState extends State<_CommentInputSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSubmit(text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.respondendoA != null
                  ? 'Respondendo a ${widget.respondendoA}'
                  : 'Adicionar comentário',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Escreva um comentário...',
                      hintStyle: TextStyle(color: _C.hint, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
