import 'package:flutter/material.dart';

import 'estatisticas_page.dart';
import 'home_page.dart';
import 'perfil/perfil_page.dart';
import 'mapPage/map_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Índices: 0=Feed, 1=Mapa, (2 é o botão +), 3=Stats, 4=Perfil
  final _paginas = const [
    HomePage(),
    MapPage(),
    SizedBox.shrink(), // slot do botão central (nunca exibido)
    EstatisticasPage(),
    PerfilPage(),
  ];

  void _onTapItem(int i) {
    if (i == 2) {
      // botão central: abre o formulário de nova denúncia
      Navigator.of(context).pushNamed('/form-ocorrencia');
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _paginas),
      bottomNavigationBar: _BottomNav(currentIndex: _index, onTap: _onTapItem),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _text = Color(0xFF1A1A1A);
  static const _hint = Color(0xFF9E9E9E);
  static const _border = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
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
              _item(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
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
              color: ativo ? _text : _hint,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
                color: ativo ? _text : _hint,
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
              color: _text,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
