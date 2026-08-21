import 'package:flutter/material.dart';

/// Uma dica de reciclagem: como separar e descartar um tipo de material.
/// Conteúdo educativo estático (não depende de rede nem de dados do usuário).
class DicaReciclagem {
  final String titulo;
  final IconData icone;
  final Color cor;

  /// Instrução curta de como preparar/descartar o material.
  final String descarte;

  /// Exemplos do dia a dia que se encaixam nesse tipo.
  final List<String> exemplos;

  const DicaReciclagem({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.descarte,
    required this.exemplos,
  });
}

/// Guia rápido de separação de resíduos, seguindo as cores usuais da coleta
/// seletiva brasileira (CONAMA): vermelho=plástico, azul=papel, verde=vidro,
/// amarelo=metal, marrom=orgânico. Eletrônicos e óleo têm descarte especial.
const List<DicaReciclagem> dicasReciclagem = [
  DicaReciclagem(
    titulo: 'Plástico',
    icone: Icons.local_drink_outlined,
    cor: Color(0xFFEF4444),
    descarte:
        'Lave, seque e amasse para ocupar menos espaço. As tampas podem ir '
        'junto.',
    exemplos: ['Garrafas PET', 'Embalagens', 'Sacolas', 'Potes'],
  ),
  DicaReciclagem(
    titulo: 'Papel',
    icone: Icons.description_outlined,
    cor: Color(0xFF3B82F6),
    descarte:
        'Mantenha seco e limpo. Papel engordurado ou molhado não é reciclável.',
    exemplos: ['Jornais', 'Caixas', 'Papelão', 'Revistas'],
  ),
  DicaReciclagem(
    titulo: 'Vidro',
    icone: Icons.wine_bar_outlined,
    cor: Color(0xFF22C55E),
    descarte:
        'Enxágue antes de descartar. Embale cacos em jornal grosso para '
        'evitar acidentes.',
    exemplos: ['Garrafas', 'Potes', 'Frascos'],
  ),
  DicaReciclagem(
    titulo: 'Metal',
    icone: Icons.recycling_outlined,
    cor: Color(0xFFF59E0B),
    descarte:
        'Lave para remover restos de comida e amasse as latas de alumínio.',
    exemplos: ['Latas', 'Alumínio', 'Tampas'],
  ),
  DicaReciclagem(
    titulo: 'Orgânico',
    icone: Icons.eco_outlined,
    cor: Color(0xFF92400E),
    descarte:
        'Ideal para compostagem doméstica — vira adubo natural para as plantas.',
    exemplos: ['Restos de comida', 'Cascas', 'Borra de café'],
  ),
  DicaReciclagem(
    titulo: 'Eletrônico',
    icone: Icons.devices_other_outlined,
    cor: Color(0xFF8B5CF6),
    descarte:
        'Nunca jogue no lixo comum! Leve a pontos de coleta especiais — '
        'contêm metais tóxicos.',
    exemplos: ['Pilhas', 'Baterias', 'Celulares', 'Cabos'],
  ),
  DicaReciclagem(
    titulo: 'Óleo de cozinha',
    icone: Icons.water_drop_outlined,
    cor: Color(0xFFCA8A04),
    descarte:
        'Guarde em garrafa PET e leve a um ponto de coleta. Nunca despeje na '
        'pia — polui a água.',
    exemplos: ['Óleo de fritura', 'Gordura'],
  ),
];
