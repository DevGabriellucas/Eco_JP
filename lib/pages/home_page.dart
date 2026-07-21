import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/routes.dart';
import '../data/repositories/comentario_repository.dart';
import '../data/repositories/ocorrencia_repository.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/comentario_model.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';
import '../services/usuario_service.dart';
import '../services/moderacao_service.dart';
import '../theme/app_theme.dart';
import '../utils/autor_ocorrencia.dart';
import '../widgets/feed_states.dart';
import '../widgets/occurrence_card.dart';
import '../widgets/occurrence_comments_sheet.dart';
import '../widgets/ocorrencia_actions.dart';
import '../widgets/report_content_sheet.dart';
import '../utils/mensagem_erro.dart';
import '../utils/reacao_ocorrencia.dart';

/// Ordenação do feed. "Recentes" respeita a ordem vinda do repositório
/// (fixadas no topo, depois por data); "Mais curtidas" reordena o restante
/// por número de likes, preservando as fixadas no topo.
enum _FeedSort {
  recentes('Mais recentes', Icons.schedule),
  curtidas('Mais curtidas', Icons.favorite);

  const _FeedSort(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Janela de tempo aplicada sobre `dataCriacao` (client-side).
enum _FeedPeriodo {
  tudo('Qualquer data', null),
  hoje('Hoje', Duration(days: 1)),
  semana('7 dias', Duration(days: 7)),
  mes('30 dias', Duration(days: 30));

  const _FeedPeriodo(this.label, this.janela);
  final String label;
  final Duration? janela;
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _authService = AuthService();
  final _notificacaoService = NotificacaoService();
  final _usuarioService = UsuarioService();
  final _moderacaoService = ModeracaoService();

  OcorrenciaRepository get _ocorrenciaRepository =>
      ref.read(ocorrenciaRepositoryProvider);
  ComentarioRepository get _comentarioRepository =>
      ref.read(comentarioRepositoryProvider);

  late Stream<List<OcorrenciaModel>> _feedStream;

  int _pageLimit = _pageSize;
  bool _loadingMore = false;
  bool _hasPotentialMore = true;
  List<OcorrenciaModel> _cachedOccurrences = const [];

  OccurrenceType? _selectedType;
  OccurrenceStatus? _selectedStatus;
  String _searchQuery = '';
  _FeedSort _sortBy = _FeedSort.recentes;
  _FeedPeriodo _periodo = _FeedPeriodo.tudo;

  final Map<String, String> _nomeCache = {};
  final Map<String, String?> _fotoCache = {};
  final Set<String> _hiddenOccurrenceIds = <String>{};

  // Cache da contagem de comentários por ocorrência. A contagem agora usa
  // aggregation .count() (uma leitura pontual, não um listener por doc). O
  // cache evita refazer a contagem a cada rebuild do feed (like, filtro,
  // scroll). Envolvido em asStream() para preservar a API do card.
  //
  // Limite superior: em sessões longas (rolar fundo + refresh) as chaves são
  // ids de ocorrência que só crescem. `_latestCommentCache` guarda um listener
  // VIVO do Firestore por entrada, então sem teto vira vazamento de listeners.
  // O cap (FIFO) descarta as entradas mais antigas — as do topo do feed, já
  // roladas para fora; se voltarem à tela o stream é recriado sob demanda.
  static const int _maxStreamCache = 120;
  final Map<String, Stream<int>> _commentCountCache = {};
  final Map<String, Stream<ComentarioModel?>> _latestCommentCache = {};

  Stream<int> _commentCountStream(String id) {
    final cached = _commentCountCache[id];
    if (cached != null) return cached;
    _capCache(_commentCountCache);
    return _commentCountCache[id] = _comentarioRepository
        .contarComentarios(id)
        .asStream()
        .asBroadcastStream();
  }

  Stream<ComentarioModel?> _latestCommentStream(String id) {
    final cached = _latestCommentCache[id];
    if (cached != null) return cached;
    _capCache(_latestCommentCache);
    return _latestCommentCache[id] = _comentarioRepository
        .observarUltimoComentario(id)
        .asBroadcastStream();
  }

  // Remove as entradas mais antigas (o Map do Dart preserva ordem de inserção)
  // até abrir espaço para mais uma, mantendo o cache em no máximo
  // [_maxStreamCache] entradas.
  void _capCache<V>(Map<String, V> cache) {
    while (cache.length >= _maxStreamCache) {
      cache.remove(cache.keys.first);
    }
  }

  @override
  void initState() {
    super.initState();
    _feedStream = _buildFeedStream();
    _scrollController.addListener(_onScroll);
  }

  Stream<List<OcorrenciaModel>> _buildFeedStream() {
    return _ocorrenciaRepository.listarFeedComFixadas(_pageLimit);
  }

  bool get _hasActiveFilters =>
      _selectedType != null ||
      _selectedStatus != null ||
      _searchQuery.isNotEmpty ||
      _periodo != _FeedPeriodo.tudo;

  /// Filtros avançados ativos (mostrados atrás do botão de filtro): período
  /// ou ordenação diferente do padrão.
  bool get _temFiltrosAvancados =>
      _periodo != _FeedPeriodo.tudo || _sortBy != _FeedSort.recentes;

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
      _periodo = _FeedPeriodo.tudo;
      _sortBy = _FeedSort.recentes;
    });
  }

  Future<void> _abrirFiltrosAvancados() async {
    final pal = context.pal;
    // Estado temporário do sheet: só aplica ao feed quando o usuário confirma.
    var sortLocal = _sortBy;
    var periodoLocal = _periodo;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: pal.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Filtros avançados',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: pal.ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sheetLabel('ORDENAR POR', pal),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _FeedSort.values.map((s) {
                        return _FiltroChoice(
                          label: s.label,
                          icon: s.icon,
                          selected: sortLocal == s,
                          onTap: () => setSheet(() => sortLocal = s),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _sheetLabel('PERÍODO', pal),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _FeedPeriodo.values.map((p) {
                        return _FiltroChoice(
                          label: p.label,
                          selected: periodoLocal == p,
                          onTap: () => setSheet(() => periodoLocal = p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setSheet(() {
                                sortLocal = _FeedSort.recentes;
                                periodoLocal = _FeedPeriodo.tudo;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: pal.muted,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Limpar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _sortBy = sortLocal;
                                _periodo = periodoLocal;
                              });
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pal.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetLabel(String text, AppPalette pal) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: pal.hint,
      letterSpacing: 0.5,
    ),
  );

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
      resolverAutorOcorrencia(
        usuarioId: uid,
        nomeSalvo: null,
        fotoSalva: null,
        usuarioService: _usuarioService,
        authService: _authService,
      ).then((autor) {
        if (!mounted) return;
        setState(() {
          _nomeCache[uid] = autor.nome;
          _fotoCache[uid] = autor.foto;
        });
      });
    }
  }

  List<OcorrenciaModel> _applyFilters(List<OcorrenciaModel> ocorrencias) {
    final query = _searchQuery.toLowerCase().trim();
    // Limite inferior do período: `dataCriacao` precisa ser mais recente que
    // isto. Null = sem restrição de data.
    final janela = _periodo.janela;
    final limiteData = janela == null ? null : DateTime.now().subtract(janela);

    final filtradas = ocorrencias.where((o) {
      if (o.oculto) return false; // ocultada pela autoridade (moderação)
      if (_hiddenOccurrenceIds.contains(o.id)) return false;
      final matchesSearch =
          query.isEmpty ||
          o.localizacao.toLowerCase().contains(query) ||
          o.titulo.toLowerCase().contains(query) ||
          o.descricao.toLowerCase().contains(query);
      final matchesType =
          _selectedType == null ||
          OccurrenceTypeParser.fromString(o.tipoLixo) == _selectedType;
      final matchesStatus =
          _selectedStatus == null ||
          OccurrenceStatusParser.fromString(o.status) == _selectedStatus;
      final matchesPeriodo =
          limiteData == null ||
          (o.dataCriacao != null && o.dataCriacao!.isAfter(limiteData));
      return matchesSearch && matchesType && matchesStatus && matchesPeriodo;
    }).toList();

    // Ordenação por curtidas preserva as fixadas no topo (semântica de
    // destaque); só o restante é reordenado por número de likes.
    if (_sortBy == _FeedSort.curtidas) {
      final fixadas = filtradas.where((o) => o.fixada).toList();
      final resto = filtradas.where((o) => !o.fixada).toList()
        ..sort((a, b) => b.likes.compareTo(a.likes));
      return [...fixadas, ...resto];
    }
    return filtradas;
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
      ocorrenciaRepository: _ocorrenciaRepository,
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
      ocorrenciaRepository: _ocorrenciaRepository,
      notificacaoService: _notificacaoService,
      nomeAutor: nome,
      onMudou: () => setState(() {}),
    );
  }

  Future<void> _openComments(OcorrenciaModel o) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OccurrenceCommentsSheet(
        occurrence: o,
        comentarioRepository: _comentarioRepository,
        authService: _authService,
        usuarioService: _usuarioService,
        notificacaoService: _notificacaoService,
      ),
    );
    if (!mounted) return;
    // A contagem de comentários do card vem de um .count() pontual e cacheado
    // (o preview do último comentário já é reativo). Ao fechar o sheet,
    // descartamos só o cache da contagem para o card recontar — assim os novos
    // comentários (inclusive os enviados pela barra de emojis) atualizam o
    // número exibido.
    setState(() => _commentCountCache.remove(o.id));
  }

  void _openPublicProfile(
    OcorrenciaModel o, {
    required String? nomeAutor,
    required String? fotoAutor,
  }) {
    final authorId = o.usuarioId;
    if (authorId == null || o.anonima) return;
    context.push(
      Routes.perfilPublico,
      extra: PerfilPublicoArgs(
        userId: authorId,
        fallbackName: nomeAutor ?? 'Usuário',
        fallbackPhotoUrl: fotoAutor,
      ),
    );
  }

  Future<void> _gerenciarOcorrencia(OcorrenciaModel o) async {
    await showOcorrenciaActions(
      context: context,
      ocorrencia: o,
      service: _ocorrenciaRepository,
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro(e, acao: 'enviar a denúncia'))),
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
      await _ocorrenciaRepository.definirFixada(o.id, fixada: fixar);
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
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
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
                      icon: Icon(Icons.notifications_none, color: pal.ink),
                      onPressed: () => context.push(Routes.notificacoes),
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
            if (uid != null && ref.watch(isAutoridadeProvider).value == true)
              _BannerAutoridade(
                onTap: () => context.push(Routes.filaVerificacao),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchBar(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FilterButton(
                    active: _temFiltrosAvancados,
                    onTap: _abrirFiltrosAvancados,
                  ),
                ],
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

    final isAutoridade = ref.watch(isAutoridadeProvider).value == true;

    return StreamBuilder<Set<String>>(
      stream: _usuarioService.observarFavoritosIds(uid),
      initialData: const <String>{},
      builder: (context, snapshot) {
        // Denúncias anônimas não guardam usuarioId no documento público
        // (S2) — para saber "é minha denúncia" nesse caso, comparamos
        // com os ponteiros do próprio perfil, não com o campo.
        return StreamBuilder<Set<String>>(
          stream: _ocorrenciaRepository.observarMinhasDenunciasAnonimasIds(uid),
          initialData: const <String>{},
          builder: (context, minhasAnonimasSnap) {
            return _buildFeedContent(
              uid,
              snapshot.data ?? const <String>{},
              isAutoridade: isAutoridade,
              minhasDenunciasAnonimasIds:
                  minhasAnonimasSnap.data ?? const <String>{},
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
        // Cada estado recebe uma ValueKey estável para o AnimatedSwitcher só
        // animar na TROCA de estado (skeleton → conteúdo), não a cada tick de
        // dados novos (que mantêm a mesma key 'content').
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildFeedState(
            snapshot,
            uid,
            favoritosIds,
            isAutoridade: isAutoridade,
            minhasDenunciasAnonimasIds: minhasDenunciasAnonimasIds,
          ),
        );
      },
    );
  }

  Widget _buildFeedState(
    AsyncSnapshot<List<OcorrenciaModel>> snapshot,
    String? uid,
    Set<String> favoritosIds, {
    required bool isAutoridade,
    Set<String> minhasDenunciasAnonimasIds = const <String>{},
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        _cachedOccurrences.isEmpty) {
      return const FeedSkeleton(key: ValueKey('feed-skeleton'));
    }

    if (snapshot.hasError && _cachedOccurrences.isEmpty) {
      return FeedErrorState(
        key: const ValueKey('feed-error'),
        onRetry: _retryFeed,
      );
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
      key: const ValueKey('feed-content'),
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
                final isOwner =
                    uid != null &&
                    (o.anonima
                        ? minhasDenunciasAnonimasIds.contains(o.id)
                        : o.usuarioId == uid);
                final nomeAutor = o.anonima
                    ? 'Denunciante anônimo'
                    : (o.usuarioNome != null && o.usuarioNome!.trim().isNotEmpty
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
        final o = occurrences[i];
        // RepaintBoundary isola o raster de cada card: a animação do carrossel
        // (PageView + indicador) e o rebuild de um like/comentário não forçam
        // os cards vizinhos a repintar. A ValueKey preserva o elemento quando
        // as fixadas reordenam a lista.
        return RepaintBoundary(key: ValueKey(o.id), child: itemBuilder(o));
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
        style: TextStyle(
          color: context.pal.hint,
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
    final pal = context.pal;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: pal.surface,
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
        style: TextStyle(fontSize: 14, color: pal.ink),
        decoration: InputDecoration(
          hintText: 'Buscar título, descrição ou local',
          hintStyle: TextStyle(color: pal.hint, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: pal.hint, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

/// Botão que abre os filtros avançados. Ganha um ponto de destaque quando há
/// algum filtro avançado ativo (período ou ordenação != padrão).
class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: active ? pal.primary : pal.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Icon(
            Icons.tune,
            size: 20,
            color: active ? Colors.white : pal.hint,
          ),
        ),
      ),
    );
  }
}

/// Chip selecionável usado dentro do sheet de filtros avançados.
class _FiltroChoice extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FiltroChoice({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: selected ? pal.primary.withValues(alpha: 0.12) : pal.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? pal.primary : pal.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? pal.primary : pal.muted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? pal.primary : pal.ink,
                ),
              ),
            ],
          ),
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
    final pal = context.pal;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: pal.surface,
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
          dropdownColor: pal.surface,
          icon: Icon(Icons.menu, color: pal.hint, size: 20),
          hint: Text(
            'Tipo de ocorrência',
            style: TextStyle(color: pal.hint, fontSize: 14),
          ),
          style: TextStyle(fontSize: 14, color: pal.ink),
          items: [
            const DropdownMenuItem<OccurrenceType?>(
              value: null,
              child: Text('Filtrar por tipo'),
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
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : pal.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : pal.border),
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
            color: selected ? Colors.white : pal.muted,
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
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: pal.ink,
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 16,
              color: AppColors.success,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fila de verificação — toque para ver denúncias pendentes',
                style: TextStyle(
                  fontSize: 12,
                  color: pal.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: pal.surface.withValues(alpha: 0.54),
            ),
          ],
        ),
      ),
    );
  }
}
