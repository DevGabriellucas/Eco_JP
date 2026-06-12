import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';
import '../services/ocorrencia_service.dart';
import '../widgets/feed_states.dart';
import '../widgets/occurrence_card.dart';
import '../widgets/ocorrencia_actions.dart';
import 'detalhe_ocorrencia_page.dart';
import 'notificacoes_page.dart';

// ─────────────────────────────────────────
//  HOME PAGE
// ─────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final _ocorrenciaService = OcorrenciaService();
  final _authService = AuthService();
  final _notificacaoService = NotificacaoService();

  late Stream<List<OcorrenciaModel>> _feedStream;

  OccurrenceType? _selectedType;
  OccurrenceStatus? _selectedStatus;
  String _searchQuery = '';

  final Map<String, String> _nomeCache  = {};
  final Map<String, String?> _fotoCache = {};

  @override
  void initState() {
    super.initState();
    _feedStream = _ocorrenciaService.listarOcorrencias();
  }

  bool get _hasActiveFilters =>
      _selectedType != null || _selectedStatus != null || _searchQuery.isNotEmpty;

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
      _feedStream = _ocorrenciaService.listarOcorrencias();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _carregarDadosAutor(List<OcorrenciaModel> ocorrencias) {
    final missingIds = ocorrencias
        .where((o) =>
            o.usuarioId != null &&
            (o.usuarioNome == null || o.usuarioNome!.trim().isEmpty) &&
            !_nomeCache.containsKey(o.usuarioId))
        .map((o) => o.usuarioId!)
        .toSet();

    for (final uid in missingIds) {
      _nomeCache[uid] = '';
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get()
          .then((doc) {
        if (!mounted) return;
        final data  = doc.data();
        final nome  = (data?['nome'] as String?)?.trim();
        final foto  = data?['fotoUrl'] as String?;
        String resolved;
        if (nome != null && nome.isNotEmpty) {
          resolved = nome;
        } else if (uid == _authService.currentUser?.uid) {
          resolved = _authService.currentUser?.email?.split('@').first ?? 'Usuário';
        } else {
          resolved = 'Usuário';
        }
        setState(() {
          _nomeCache[uid]  = resolved;
          _fotoCache[uid]  = foto?.isNotEmpty == true ? foto : null;
        });
      });
    }
  }

  List<OcorrenciaModel> _applyFilters(List<OcorrenciaModel> ocorrencias) {
    return ocorrencias.where((o) {
      final matchesSearch = _searchQuery.isEmpty ||
          o.localizacao.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.titulo.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == null ||
          OccurrenceTypeParser.fromString(o.tipoLixo) == _selectedType;
      final matchesStatus = _selectedStatus == null ||
          OccurrenceStatusParser.fromString(o.status) == _selectedStatus;
      return matchesSearch && matchesType && matchesStatus;
    }).toList();
  }

  void _toggleLike(OcorrenciaModel o) {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final vaiCurtir = !o.userLiked;
    _ocorrenciaService.toggleLike(o.id, uid);
    if (vaiCurtir && o.usuarioId != null && o.usuarioId != uid) {
      final eu = _authService.currentUser;
      final nome = eu?.displayName ?? eu?.email?.split('@').first ?? 'Alguém';
      _notificacaoService.notificar(
        donoId: o.usuarioId!,
        tipo: 'curtida',
        deUsuarioNome: nome,
        ocorrenciaId: o.id,
        ocorrenciaTitulo: o.titulo,
      );
    }
  }

  void _toggleDislike(OcorrenciaModel o) {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    _ocorrenciaService.toggleDislike(o.id, uid);
  }

  void _openDetail(OcorrenciaModel o) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalheOcorrenciaPage(occurrence: o)),
    );
  }

  Future<void> _gerenciarOcorrencia(OcorrenciaModel o) async {
    await showOcorrenciaActions(
      context: context,
      ocorrencia: o,
      service: _ocorrenciaService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser?.uid;
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
              'Feed',
              style: TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
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
                      icon: const Icon(Icons.notifications_none,
                          color: Color(0xFF1A1A1A)),
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
                            color: Color(0xFFEF4444),
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
          child: Divider(height: 1, color: Color(0xFFD8D8D8)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SearchBar(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            const SizedBox(height: 10),

            // ── Type filter dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TypeDropdown(
                selected: _selectedType,
                onChanged: (v) => setState(() => _selectedType = v),
              ),
            ),

            const SizedBox(height: 10),

            // ── Status chip filters
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _StatusChip(
                    label: 'Todos',
                    selected: _selectedStatus == null,
                    color: const Color(0xFF6B7280),
                    onTap: () => setState(() => _selectedStatus = null),
                  ),
                  ...OccurrenceStatus.values.map(
                    (s) => _StatusChip(
                      label: s.label,
                      selected: _selectedStatus == s,
                      color: s.color,
                      onTap: () => setState(() =>
                          _selectedStatus = _selectedStatus == s ? null : s),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Feed em tempo real
            Expanded(
              child: StreamBuilder<List<OcorrenciaModel>>(
                stream: _feedStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const FeedSkeleton();
                  }
                  if (snapshot.hasError) {
                    return FeedErrorState(onRetry: _retryFeed);
                  }
                  final all = snapshot.data ?? [];
                  _carregarDadosAutor(all);
                  final filtradas = _applyFilters(all);
                  if (filtradas.isEmpty) {
                    return FeedEmptyState(
                      hasActiveFilters: _hasActiveFilters,
                      onClearFilters: _clearFilters,
                    );
                  }
                  final uid = _authService.currentUser?.uid;
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtradas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final o = filtradas[i];
                      final isOwner = uid != null && o.usuarioId == uid;
                      final nomeAutor = (o.usuarioNome != null && o.usuarioNome!.trim().isNotEmpty)
                          ? o.usuarioNome!
                          : (_nomeCache[o.usuarioId]?.isNotEmpty == true ? _nomeCache[o.usuarioId] : null);
                      final fotoAutor = (o.usuarioFotoUrl != null && o.usuarioFotoUrl!.isNotEmpty)
                          ? o.usuarioFotoUrl
                          : _fotoCache[o.usuarioId];
                      return OccurrenceCard(
                        occurrence: o,
                        nomeAutor: nomeAutor,
                        fotoAutor: fotoAutor,
                        onLike: () => _toggleLike(o),
                        onDislike: () => _toggleDislike(o),
                        onTap: () => _openDetail(o),
                        onManage: isOwner ? () => _gerenciarOcorrencia(o) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SEARCH BAR
// ─────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
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
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Filtrar localização',
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFFAAAAAA), size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TYPE DROPDOWN
// ─────────────────────────────────────────

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
        color: Colors.white,
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
          icon: const Icon(Icons.menu, color: Color(0xFFAAAAAA), size: 20),
          hint: const Text(
            'Tipo de ocorrência',
            style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
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
                    Text(
                      t.label,
                      style: TextStyle(color: t.color),
                    ),
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

// ─────────────────────────────────────────
//  STATUS CHIP
// ─────────────────────────────────────────

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
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFFE0E0E0),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
