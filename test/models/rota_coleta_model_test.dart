import 'package:eco_jp/models/rota_coleta_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TurnoColetaParser.fromString', () {
    test('reconhece turno noturno', () {
      expect(TurnoColetaParser.fromString('noturno'), TurnoColeta.noturno);
      expect(TurnoColetaParser.fromString('Noite'), TurnoColeta.noturno);
    });

    test('valores desconhecidos caem em diurno', () {
      expect(TurnoColetaParser.fromString('diurno'), TurnoColeta.diurno);
      expect(
        TurnoColetaParser.fromString('qualquer coisa'),
        TurnoColeta.diurno,
      );
    });
  });

  group('RotaColetaModel.fromGrupoBairro', () {
    test('combina grupo + bairro, gerando id e convertendo pontos', () {
      final rota = RotaColetaModel.fromGrupoBairro(
        {
          'id': 'diaria-noturno',
          'turno': 'noturno',
          'diasSemana': [1, 2, 3, 4, 5, 6, 7],
          'horario': 'A partir das 19h',
        },
        {
          'nome': 'Centro',
          'pontos': [
            {'lat': -7.1175, 'lng': -34.8670},
            {'lat': -7.1215, 'lng': -34.8630},
          ],
        },
      );

      expect(rota.id, 'diaria-noturno-centro');
      expect(rota.bairro, 'Centro');
      expect(rota.turno, TurnoColeta.noturno);
      expect(rota.diasSemana, [1, 2, 3, 4, 5, 6, 7]);
      expect(rota.horario, 'A partir das 19h');
      expect(rota.pontos, hasLength(2));
      expect(rota.pontos.first.latitude, -7.1175);
      expect(rota.temArea, isTrue);
    });

    test('bairro sem pontos não tem área e gera id sem acentos', () {
      final rota = RotaColetaModel.fromGrupoBairro(
        {
          'id': 'ter-qui-sab-diurno',
          'turno': 'diurno',
          'diasSemana': [2, 4, 6],
          'horario': 'A partir das 7h',
        },
        {'nome': 'José Américo'},
      );

      expect(rota.id, 'ter-qui-sab-diurno-jose-americo');
      expect(rota.pontos, isEmpty);
      expect(rota.temArea, isFalse);
      expect(rota.centro, isNull);
    });
  });

  group('RotaColetaModel.descricaoDias', () {
    RotaColetaModel comDias(List<int> dias) => RotaColetaModel(
      id: 'r',
      bairro: 'Bairro',
      turno: TurnoColeta.diurno,
      diasSemana: dias,
      horario: 'A partir das 7h',
    );

    test('semana inteira vira "Diariamente"', () {
      expect(comDias([1, 2, 3, 4, 5, 6, 7]).descricaoDias, 'Diariamente');
    });

    test('dias alternados são listados com "e" no final', () {
      expect(comDias([1, 3, 5]).descricaoDias, 'Seg, Qua e Sex');
      expect(comDias([2, 4, 6]).descricaoDias, 'Ter, Qui e Sáb');
    });

    test('um único dia aparece sozinho', () {
      expect(comDias([3]).descricaoDias, 'Qua');
    });
  });

  group('RotaColetaModel.coletaHoje', () {
    test('é true quando o dia da semana atual está na lista', () {
      final hoje = DateTime.now().weekday;
      final rota = RotaColetaModel(
        id: 'r1',
        bairro: 'Bairro',
        turno: TurnoColeta.diurno,
        diasSemana: [hoje],
        horario: 'A partir das 7h',
      );

      expect(rota.coletaHoje, isTrue);
    });

    test('é false quando o dia da semana atual não está na lista', () {
      final hoje = DateTime.now().weekday;
      final outroDia = hoje == 7 ? 1 : hoje + 1;
      final rota = RotaColetaModel(
        id: 'r2',
        bairro: 'Bairro',
        turno: TurnoColeta.diurno,
        diasSemana: [outroDia],
        horario: 'A partir das 7h',
      );

      expect(rota.coletaHoje, isFalse);
    });
  });
}
