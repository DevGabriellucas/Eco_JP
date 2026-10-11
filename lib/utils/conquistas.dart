import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Uma conquista (badge) do perfil. Fica desbloqueada quando [progresso]
/// atinge [meta]. Enquanto isso, o card mostra o progresso atual.
class Conquista {
  final String titulo;
  final String descricao;
  final IconData icone;
  final Color cor;
  final int progresso;
  final int meta;

  const Conquista({
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.progresso,
    required this.meta,
  });

  bool get desbloqueada => progresso >= meta;
}

/// Calcula as conquistas do usuário a partir das estatísticas já derivadas do
/// perfil (denúncias, resolvidas oficialmente, curtidas recebidas) e do papel
/// de autoridade. Ordem: desbloqueadas antes das pendentes, para o perfil
/// destacar o que já foi conquistado.
List<Conquista> calcularConquistas({
  required int denuncias,
  required int resolvidas,
  required int curtidas,
  required bool isAutoridade,
}) {
  final lista = <Conquista>[
    Conquista(
      titulo: 'Primeira voz',
      descricao: 'Registrou a primeira denúncia',
      icone: Icons.campaign_outlined,
      cor: AppColors.primary,
      progresso: denuncias,
      meta: 1,
    ),
    Conquista(
      titulo: 'Guardião ativo',
      descricao: '5 denúncias registradas',
      icone: Icons.eco_outlined,
      cor: AppColors.primary,
      progresso: denuncias,
      meta: 5,
    ),
    Conquista(
      titulo: 'Vigilante',
      descricao: '25 denúncias registradas',
      icone: Icons.visibility_outlined,
      cor: AppColors.primary,
      progresso: denuncias,
      meta: 25,
    ),
    Conquista(
      titulo: 'Impacto real',
      descricao: 'Uma denúncia resolvida pela autoridade',
      icone: Icons.verified_outlined,
      cor: AppColors.success,
      progresso: resolvidas,
      meta: 1,
    ),
    Conquista(
      titulo: 'Transformador',
      descricao: '5 denúncias resolvidas',
      icone: Icons.auto_awesome_outlined,
      cor: AppColors.success,
      progresso: resolvidas,
      meta: 5,
    ),
    Conquista(
      titulo: 'Voz da comunidade',
      descricao: '50 curtidas recebidas',
      icone: Icons.favorite_outline,
      cor: AppColors.danger,
      progresso: curtidas,
      meta: 50,
    ),
    if (isAutoridade)
      const Conquista(
        titulo: 'Verificador',
        descricao: 'Autoridade que verifica denúncias da comunidade',
        icone: Icons.shield_outlined,
        cor: AppColors.success,
        progresso: 1,
        meta: 1,
      ),
  ];

  lista.sort((a, b) {
    if (a.desbloqueada == b.desbloqueada) return 0;
    return a.desbloqueada ? -1 : 1;
  });
  return lista;
}
