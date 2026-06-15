import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'estatisticas_page.dart';
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
      Navigator.of(context).pushNamed('/form-ocorrencia');
      return;
    }
    setState(() {
      _index = i;
      _visitadas.add(i);
    });
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
      bottomNavigationBar: _BottomNav(currentIndex: _index, onTap: _onTapItem),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

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
    );
  }

  Widget _botaoCentral() {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: () => onTap(2),
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
