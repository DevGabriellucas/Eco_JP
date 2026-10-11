import 'package:eco_jp/models/occurrence_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OccurrenceTypeParser.fromString', () {
    test('reconhece variações de lixo e resíduos', () {
      expect(OccurrenceTypeParser.fromString('Lixo'), OccurrenceType.lixo);
      expect(
        OccurrenceTypeParser.fromString('descarte de resíduos'),
        OccurrenceType.lixo,
      );
      expect(
        OccurrenceTypeParser.fromString('RESIDUO solido'),
        OccurrenceType.lixo,
      );
    });

    test('reconhece queimada com e sem acento', () {
      expect(
        OccurrenceTypeParser.fromString('Queimada'),
        OccurrenceType.queimada,
      );
      expect(
        OccurrenceTypeParser.fromString('incêndio na mata'),
        OccurrenceType.queimada,
      );
      expect(
        OccurrenceTypeParser.fromString('incendio'),
        OccurrenceType.queimada,
      );
    });

    test('reconhece árvores caídas, enchentes, esgoto e iluminação', () {
      expect(
        OccurrenceTypeParser.fromString('árvore caída na rua'),
        OccurrenceType.arvoresCaidas,
      );
      expect(
        OccurrenceTypeParser.fromString('alagamento'),
        OccurrenceType.enchentes,
      );
      expect(
        OccurrenceTypeParser.fromString('Esgoto a céu aberto'),
        OccurrenceType.esgoto,
      );
      expect(
        OccurrenceTypeParser.fromString('falta iluminacao'),
        OccurrenceType.faltaIluminacao,
      );
    });

    test('valor desconhecido cai em outros', () {
      expect(
        OccurrenceTypeParser.fromString('problema misterioso'),
        OccurrenceType.outros,
      );
      expect(OccurrenceTypeParser.fromString(''), OccurrenceType.outros);
    });
  });

  group('OccurrenceStatusParser.fromString', () {
    test('"não resolvido" tem precedência sobre "resolvido"', () {
      expect(
        OccurrenceStatusParser.fromString('Não resolvido'),
        OccurrenceStatus.unresolved,
      );
      expect(
        OccurrenceStatusParser.fromString('nao resolvido'),
        OccurrenceStatus.unresolved,
      );
    });

    test('resolvido e concluído mapeiam para resolved', () {
      expect(
        OccurrenceStatusParser.fromString('Resolvido'),
        OccurrenceStatus.resolved,
      );
      expect(
        OccurrenceStatusParser.fromString('concluído'),
        OccurrenceStatus.resolved,
      );
    });

    test('pendente ou desconhecido cai em inProgress', () {
      expect(
        OccurrenceStatusParser.fromString('Pendente'),
        OccurrenceStatus.inProgress,
      );
      expect(
        OccurrenceStatusParser.fromString('qualquer coisa'),
        OccurrenceStatus.inProgress,
      );
    });
  });

  group('Labels dos enums', () {
    test('todos os tipos têm label não vazio', () {
      for (final t in OccurrenceType.values) {
        expect(t.label, isNotEmpty);
      }
    });

    test('todos os status têm label não vazio', () {
      for (final s in OccurrenceStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });
}
