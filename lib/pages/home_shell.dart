import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity_provider.dart';
import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/usuario_model.dart';
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

  // Stream do perfil (foto do avatar na barra), recriada só se o usuário
  // mudar — não a cada build.
  String? _perfilUid;
  Stream<UsuarioModel?>? _perfilStream;

  Stream<UsuarioModel?> _perfilDe(String uid) {
    if (_perfilUid != uid || _perfilStream == null) {
      _perfilUid = uid;
      _perfilStream = UsuarioService.instance.observarPerfil(uid);
    }
    return _perfilStream!;
  }

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
        context.push(Routes.formOcorrencia);
      }
      return;
    }

    // hasClients: o controller só tem posição quando está preso a uma lista
    // visível. Na aba Dados do cidadão e nos estados de skeleton/erro/vazio
    // do feed ele fica solto, e ler `offset` lançava StateError (registrado
    // como crash fatal ao tocar de novo na aba).
    if (i == 0) {
      if (_index == 0) {
        if (_scrollController.hasClients && _scrollController.offset > 0) {
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
        if (_scrollControllerEstatisticas.hasClients &&
            _scrollControllerEstatisticas.offset > 0) {
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
        if (_scrollControllerPerfil.hasClients &&
            _scrollControllerPerfil.offset > 0) {
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
              stream: _perfilDe(authUser.uid),
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
    final pal = context.pal;
    const height = 72.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: SafeArea(
        top: false,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: pal.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              children: [
                _buildItem(context, 0, Icons.home_rounded, Icons.home_outlined,
                    'Feed', 24.0),
                _buildItem(context, 1, Icons.location_on_rounded,
                    Icons.location_on_outlined, 'Mapa', 24.0),
                _buildBotaoCentral(context, 24.0),
                _buildItem(context, 3, Icons.library_books_rounded,
                    Icons.library_books_outlined, 'Dados', 24.0),
                _buildItemPerfil(context),
              ],
            ),
          ),
        ),
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
    final pal = context.pal;
    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: label,
        child: GestureDetector(
          onTap: () => onTap(i),
          child: Center(
            child: Container(
              width: double.infinity,
              height: 58,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              decoration: BoxDecoration(
                color: ativo
                    ? pal.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    ativo ? icon : iconAtivo,
                    size: iconSize,
                    color: ativo ? pal.primary : pal.muted,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ativo ? pal.primary : pal.muted,
                      fontSize: 11,
                      fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemPerfil(BuildContext context) {
    final ativo = currentIndex == 4;
    final pal = context.pal;
    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: 'Perfil',
        child: GestureDetector(
          onTap: () => onTap(4),
          child: Center(
            child: Container(
              width: double.infinity,
              height: 58,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              decoration: BoxDecoration(
                color: ativo
                    ? pal.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatarPerfil(),
                  const SizedBox(height: 2),
                  Text(
                    'Perfil',
                    style: TextStyle(
                      color: ativo ? pal.primary : pal.muted,
                      fontSize: 11,
                      fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildBotaoCentral(BuildContext context, double iconSize) {
    // Autoridade: atalho para a fila de verificação (selo). Cidadão: "+".
    final label =
        isAutoridade ? 'Fila de verificação e moderação' : 'Nova denúncia';
    final labelCurta = isAutoridade ? 'Fila' : 'Denunciar';
    final pal = context.pal;
    final ativo = currentIndex == 2;

    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: label,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            onTap: () => onTap(2),
            child: Container(
              width: double.infinity,
              height: 58,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              decoration: BoxDecoration(
                color: ativo
                    ? pal.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAutoridade ? Icons.fact_check_outlined : Icons.add,
                    color: ativo ? pal.primary : pal.muted,
                    size: iconSize,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    labelCurta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ativo ? pal.primary : pal.muted,
                      fontSize: 11,
                      fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
