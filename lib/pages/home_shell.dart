import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/role_service.dart';
import '../theme/app_theme.dart';
import 'estatisticas_page.dart';
import 'fila_moderacao_page.dart';
import 'fila_verificacao_page.dart';
import 'home_page.dart';
import 'mapPage/map_page.dart';
import 'perfil/perfil_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Abas já abertas. Só elas são instanciadas (lazy): assim Mapa,
  // Estatísticas e Perfil — e os listeners do Firestore deles — só ligam
  // quando o usuário toca pela primeira vez. O IndexedStack mantém vivas as
  // já visitadas para preservar o estado ao alternar entre elas.
  final Set<int> _visitadas = {0};

  final _roleService = RoleService();
  final _authService = AuthService();

  // Autoridade não cria denúncia: o botão central vira atalho para a fila
  // de verificação. Cidadão comum mantém o "+" para registrar denúncia.
  bool _isAutoridade = false;

  @override
  void initState() {
    super.initState();
    _checarPapel();
  }

  Future<void> _checarPapel() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final isAut = await _roleService.isAutoridade(uid);
    if (mounted) setState(() => _isAutoridade = isAut);
  }

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
        Navigator.of(context).pushNamed('/form-ocorrencia');
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
      backgroundColor: AppColors.surface,
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.fact_check_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Fila de verificação'),
              subtitle: const Text('Verificar e triar denúncias ambientais'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FilaVerificacaoPage(),
                  ),
                );
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FilaModeracaoPage()),
                );
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
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(
          5,
          (i) => _visitadas.contains(i) ? _pagina(i) : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onTap: _onTapItem,
        isAutoridade: _isAutoridade,
      ),
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(0, Icons.home_outlined, Icons.home, 'Feed'),
              _item(1, Icons.map_outlined, Icons.map, 'Mapa'),
              _botaoCentral(),
              _item(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Dados'),
              _item(4, Icons.person_outline, Icons.person, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, IconData iconAtivo, String label) {
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
                color: ativo ? AppColors.ink : AppColors.hint,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
                  color: ativo ? AppColors.ink : AppColors.hint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoCentral() {
    // Autoridade: atalho para a fila de verificação (selo). Cidadão: "+".
    final label = isAutoridade ? 'Fila de verificação e moderação' : 'Nova denúncia';
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
                  color: isAutoridade ? AppColors.success : AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAutoridade ? Icons.fact_check_outlined : Icons.add,
                  color: Colors.white,
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
