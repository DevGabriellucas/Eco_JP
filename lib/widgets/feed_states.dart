import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_motion.dart';

// ─────────────────────────────────────────
//  ESTADOS DO FEED
//  Skeleton (carregando), vazio e erro.
//  Compartilhados entre feed e perfil.
// ─────────────────────────────────────────

/// Lista de cards "fantasma" com animação de pulso, exibida
/// enquanto as ocorrências são carregadas do Firestore.
class FeedSkeleton extends StatefulWidget {
  final int itemCount;
  final Widget? header;

  const FeedSkeleton({super.key, this.itemCount = 4, this.header});

  @override
  State<FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<FeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.shimmerLoop,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: widget.itemCount + (widget.header == null ? 0 : 1),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (widget.header != null && index == 0) return widget.header!;
          return _SkeletonCard(progress: _controller.value);
        },
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double progress;

  const _SkeletonCard({required this.progress});

  Widget _bar({
    required double width,
    double height = 12,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-1.8 + progress * 3.6, 0),
          end: Alignment(-0.8 + progress * 3.6, 0),
          colors: const [
            AppColors.primarySoft,
            Color(0xFFF0FAF5),
            AppColors.primarySoft,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const bone = AppColors.primarySoft;
    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 18, backgroundColor: bone),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 120),
                  const SizedBox(height: 6),
                  _bar(width: 80, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Área da imagem
          Container(
            height: 320,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.8 + progress * 3.6, 0),
                end: Alignment(-0.8 + progress * 3.6, 0),
                colors: const [
                  AppColors.primarySoft,
                  Color(0xFFF0FAF5),
                  AppColors.primarySoft,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          const SizedBox(height: 14),
          _bar(width: 200, height: 14),
          const SizedBox(height: 8),
          _bar(width: double.infinity, height: 10),
          const SizedBox(height: 6),
          _bar(width: 240, height: 10),
        ],
      ),
    );
  }
}

/// Estado vazio do feed. Diferencia "ainda não há denúncias"
/// de "nenhum resultado para os filtros aplicados".
class FeedEmptyState extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback? onClearFilters;

  const FeedEmptyState({
    super.key,
    this.hasActiveFilters = false,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final title = hasActiveFilters
        ? 'Nenhum resultado encontrado'
        : 'Nenhuma denúncia por aqui ainda';
    final subtitle = hasActiveFilters
        ? 'Tente ajustar a busca ou remover os filtros aplicados.'
        : 'Seja o primeiro a registrar uma ocorrência ambiental na sua região!';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.19),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasActiveFilters ? Icons.search_off : Icons.eco_outlined,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.30),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: pal.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: pal.hint),
            ),
            if (hasActiveFilters && onClearFilters != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Limpar filtros'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de erro do feed, com ação de tentar novamente.
class FeedErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const FeedErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_outlined,
                size: 40,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Não foi possível carregar o feed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: pal.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Verifique sua conexão com a internet e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: pal.hint),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
