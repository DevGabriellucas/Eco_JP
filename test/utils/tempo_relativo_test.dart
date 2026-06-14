import 'package:eco_jp/utils/tempo_relativo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Referência fixa para os testes não dependerem do relógio real.
  final agora = DateTime(2026, 6, 13, 12, 0, 0);

  group('tempoRelativo', () {
    test('data nula retorna string vazia', () {
      expect(tempoRelativo(null, agora: agora), '');
    });

    test('menos de 1 minuto retorna "agora"', () {
      expect(
        tempoRelativo(
          agora.subtract(const Duration(seconds: 30)),
          agora: agora,
        ),
        'agora',
      );
    });

    test('data no futuro retorna "agora"', () {
      expect(
        tempoRelativo(agora.add(const Duration(minutes: 5)), agora: agora),
        'agora',
      );
    });

    test('minutos', () {
      expect(
        tempoRelativo(agora.subtract(const Duration(minutes: 5)), agora: agora),
        'há 5 min',
      );
    });

    test('horas', () {
      expect(
        tempoRelativo(agora.subtract(const Duration(hours: 3)), agora: agora),
        'há 3 h',
      );
    });

    test('ontem', () {
      expect(
        tempoRelativo(agora.subtract(const Duration(days: 1)), agora: agora),
        'ontem',
      );
    });

    test('dias dentro da semana', () {
      expect(
        tempoRelativo(agora.subtract(const Duration(days: 3)), agora: agora),
        'há 3 dias',
      );
    });

    test('mais de uma semana usa data absoluta', () {
      expect(
        tempoRelativo(agora.subtract(const Duration(days: 10)), agora: agora),
        '03/06/2026',
      );
    });
  });

  group('grupoPorData', () {
    test('data nula cai em "Mais antigas"', () {
      expect(grupoPorData(null, agora: agora), 'Mais antigas');
    });

    test('mesmo dia é "Hoje"', () {
      expect(
        grupoPorData(agora.subtract(const Duration(hours: 2)), agora: agora),
        'Hoje',
      );
    });

    test('dia anterior é "Ontem"', () {
      expect(grupoPorData(DateTime(2026, 6, 12, 23, 0), agora: agora), 'Ontem');
    });

    test('dentro da semana é "Esta semana"', () {
      expect(
        grupoPorData(DateTime(2026, 6, 9, 10, 0), agora: agora),
        'Esta semana',
      );
    });

    test('mais de uma semana é "Mais antigas"', () {
      expect(
        grupoPorData(DateTime(2026, 6, 1, 10, 0), agora: agora),
        'Mais antigas',
      );
    });
  });
}
