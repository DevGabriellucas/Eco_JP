import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final String descricao;

  const PlaceholderPage({
    super.key,
    required this.titulo,
    required this.icone,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            const Text(
              'EcoJP',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              titulo,
              style: const TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFD8D8D8)),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 72, color: const Color(0xFFBDBDBD)),
            const SizedBox(height: 20),
            const Text(
              'Em breve',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                descricao,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8A8A8A),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
