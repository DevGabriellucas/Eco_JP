import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity_provider.dart';
import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../services/usuario_service.dart';
import '../theme/app_theme.dart';
import '../utils/cloudinary_image.dart';
import '../utils/imagem_cacheada.dart';
import 'estatisticas_page.dart';
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
        return HomePage(scrollController: _scrollController);
      case 1:
        return const MapPage();
      case 3:
        return EstatisticasPage(scrollController: _scrollControllerEstatisticas);
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
        context.push(Routes.formOcorrencia);
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
      body: IndexedStack(
        index: _index,
        children: List.generate(
          5,
          (i) => _visitadas.contains(i) ? _pagina(i) : const SizedBox.shrink(),
        ),
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
    const height = 56.0;
    const padding = 8.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding, vertical: padding),
      child: SafeArea(
        top: false,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildItem(0, Icons.home_rounded, Icons.home_outlined, 'Feed', 24.0),
                _buildItem(1, Icons.location_on_rounded, Icons.location_on_outlined, 'Mapa', 24.0),
                _buildBotaoCentral(24.0),
                _buildItem(3, Icons.library_books_rounded, Icons.library_books_outlined, 'Dados', 24.0),
                _buildItemPerfil(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
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
        child: GestureDetector(
          onTap: () => onTap(i),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ativo ? const Color(0xFF888888) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemPerfil() {
    final ativo = currentIndex == 4;
    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: 'Perfil',
        child: GestureDetector(
          onTap: () => onTap(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.only(left: 28, right: 48, top: 14, bottom: 14),
                decoration: BoxDecoration(
                  color: ativo ? const Color(0xFF888888) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _buildAvatarPerfil(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPerfil() {
    if (fotoPerfilUrl != null && fotoPerfilUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFF9E9E9E),
        backgroundImage: imagemCacheada(
          cloudinaryAvatar(fotoPerfilUrl!, radius: 28),
        ),
      );
    }
    return const CircleAvatar(
      radius: 14,
      backgroundColor: Color(0xFF9E9E9E),
      child: Icon(
        Icons.account_circle_rounded,
        size: 24,
        color: Colors.white,
      ),
    );
  }

  Widget _buildBotaoCentral(double iconSize) {
    // Autoridade: atalho para a fila de verificação (selo). Cidadão: "+".
    final label = isAutoridade
        ? 'Fila de verificação e moderação'
        : 'Nova denúncia';

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: () => onTap(2),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isAutoridade ? AppColors.success : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAutoridade ? Icons.fact_check_outlined : Icons.add,
              color: isAutoridade ? Colors.white : Colors.black,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
