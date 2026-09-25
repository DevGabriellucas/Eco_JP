import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity_provider.dart';
import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../services/usuario_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../utils/cloudinary_image.dart';
import '../utils/imagem_cacheada.dart';
import '../widgets/shared/app_icons.dart';
import 'estatisticas_page.dart';
import 'form_ocorrencia_page.dart';
import 'home_page.dart';
import 'mapPage/map_page.dart';
import 'perfil/perfil_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  late ScrollController _scrollController;
  late ScrollController _scrollControllerEstatisticas;
  late ScrollController _scrollControllerPerfil;

  final Set<int> _visitadas = {0};

  bool _isAutoridade = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollControllerEstatisticas = ScrollController();
    _scrollControllerPerfil = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollControllerEstatisticas.dispose();
    _scrollControllerPerfil.dispose();
    super.dispose();
  }

  // Índices: 0=Feed, 1=Mapa, (2 é o botão +), 3=Dados, 4=Perfil
  Widget _pagina(int i) {
    switch (i) {
      case 0:
        return HomePage(
          scrollController: _scrollController,
          onOpenMap: () => _onTapItem(1),
          onOpenProfile: () => _onTapItem(4),
          onCreateOccurrence: () => _onTapItem(2),
        );
      case 1:
        return const MapPage();
      case 3:
        return EstatisticasPage(
            scrollController: _scrollControllerEstatisticas);
      case 4:
        return PerfilPage(scrollController: _scrollControllerPerfil);
      default:
        return const SizedBox.shrink();
    }
  }

  void _onTapItem(int i) {
    if (i == 2) {
      if (_isAutoridade) {
        _abrirMenuAutoridade();
      } else {
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            transitionDuration: AppMotion.slow,
            reverseTransitionDuration: AppMotion.base,
            pageBuilder: (_, animation, secondaryAnimation) =>
                const FormOcorrenciaPage(),
            transitionsBuilder: (_, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: AppMotion.curveEnter,
                reverseCurve: AppMotion.curveExit,
              );
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(opacity: curved, child: child),
              );
            },
          ),
        );
      }
      return;
    }

    if (i == 0) {
      if (_index == 0) {
        if (_scrollController.offset > 0) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        } else {
          setState(() {});
        }
      } else {
        setState(() {
          _index = i;
          _visitadas.add(i);
        });
      }
      return;
    }

    if (i == 3) {
      if (_index == 3) {
        if (_scrollControllerEstatisticas.offset > 0) {
          _scrollControllerEstatisticas.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      } else {
        setState(() {
          _index = i;
          _visitadas.add(i);
        });
      }
      return;
    }

    if (i == 4) {
      if (_index == 4) {
        if (_scrollControllerPerfil.offset > 0) {
          _scrollControllerPerfil.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      } else {
        setState(() {
          _index = i;
          _visitadas.add(i);
        });
      }
      return;
    }

    setState(() {
      _index = i;
      _visitadas.add(i);
    });
  }

  // Autoridade escolhe entre a fila de verificação de denúncias e a fila de
  // moderação de conteúdo abusivo.
  void _abrirMenuAutoridade() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.pal.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.pal.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.fact_check_outlined,
                color: context.pal.primary,
              ),
              title: const Text('Fila de verificação'),
              subtitle: const Text('Verificar e triar denúncias ambientais'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(Routes.filaVerificacao);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.report_gmailerrorred_outlined,
                color: AppColors.danger,
              ),
              title: const Text('Fila de moderação'),
              subtitle: const Text('Denúncias de conteúdo abusivo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(Routes.filaModeracao);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isAutoridade = ref.watch(isAutoridadeProvider).value ?? false;
    final online = ref.watch(conexaoOnlineProvider).value ?? true;

    final authUser = ref.watch(authStateChangesProvider).value;
    final usuarioService = UsuarioService();

    // Quando a fila de verificação pede foco em uma denúncia, troca para a aba
    // do feed (o próprio feed faz o scroll/destaque e limpa o provider).
    ref.listen(feedFocoOcorrenciaProvider, (anterior, atual) {
      if (atual != null && _index != 0) {
        setState(() {
          _index = 0;
          _visitadas.add(0);
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [0, 1, 3, 4].map((i) {
          final active = _index == i;
          return Positioned.fill(
            child: IgnorePointer(
              ignoring: !active,
              child: TickerMode(
                enabled: active,
                child: active && _visitadas.contains(i)
                    ? KeyedSubtree(key: ValueKey(i), child: _pagina(i))
                    : const SizedBox.shrink(),
              ),
            ),
          );
        }).toList(),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BannerOffline(visivel: !online),
          if (authUser != null)
            StreamBuilder(
              stream: usuarioService.observarPerfil(authUser.uid),
              builder: (context, perfilSnap) {
                final fotoUrl = perfilSnap.data?.fotoUrl;
                return _BottomNav(
                  currentIndex: _index,
                  onTap: _onTapItem,
                  isAutoridade: _isAutoridade,
                  isCompressed: false,
                  fotoPerfilUrl: fotoUrl,
                );
              },
            )
          else
            _BottomNav(
              currentIndex: _index,
              onTap: _onTapItem,
              isAutoridade: _isAutoridade,
              isCompressed: false,
              fotoPerfilUrl: null,
            ),
        ],
      ),
    );
  }
}

/// Aviso fino de que o app está sem conexão e mostrando dados salvos. Anima a
/// entrada/saída para não "pular" a tela quando a conexão oscila.
class _BannerOffline extends StatelessWidget {
  final bool visivel;

  const _BannerOffline({required this.visivel});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: visivel
          ? Container(
              width: double.infinity,
              color: AppColors.warning.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 15, color: pal.muted),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Sem conexão — mostrando dados salvos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pal.muted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAutoridade;
  final bool isCompressed;
  final String? fotoPerfilUrl;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.isAutoridade,
    this.isCompressed = false,
    this.fotoPerfilUrl,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final capsuleColor = dark
        ? const Color(0xE6193428)
        : const Color(0xE6E8F7EF);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: capsuleColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                _buildItem(
                  context,
                  0,
                  AppIcons.homeActive,
                  AppIcons.home,
                  'Início',
                  24,
                ),
                _buildItem(
                  context,
                  1,
                  AppIcons.mapActive,
                  AppIcons.map,
                  'Mapa',
                  24,
                ),
                _buildBotaoCentral(context, 24),
                _buildItem(
                  context,
                  3,
                  AppIcons.dataActive,
                  AppIcons.data,
                  'Dados',
                  24,
                ),
                _buildItemPerfil(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navContent({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool ativo,
    required double iconSize,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = dark ? const Color(0xFF70E6A6) : AppColors.primary;
    final inactiveColor = dark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF456353);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: ativo
            ? (dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.78))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: ativo ? activeColor : inactiveColor),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
              color: ativo ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    int i,
    IconData icon,
    IconData iconAtivo,
    String label,
    double iconSize,
  ) {
    final ativo = currentIndex == i;
    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: label,
        child: _PressableNavTap(
          onTap: () => onTap(i),
          child: Center(
            child: _navContent(
              context: context,
              icon: ativo ? icon : iconAtivo,
              label: label,
              ativo: ativo,
              iconSize: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemPerfil(BuildContext context) {
    final ativo = currentIndex == 4;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = dark ? const Color(0xFF70E6A6) : AppColors.primary;
    final inactiveColor = dark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF456353);
    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: 'Perfil',
        child: _PressableNavTap(
          onTap: () => onTap(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: ativo
                  ? (dark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.78))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAvatarPerfil(context, ativo),
                const SizedBox(height: 3),
                Text(
                  'Perfil',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                    color: ativo ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPerfil(BuildContext context, bool ativo) {
    if (fotoPerfilUrl != null && fotoPerfilUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: ativo ? AppColors.primary : context.pal.surfaceAlt,
        backgroundImage: imagemCacheada(
          cloudinaryAvatar(fotoPerfilUrl!, radius: 28),
        ),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: ativo ? AppColors.primary : context.pal.surfaceAlt,
      child: Icon(
        ativo ? AppIcons.profileActive : AppIcons.profile,
        size: 24,
        color: Colors.white,
      ),
    );
  }

  Widget _buildBotaoCentral(BuildContext context, double iconSize) {
    // Autoridade: atalho para a fila de verificação (selo). Cidadão: "+".
    final label =
        isAutoridade ? 'Fila de verificação e moderação' : 'Nova denúncia';

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: _PressableNavTap(
          onTap: () => onTap(2),
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, -5),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.24),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      isAutoridade ? Icons.fact_check_outlined : AppIcons.add,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -3),
                  child: Text(
                    isAutoridade ? 'Fila' : 'Denunciar',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF70E6A6)
                          : AppColors.primary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableNavTap extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableNavTap({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
