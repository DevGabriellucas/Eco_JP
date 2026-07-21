import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity_provider.dart';
import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../theme/app_theme.dart';
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

  // Abas já abertas. Só elas são instanciadas (lazy): assim Mapa,
  // Estatísticas e Perfil — e os listeners do Firestore deles — só ligam
  // quando o usuário toca pela primeira vez. O IndexedStack mantém vivas as
  // já visitadas para preservar o estado ao alternar entre elas.
  final Set<int> _visitadas = {0};

  // Autoridade não cria denúncia: o botão central vira atalho para a fila
  // de verificação. Cidadão comum mantém o "+" para registrar denúncia.
  // Espelha o valor mais recente do provider para uso fora do build (em
  // _onTapItem, que roda a partir de um callback, não de um rebuild).
  bool _isAutoridade = false;

  // Índices: 0=Feed, 1=Mapa, (2 é o botão +), 3=Dados, 4=Perfil
  Widget _pagina(int i) {
    switch (i) {
      case 0:
        return const HomePage();
      case 1:
        return const MapPage();
      case 3:
        return const EstatisticasPage();
      case 4:
        return const PerfilPage();
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
    // Espelha o valor mais recente do provider no campo, para que _onTapItem
    // (chamado a partir de um callback do bottom nav, fora do build) leia o
    // papel atual sem precisar de outro ref.watch fora da árvore de widgets.
    _isAutoridade = ref.watch(isAutoridadeProvider).value ?? false;

    // Enquanto o provider não emite, assume online (evita piscar o aviso).
    final online = ref.watch(conexaoOnlineProvider).value ?? true;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(
          5,
          (i) => _visitadas.contains(i) ? _pagina(i) : const SizedBox.shrink(),
        ),
      ),
      // Banner de offline fica acima da barra de navegação: assim não conflita
      // com a AppBar/SafeArea de cada página.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BannerOffline(visivel: !online),
          _BottomNav(
            currentIndex: _index,
            onTap: _onTapItem,
            isAutoridade: _isAutoridade,
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

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.isAutoridade,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(top: BorderSide(color: pal.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(0, Icons.home_rounded, Icons.home, 'Feed', pal),
              _item(1, Icons.location_on_rounded, Icons.location_on, 'Mapa', pal),
              _botaoCentral(pal),
              _item(3, Icons.library_books_rounded, Icons.library_books, 'Dados', pal),
              _item(4, Icons.account_circle_rounded, Icons.account_circle, 'Perfil', pal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    int i,
    IconData icon,
    IconData iconAtivo,
    String label,
    AppPalette pal,
  ) {
    final ativo = currentIndex == i;
    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        label: label,
        child: InkWell(
          onTap: () => onTap(i),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ativo ? iconAtivo : icon,
                size: 24,
                color: ativo ? pal.ink : pal.hint,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
                  color: ativo ? pal.ink : pal.hint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoCentral(AppPalette pal) {
    // Autoridade: atalho para a fila de verificação (selo). Cidadão: "+".
    final label = isAutoridade
        ? 'Fila de verificação e moderação'
        : 'Nova denúncia';
    return Expanded(
      child: Center(
        child: Semantics(
          button: true,
          label: label,
          child: Tooltip(
            message: label,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isAutoridade ? AppColors.success : pal.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAutoridade ? Icons.fact_check_outlined : Icons.add_circle_rounded,
                  color: isAutoridade ? Colors.white : pal.surface,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
