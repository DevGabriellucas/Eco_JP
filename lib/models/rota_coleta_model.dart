import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/texto.dart';

// ─────────────────────────────────────────
//  AGENDA DE COLETA DE LIXO POR BAIRRO
//  Dias da semana e turno divulgados pela
//  Emlur. Bairros conhecidos têm área
//  aproximada no mapa; os demais são
//  localizados sob demanda por geocodificação.
// ─────────────────────────────────────────

/// A Emlur divulga a coleta domiciliar por bairro distinguindo apenas o
/// turno (diurno, a partir das 7h, ou noturno, a partir das 19h). Não há
/// agenda pública de coleta seletiva/orgânica por bairro.
enum TurnoColeta { diurno, noturno }

extension TurnoColetaInfo on TurnoColeta {
  String get label {
    switch (this) {
      case TurnoColeta.diurno:
        return 'Coleta diurna';
      case TurnoColeta.noturno:
        return 'Coleta noturna';
    }
  }

  Color get color {
    switch (this) {
      case TurnoColeta.diurno:
        return const Color(0xFFF59E0B);
      case TurnoColeta.noturno:
        return const Color(0xFF4338CA);
    }
  }

  IconData get icon {
    switch (this) {
      case TurnoColeta.diurno:
        return Icons.wb_sunny_outlined;
      case TurnoColeta.noturno:
        return Icons.nights_stay_outlined;
    }
  }
}

extension TurnoColetaParser on TurnoColeta {
  static TurnoColeta fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'noturno':
      case 'noite':
        return TurnoColeta.noturno;
      default:
        return TurnoColeta.diurno;
    }
  }
}

/// Nomes abreviados dos dias da semana, indexados por [DateTime.weekday]
/// (1 = segunda ... 7 = domingo). O índice 0 não é usado.
const diasSemanaAbrev = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// Agenda de coleta de um bairro em um grupo do cronograma da Emlur
/// (frequência + turno).
///
/// [pontos] é opcional: quando preenchido (2+ pontos), o app desenha a área
/// aproximada do bairro como uma linha no mapa. Quando vazio, o bairro só
/// existe na consulta por texto e sua posição é resolvida sob demanda via
/// geocodificação no aparelho do usuário.
class RotaColetaModel {
  final String id;
  final String bairro;
  final TurnoColeta turno;

  /// Dias em que a coleta ocorre, no formato de [DateTime.weekday]
  /// (1 = segunda ... 7 = domingo).
  final List<int> diasSemana;

  final String horario;
  final List<LatLng> pontos;

  const RotaColetaModel({
    required this.id,
    required this.bairro,
    required this.turno,
    required this.diasSemana,
    required this.horario,
    this.pontos = const [],
  });

  /// Constrói a agenda de um bairro a partir de um grupo do JSON (que carrega
  /// turno/dias/horário) e do item do bairro (nome e pontos opcionais).
  factory RotaColetaModel.fromGrupoBairro(
    Map<String, dynamic> grupo,
    Map<String, dynamic> bairro,
  ) {
    final nome = bairro['nome'] as String;
    final pontosRaw = bairro['pontos'] as List?;

    return RotaColetaModel(
      id: '${grupo['id']}-${slugify(nome)}',
      bairro: nome,
      turno: TurnoColetaParser.fromString(grupo['turno'] as String),
      diasSemana: (grupo['diasSemana'] as List).map((e) => e as int).toList(),
      horario: grupo['horario'] as String,
      pontos: pontosRaw == null
          ? const []
          : pontosRaw
                .map(
                  (p) => LatLng(
                    (p['lat'] as num).toDouble(),
                    (p['lng'] as num).toDouble(),
                  ),
                )
                .toList(),
    );
  }

  /// `true` quando há uma área desenhável no mapa (linha entre 2+ pontos).
  bool get temArea => pontos.length >= 2;

  /// Se a coleta passa nesse bairro hoje (com base na data do aparelho).
  bool get coletaHoje => diasSemana.contains(DateTime.now().weekday);

  /// Descrição amigável dos dias de coleta. Ex.: "Diariamente",
  /// "Seg, Qua e Sex", "Ter, Qui e Sáb".
  String get descricaoDias {
    if (diasSemana.length >= 7) return 'Diariamente';
    final nomes = diasSemana.map((d) => diasSemanaAbrev[d]).toList();
    if (nomes.length == 1) return nomes.first;
    final inicio = nomes.sublist(0, nomes.length - 1).join(', ');
    return '$inicio e ${nomes.last}';
  }

  /// Ponto central da área (média dos pontos). Retorna `null` quando o bairro
  /// não tem área desenhada.
  LatLng? get centro {
    if (pontos.isEmpty) return null;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in pontos) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pontos.length, lng / pontos.length);
  }
}
