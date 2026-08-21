import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
        return const Color(0xFF8B5CF6);
      case OccurrenceType.enchentes:
        return const Color(0xFF1D4ED8);
      case OccurrenceType.esgoto:
        return AppColors.success;
      case OccurrenceType.faltaIluminacao:
        return const Color(0xFFEC4899);
      case OccurrenceType.lixo:
        return AppColors.warning;
      case OccurrenceType.queimada:
        return AppColors.danger;
      case OccurrenceType.outros:
        return const Color(0xFF06B6D4);
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
    if (normalized.contains('lixo') ||
        normalized.contains('resíduo') ||
        normalized.contains('residuo')) {
      return OccurrenceType.lixo;
    }
    if (normalized.contains('queimada') ||
        normalized.contains('incêndio') ||
        normalized.contains('incendio')) {
      return OccurrenceType.queimada;
    }
    if (normalized.contains('buraco')) {
      return OccurrenceType.buraco;
    }
    if (normalized.contains('árvore') ||
        normalized.contains('arvore') ||
        normalized.contains('caída') ||
        normalized.contains('caida')) {
      return OccurrenceType.arvoresCaidas;
    }
    if (normalized.contains('enchente') || normalized.contains('alagamento')) {
      return OccurrenceType.enchentes;
    }
    if (normalized.contains('esgoto')) {
      return OccurrenceType.esgoto;
    }
    if (normalized.contains('iluminação') ||
        normalized.contains('iluminacao')) {
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
        return 'Pendente';
      case OccurrenceStatus.unresolved:
        return 'Não resolvido';
    }
  }

  Color get color {
    switch (this) {
      case OccurrenceStatus.resolved:
        return AppColors.success;
      case OccurrenceStatus.inProgress:
        return const Color(0xFF9CA3AF);
      case OccurrenceStatus.unresolved:
        return AppColors.danger;
    }
  }

  IconData get icon {
    switch (this) {
      case OccurrenceStatus.resolved:
        return Icons.check;
      case OccurrenceStatus.inProgress:
        return Icons.schedule;
      case OccurrenceStatus.unresolved:
        return Icons.close;
    }
  }
}

// ─────────────────────────────────────────
//  STATUS OFICIAL (autoridade)
//  Triagem antes da confirmação final.
// ─────────────────────────────────────────

enum StatusOficial { emAnalise, naoConfirmada, encaminhada, resolvida }

extension StatusOficialInfo on StatusOficial {
  String get valor {
    switch (this) {
      case StatusOficial.emAnalise:
        return 'em_analise';
      case StatusOficial.naoConfirmada:
        return 'nao_confirmada';
      case StatusOficial.encaminhada:
        return 'encaminhada';
      case StatusOficial.resolvida:
        return 'resolvida';
    }
  }

  String get label {
    switch (this) {
      case StatusOficial.emAnalise:
        return 'Em análise';
      case StatusOficial.naoConfirmada:
        return 'Não confirmada';
      case StatusOficial.encaminhada:
        return 'Encaminhada';
      case StatusOficial.resolvida:
        return 'Resolvida';
    }
  }

  Color get color {
    switch (this) {
      case StatusOficial.emAnalise:
        return AppColors.warning;
      case StatusOficial.naoConfirmada:
        return AppColors.danger;
      case StatusOficial.encaminhada:
        return const Color(0xFF3B82F6);
      case StatusOficial.resolvida:
        return AppColors.success;
    }
  }

  IconData get icon {
    switch (this) {
      case StatusOficial.emAnalise:
        return Icons.search;
      case StatusOficial.naoConfirmada:
        return Icons.cancel_outlined;
      case StatusOficial.encaminhada:
        return Icons.send;
      case StatusOficial.resolvida:
        return Icons.check_circle;
    }
  }

  static StatusOficial? fromString(String? value) {
    switch (value) {
      case 'em_analise':
        return StatusOficial.emAnalise;
      case 'nao_confirmada':
        return StatusOficial.naoConfirmada;
      case 'encaminhada':
        return StatusOficial.encaminhada;
      case 'resolvida':
        return StatusOficial.resolvida;
      default:
        return null;
    }
  }
}

// ─────────────────────────────────────────
//  ESTÁGIO OFICIAL (visão unificada)
//  Combina `verificada` + `statusOficial` em um único estágio do ciclo de
//  triagem, usado para exibir um selo coerente no feed, na fila e no detalhe.
// ─────────────────────────────────────────

enum EstagioOficial {
  pendente,
  emAnalise,
  naoConfirmada,
  confirmada,
  encaminhada,
  resolvida,
}

extension EstagioOficialInfo on EstagioOficial {
  /// Deriva o estágio a partir dos campos persistidos da ocorrência.
  static EstagioOficial calcular(bool verificada, StatusOficial? statusOficial) {
    if (verificada) {
      if (statusOficial == StatusOficial.resolvida) {
        return EstagioOficial.resolvida;
      }
      if (statusOficial == StatusOficial.encaminhada) {
        return EstagioOficial.encaminhada;
      }
      return EstagioOficial.confirmada;
    }
    if (statusOficial == StatusOficial.emAnalise) {
      return EstagioOficial.emAnalise;
    }
    if (statusOficial == StatusOficial.naoConfirmada) {
      return EstagioOficial.naoConfirmada;
    }
    return EstagioOficial.pendente;
  }

  String get label {
    switch (this) {
      case EstagioOficial.pendente:
        return 'Pendente';
      case EstagioOficial.emAnalise:
        return 'Em análise';
      case EstagioOficial.naoConfirmada:
        return 'Não confirmada';
      case EstagioOficial.confirmada:
        return 'Verificada';
      case EstagioOficial.encaminhada:
        return 'Encaminhada';
      case EstagioOficial.resolvida:
        return 'Resolvida';
    }
  }

  Color get color {
    switch (this) {
      case EstagioOficial.pendente:
        return const Color(0xFF9CA3AF);
      case EstagioOficial.emAnalise:
        return AppColors.warning;
      case EstagioOficial.naoConfirmada:
        return AppColors.danger;
      case EstagioOficial.confirmada:
        return AppColors.success;
      case EstagioOficial.encaminhada:
        return const Color(0xFF3B82F6);
      case EstagioOficial.resolvida:
        return AppColors.successStrong;
    }
  }

  IconData get icon {
    switch (this) {
      case EstagioOficial.pendente:
        return Icons.schedule;
      case EstagioOficial.emAnalise:
        return Icons.search;
      case EstagioOficial.naoConfirmada:
        return Icons.cancel_outlined;
      case EstagioOficial.confirmada:
        return Icons.verified;
      case EstagioOficial.encaminhada:
        return Icons.send;
      case EstagioOficial.resolvida:
        return Icons.check_circle;
    }
  }

  /// Estágios que representam ação oficial já tomada (não-pendente).
  bool get temAcaoOficial => this != EstagioOficial.pendente;
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
