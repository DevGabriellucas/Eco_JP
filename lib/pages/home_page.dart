import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/comentario_model.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';
import '../services/ocorrencia_service.dart';
import '../services/role_service.dart';
import '../services/usuario_service.dart';
import '../services/moderacao_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_states.dart';
import '../widgets/occurrence_card.dart';
import '../widgets/occurrence_comments_sheet.dart';
import '../widgets/ocorrencia_actions.dart';
import '../widgets/report_content_sheet.dart';
import '../utils/reacao_ocorrencia.dart';
import 'fila_verificacao_page.dart';
import 'notificacoes_page.dart';
import 'perfil/perfil_publico_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _ocorrenciaService = OcorrenciaService();
  final _authService = AuthService();
  final _notificacaoService = NotificacaoService();
  final _roleService = RoleService();
  final _usuarioService = UsuarioService();
  final _moderacaoService = ModeracaoService();

  late Stream<List<OcorrenciaModel>> _feedStream;

  int _pageLimit = _pageSize;
  bool _loadingMore = false;
  bool _hasPotentialMore = true;
  List<OcorrenciaModel> _cachedOccurrences = const [];

  OccurrenceType? _selectedType;
  OccurrenceStatus? _selectedStatus;
  String _searchQuery = '';

  final Map<String, String> _nomeCache = {};
  final Map<String, String?> _fotoCache = {};
  final Set<String> _hiddenOccurrenceIds = <String>{};

  // Cache da contagem de comentários por ocorrência. A contagem agora usa
  // aggregation .count() (uma leitura pontual, não um listener por doc). O
  // cache evita refazer a contagem a cada rebuild do feed (like, filtro,
  // scroll). Envolvido em asStream() para preservar a API do card.
  final Map<String, Stream<int>> _commentCountCache = {};
  final Map<String, Stream<ComentarioModel?>> _latestCommentCache = {};

  Stream<int> _commentCountStream(String id) => _commentCountCache[id] ??=
      _ocorrenciaService.contarComentarios(id).asStream().asBroadcastStream();

  Stream<ComentarioModel?> _latestCommentStream(String id) =>
      _latestCommentCache[id] ??= _ocorrenciaService
          .observarUltimoComentario(id)
          .asBroadcastStream();

  @override
  void initState() {
    super.initState();
    _feedStream = _buildFeedStream();
    _scrollController.addListener(_onScroll);
  }

  Stream<List<OcorrenciaModel>> _buildFeedStream() {
    return _ocorrenciaService.listarFeedComFixadas(_pageLimit);
  }

  bool get _hasActiveFilters =>
      _selectedType != null ||
      _selectedStatus != null ||
      _searchQuery.isNotEmpty;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 360) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loadingMore || !_hasPotentialMore) return;
    setState(() {
      _loadingMore = true;
      _pageLimit += _pageSize;
      _feedStream = _buildFeedStream();
    });
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _pageLimit = _pageSize;
      _loadingMore = false;
      _hasPotentialMore = true;
      _feedStream = _buildFeedStream();
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedType = null;
      _selectedStatus = null;
      _searchQuery = '';
    });
  }

  void _retryFeed() {
    setState(() {
      _pageLimit = _pageSize;
      _loadingMore = false;
      _hasPotentialMore = true;
      _feedStream = _buildFeedStream();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _carregarDadosAutor(List<OcorrenciaModel> ocorrencias) {
    final missingIds = ocorrencias
        .where(
          (o) =>
              !o.anonima &&
              o.usuarioId != null &&
              (o.usuarioNome == null || o.usuarioNome!.trim().isEmpty) &&
              !_nomeCache.containsKey(o.usuarioId),
        )
        .map((o) => o.usuarioId!)
        .toSet();

    for (final uid in missingIds) {
      _nomeCache[uid] = '';
      FirebaseFirestore.instance.collection('usuarios').doc(uid).get().then((
        doc,
      ) {
        if (!mounted) return;
        final data = doc.data();
        final nome = (data?['nome'] as String?)?.trim();
        final foto = data?['fotoUrl'] as String?;
        String resolved;
        if (nome != null && nome.isNotEmpty) {
          resolved = nome;
        } else if (uid == _authService.currentUser?.uid) {
          resolved =
              _authService.currentUser?.email?.split('@').first ?? 'Usuário';
        } else {
          resolved = 'Usuário';
        }
        setState(() {
          _nomeCache[uid] = resolved;
          _fotoCache[uid] = foto?.isNotEmpty == true ? foto : null;
        });
      });
    }
  }

  List<OcorrenciaModel> _applyFilters(List<OcorrenciaModel> ocorrencias) {
    final query = _searchQuery.toLowerCase().trim();
    return ocorrencias.where((o) {
      if (o.oculto) return false; // ocultada pela autoridade (moderação)
      if (_hiddenOccurrenceIds.contains(o.id)) return false;
      final matchesSearch =
          query.isEmpty ||
          o.localizacao.toLowerCase().contains(query) ||
          o.titulo.toLowerCase().contains(query);
      final matchesType =
          _selectedType == null ||
          OccurrenceTypeParser.fromString(o.tipoLixo) == _selectedType;
      final matchesStatus =
          _selectedStatus == null ||
          OccurrenceStatusParser.fromString(o.status) == _selectedStatus;
      return matchesSearch && matchesType && matchesStatus;
    }).toList();
  }

  Future<void> _toggleLike(OcorrenciaModel o) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final eu = _authService.currentUser;
    final nome = eu?.displayName ?? eu?.email?.split('@').first;
    await reagirOcorrencia(
      context: context,
      ocorrencia: o,
      uid: uid,
      isLike: true,
      ocorrenciaService: _ocorrenciaService,
      notificacaoService: _notificacaoService,
      nomeAutor: nome,
      onMudou: () => setState(() {}),
    );
  }

  Future<void> _toggleDislike(OcorrenciaModel o) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final eu = _authService.currentUser;
    final nome = eu?.displayName ?? eu?.email?.split('@').first;
    await reagirOcorrencia(
      context: context,
      ocorrencia: o,
      uid: uid,
      isLike: false,
      ocorrenciaService: _ocorrenciaService,
      notificacaoService: _notificacaoService,
      nomeAutor: nome,
      onMudou: () => setState(() {}),
    );
  }

  void _openComments(OcorrenciaModel o) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OccurrenceCommentsSheet(
        occurrence: o,
        ocorrenciaService: _ocorrenciaService,
        authService: _authService,
        usuarioService: _usuarioService,
        notificacaoService: _notificacaoService,
      ),
    );
  }

  void _openPublicProfile(
    OcorrenciaModel o, {
    required String? nomeAutor,
    required String? fotoAutor,
  }) {
    final authorId = o.usuarioId;
    if (authorId == null || o.anonima) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilPublicoPage(
          userId: authorId,
          fallbackName: nomeAutor ?? 'Usuário',
          fallbackPhotoUrl: fotoAutor,
        ),
      ),
    );
  }

  Future<void> _gerenciarOcorrencia(OcorrenciaModel o) async {
    await showOcorrenciaActions(
      context: context,
      ocorrencia: o,
      service: _ocorrenciaService,
    );
  }

  Future<void> _denunciarOcorrencia(OcorrenciaModel o) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final result = await showReportContentSheet(
      context,
      title: 'Denunciar publicação',
    );
    if (result == null) return;

    try {
      await _moderacaoService.denunciarOcorrencia(
        ocorrenciaId: o.id,
        denuncianteId: uid,
        motivo: result.motivo,
        detalhe: result.detalhe,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denúncia enviada para moderação.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar a denúncia.')),
      );
    }
  }

  void _ocultarOcorrencia(OcorrenciaModel o) {
    setState(() => _hiddenOccurrenceIds.add(o.id));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Denúncia ocultada do feed.'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              if (!mounted) return;
              setState(() => _hiddenOccurrenceIds.remove(o.id));
            },
          ),
        ),
      );
  }

  Future<void> _toggleSalvarOcorrencia(
    OcorrenciaModel o, {
    required bool salvo,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final vaiSalvar = !salvo;

    try {
      await _usuarioService.definirFavorito(
        uid: uid,
        ocorrenciaId: o.id,
        salvar: vaiSalvar,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              vaiSalvar
                  ? 'Denúncia salva nos favoritos.'
                  : 'Denúncia removida dos favoritos.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar os salvos.')),
      );
    }
  }

  Future<void> _toggleFixarOcorrencia(OcorrenciaModel o) async {
    final fixar = !o.fixada;
    try {
      await _ocorrenciaService.definirFixada(o.id, fixada: fixar);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              fixar
                  ? 'Denuncia fixada no topo do feed.'
                  : 'Destaque removido do feed.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel atualizar o destaque.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Row(
          children: [
            Text(
              'EcoJP',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(width: 12),
            Text('Feed', style: TextStyle(fontSize: 15, color: AppColors.hint)),
          ],
        ),
        actions: [
          if (uid != null)
            StreamBuilder<int>(
              stream: _notificacaoService.contarNaoLidas(uid),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Notificações',
                      icon: const Icon(
                        Icons.notifications_none,
                        color: AppColors.ink,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificacoesPage(),
                        ),
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 6,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (uid != null)
              StreamBuilder<bool>(
                stream: _roleService.observarAutoridade(uid),
                builder: (context, snap) {
                  if (snap.data != true) return const SizedBox.shrink();
                  return _BannerAutoridade(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FilaVerificacaoPage(),
                      ),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SearchBar(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TypeDropdown(
                selected: _selectedType,
                onChanged: (v) => setState(() => _selectedType = v),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _StatusChip(
                    label: 'Todos',
                    selected: _selectedStatus == null,
                    color: AppColors.muted,
                    onTap: () => setState(() => _selectedStatus = null),
                  ),
                  ...OccurrenceStatus.values.map(
                    (s) => _StatusChip(
                      label: s.label,
                      selected: _selectedStatus == s,
                      color: s.color,
                      onTap: () => setState(
                        () => _selectedStatus = _selectedStatus == s ? null : s,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildFeed(uid)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(String? uid) {
    if (uid == null) {
      return _buildFeedContent(uid, const <String>{}, isAutoridade: false);
    }

    return StreamBuilder<Set<String>>(
      stream: _usuarioService.observarFavoritosIds(uid),
      initialData: const <String>{},
      builder: (context, snapshot) {
        return StreamBuilder<bool>(
          stream: _roleService.observarAutoridade(uid),
          initialData: false,
          builder: (context, roleSnapshot) {
            // Denúncias anônimas não guardam usuarioId no documento público
            // (S2) — para saber "é minha denúncia" nesse caso, comparamos
            // com os ponteiros do próprio perfil, não com o campo.
            return StreamBuilder<Set<String>>(
              stream: _ocorrenciaService.observarMinhasDenunciasAnonimasIds(
                uid,
              ),
              initialData: const <String>{},
              builder: (context, minhasAnonimasSnap) {
                return _buildFeedContent(
                  uid,
                  snapshot.data ?? const <String>{},
                  isAutoridade: roleSnapshot.data == true,
                  minhasDenunciasAnonimasIds:
                      minhasAnonimasSnap.data ?? const <String>{},
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFeedContent(
    String? uid,
    Set<String> favoritosIds, {
    required bool isAutoridade,
    Set<String> minhasDenunciasAnonimasIds = const <String>{},
  }) {
    return StreamBuilder<List<OcorrenciaModel>>(
      stream: _feedStream,
      initialData: _cachedOccurrences.isEmpty ? null : _cachedOccurrences,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedOccurrences.isEmpty) {
          return const FeedSkeleton();
        }

        if (snapshot.hasError && _cachedOccurrences.isEmpty) {
          return FeedErrorState(onRetry: _retryFeed);
        }

        final all = snapshot.data ?? _cachedOccurrences;
        _cachedOccurrences = all;
        _carregarDadosAutor(all);

        final hasMore = all.length >= _pageLimit;
        if (_loadingMore || _hasPotentialMore != hasMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _loadingMore = false;
              _hasPotentialMore = hasMore;
            });
          });
        }

        final filtradas = _applyFilters(all);

        return RefreshIndicator(
          onRefresh: _refreshFeed,
          child: filtradas.isEmpty
              ? _EmptyFeedList(
                  hasActiveFilters: _hasActiveFilters,
                  hasPotentialMore: _hasPotentialMore,
                  loadingMore: _loadingMore,
                  onClearFilters: _clearFilters,
                  onLoadMore: _loadMore,
                )
              : _OccurrenceList(
                  controller: _scrollController,
                  occurrences: filtradas,
                  hasPotentialMore: _hasPotentialMore,
                  loadingMore: _loadingMore,
                  onLoadMore: _loadMore,
                  itemBuilder: (o) {
                    // Anônima: o campo usuarioId sumiu do documento (S2), então
                    // "é minha" vem dos ponteiros do próprio perfil.
                    final isOwner = uid != null &&
                        (o.anonima
                            ? minhasDenunciasAnonimasIds.contains(o.id)
                            : o.usuarioId == uid);
                    final nomeAutor = o.anonima
                        ? 'Denunciante anônimo'
                        : (o.usuarioNome != null &&
                                  o.usuarioNome!.trim().isNotEmpty
                              ? o.usuarioNome!
                              : (_nomeCache[o.usuarioId]?.isNotEmpty == true
                                    ? _nomeCache[o.usuarioId]
                                    : null));
                    final fotoAutor = o.anonima
                        ? null
                        : ((o.usuarioFotoUrl != null &&
                                  o.usuarioFotoUrl!.isNotEmpty)
                              ? o.usuarioFotoUrl
                              : _fotoCache[o.usuarioId]);

                    return OccurrenceCard(
                      occurrence: o,
                      nomeAutor: nomeAutor,
                      fotoAutor: fotoAutor,
                      commentCountStream: _commentCountStream(o.id),
                      latestCommentStream: _latestCommentStream(o.id),
                      saved: favoritosIds.contains(o.id),
                      onLike: () => _toggleLike(o),
                      onDislike: () => _toggleDislike(o),
                      onComment: () => _openComments(o),
                      onAuthorTap: o.anonima || o.usuarioId == null
                          ? null
                          : () => _openPublicProfile(
                              o,
                              nomeAutor: nomeAutor,
                              fotoAutor: fotoAutor,
                            ),
                      onReport: isOwner ? null : () => _denunciarOcorrencia(o),
                      onTogglePin: isAutoridade
                          ? () => _toggleFixarOcorrencia(o)
                          : null,
                      onSave: () => _toggleSalvarOcorrencia(
                        o,
                        salvo: favoritosIds.contains(o.id),
                      ),
                      onHide: () => _ocultarOcorrencia(o),
                      onManage: isOwner ? () => _gerenciarOcorrencia(o) : null,
                    );
                  },
                ),
        );
      },
    );
  }
}

class _OccurrenceList extends StatelessWidget {
  final ScrollController controller;
  final List<OcorrenciaModel> occurrences;
  final bool hasPotentialMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final Widget Function(OcorrenciaModel occurrence) itemBuilder;

  const _OccurrenceList({
    required this.controller,
    required this.occurrences,
    required this.hasPotentialMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: occurrences.length + 1,
      separatorBuilder: (_, index) => index >= occurrences.length - 1
          ? const SizedBox.shrink()
          : const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i == occurrences.length) {
          return _PaginationFooter(
            hasPotentialMore: hasPotentialMore,
            loadingMore: loadingMore,
            onLoadMore: onLoadMore,
          );
        }
        return itemBuilder(occurrences[i]);
      },
    );
  }
}

class _EmptyFeedList extends StatelessWidget {
  final bool hasActiveFilters;
  final bool hasPotentialMore;
  final bool loadingMore;
  final VoidCallback onClearFilters;
  final VoidCallback onLoadMore;

  const _EmptyFeedList({
    required this.hasActiveFilters,
    required this.hasPotentialMore,
    required this.loadingMore,
    required this.onClearFilters,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.46,
          child: FeedEmptyState(
            hasActiveFilters: hasActiveFilters,
            onClearFilters: hasActiveFilters ? onClearFilters : null,
          ),
        ),
        if (hasActiveFilters)
          _PaginationFooter(
            hasPotentialMore: hasPotentialMore,
            loadingMore: loadingMore,
            onLoadMore: onLoadMore,
            filteredEmpty: true,
          ),
      ],
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  final bool hasPotentialMore;
  final bool loadingMore;
  final bool filteredEmpty;
  final VoidCallback onLoadMore;

  const _PaginationFooter({
    required this.hasPotentialMore,
    required this.loadingMore,
    required this.onLoadMore,
    this.filteredEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasPotentialMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text(
              filteredEmpty
                  ? 'Buscar em denúncias antigas'
                  : 'Carregar mais denúncias',
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        filteredEmpty
            ? 'Nenhuma denúncia carregada combina com esses filtros.'
            : 'Você chegou ao fim do feed.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.hint,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.ink),
        decoration: const InputDecoration(
          hintText: 'Filtrar localização',
          prefixIcon: Icon(Icons.search, color: AppColors.hint, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  final OccurrenceType? selected;
  final ValueChanged<OccurrenceType?> onChanged;

  const _TypeDropdown({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OccurrenceType?>(
          value: selected,
          isExpanded: true,
          icon: const Icon(Icons.menu, color: AppColors.hint, size: 20),
          hint: const Text(
            'Tipo de ocorrência',
            style: TextStyle(color: AppColors.hint, fontSize: 14),
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.ink),
          items: [
            const DropdownMenuItem<OccurrenceType?>(
              value: null,
              child: Text('Todos os tipos'),
            ),
            ...OccurrenceType.values.map(
              (t) => DropdownMenuItem(
                value: t,
                child: Row(
                  children: [
                    Icon(t.icon, size: 16, color: t.color),
                    const SizedBox(width: 8),
                    Text(t.label, style: TextStyle(color: t.color)),
                  ],
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  BANNER DE AUTORIDADE
//  Visível no topo do feed apenas para contas com papel 'autoridade'.
// ─────────────────────────────────────────

class _BannerAutoridade extends StatelessWidget {
  final VoidCallback onTap;
  const _BannerAutoridade({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.ink,
        child: Row(
          children: const [
            Icon(Icons.shield_outlined, size: 16, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fila de verificação — toque para ver denúncias pendentes',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
