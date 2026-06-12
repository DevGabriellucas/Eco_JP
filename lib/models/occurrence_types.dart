import 'package:flutter/material.dart';

// ─────────────────────────────────────────
//  TIPOS E STATUS DE OCORRÊNCIA
//  Enums compartilhados por feed, mapa,
//  estatísticas, detalhes e perfil.
// ─────────────────────────────────────────

enum OccurrenceStatus { resolved, inProgress, unresolved }

enum OccurrenceType {
  lixo,
  queimada,
  buraco,
  arvoresCaidas,
  enchentes,
  esgoto,
  faltaIluminacao,
  outros,
}

extension OccurrenceTypeLabel on OccurrenceType {
  String get label {
    switch (this) {
      case OccurrenceType.lixo:
        return 'Lixo';
      case OccurrenceType.queimada:
        return 'Queimada';
      case OccurrenceType.buraco:
        return 'Buraco';
      case OccurrenceType.arvoresCaidas:
        return 'Árvores caídas';
      case OccurrenceType.enchentes:
        return 'Enchentes';
      case OccurrenceType.esgoto:
        return 'Esgoto';
      case OccurrenceType.faltaIluminacao:
        return 'Falta iluminação';
      case OccurrenceType.outros:
        return 'Outros';
    }
  }

  IconData get icon {
    switch (this) {
      case OccurrenceType.lixo:
        return Icons.delete_outline;
      case OccurrenceType.queimada:
        return Icons.local_fire_department_outlined;
      case OccurrenceType.buraco:
        return Icons.warning_amber_outlined;
      case OccurrenceType.arvoresCaidas:
        return Icons.park_outlined;
      case OccurrenceType.enchentes:
        return Icons.water_outlined;
      case OccurrenceType.esgoto:
        return Icons.water_damage;
      case OccurrenceType.faltaIluminacao:
        return Icons.lightbulb_outline;
      case OccurrenceType.outros:
        return Icons.help_outline;
    }
  }

  Color get color {
    switch (this) {
      case OccurrenceType.arvoresCaidas:
        return const Color(0xFFFFE066);
      case OccurrenceType.buraco:
        return const Color(0xFF111827);
      case OccurrenceType.enchentes:
        return const Color(0xFF1D4ED8);
      case OccurrenceType.esgoto:
        return const Color(0xFF22C55E);
      case OccurrenceType.faltaIluminacao:
        return const Color(0xFFEC4899);
      case OccurrenceType.lixo:
        return const Color(0xFFF97316);
      case OccurrenceType.queimada:
        return const Color(0xFFEF4444);
      case OccurrenceType.outros:
        return const Color(0xFF6B7280);
    }
  }

  /// Matiz aproximada do marcador no Google Maps (limitado a matizes/hues,
  /// por isso não reproduz exatamente as cores RGB acima).
  double get markerHue {
    switch (this) {
      case OccurrenceType.lixo:
        return 30;
      case OccurrenceType.queimada:
        return 0;
      case OccurrenceType.buraco:
        return 270;
      case OccurrenceType.arvoresCaidas:
        return 60;
      case OccurrenceType.enchentes:
        return 220;
      case OccurrenceType.esgoto:
        return 120;
      case OccurrenceType.faltaIluminacao:
        return 330;
      case OccurrenceType.outros:
        return 200;
    }
  }
}

extension OccurrenceTypeParser on OccurrenceType {
  static OccurrenceType fromString(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.contains('lixo') || normalized.contains('resíduo') || normalized.contains('residuo')) {
      return OccurrenceType.lixo;
    }
    if (normalized.contains('queimada') || normalized.contains('incêndio') || normalized.contains('incendio')) {
      return OccurrenceType.queimada;
    }
    if (normalized.contains('buraco')) {
      return OccurrenceType.buraco;
    }
    if (normalized.contains('árvore') || normalized.contains('arvore') || normalized.contains('caída') || normalized.contains('caida')) {
      return OccurrenceType.arvoresCaidas;
    }
    if (normalized.contains('enchente') || normalized.contains('alagamento')) {
      return OccurrenceType.enchentes;
    }
    if (normalized.contains('esgoto')) {
      return OccurrenceType.esgoto;
    }
    if (normalized.contains('iluminação') || normalized.contains('iluminacao')) {
      return OccurrenceType.faltaIluminacao;
    }
    return OccurrenceType.outros;
  }
}

extension OccurrenceStatusLabel on OccurrenceStatus {
  String get label {
    switch (this) {
      case OccurrenceStatus.resolved:
        return 'Concluído';
      case OccurrenceStatus.inProgress:
        return 'Em andamento';
      case OccurrenceStatus.unresolved:
        return 'Não resolvido';
    }
  }

  Color get color {
    switch (this) {
      case OccurrenceStatus.resolved:
        return const Color(0xFF22C55E);
      case OccurrenceStatus.inProgress:
        return const Color(0xFFF97316);
      case OccurrenceStatus.unresolved:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case OccurrenceStatus.resolved:
        return Icons.check;
      case OccurrenceStatus.inProgress:
        return Icons.more_horiz;
      case OccurrenceStatus.unresolved:
        return Icons.close;
    }
  }
}

extension OccurrenceStatusParser on OccurrenceStatus {
  static OccurrenceStatus fromString(String value) {
    final normalized = value.toLowerCase().trim();
    // "Não resolvido" precisa ser checado antes de "resol" (que casaria com resolvido).
    if (normalized.contains('não resol') ||
        normalized.contains('nao resol') ||
        normalized.contains('não conclu') ||
        normalized.contains('nao conclu')) {
      return OccurrenceStatus.unresolved;
    }
    if (normalized.contains('resol') || normalized.contains('conclu')) {
      return OccurrenceStatus.resolved;
    }
    return OccurrenceStatus.inProgress;
  }
}
