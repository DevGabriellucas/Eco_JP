import 'package:eco_jp/utils/texto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('removerAcentos', () {
    test('remove diacríticos mantendo as letras', () {
      expect(removerAcentos('João'), 'Joao');
      expect(removerAcentos('ação'), 'acao');
      expect(removerAcentos('Çedilha ÀÉÍÓÚ'), 'Cedilha AEIOU');
    });

    test('preserva texto sem acento', () {
      expect(removerAcentos('Centro 123'), 'Centro 123');
    });
  });

  group('slugify', () {
    test('gera kebab-case sem acentos', () {
      expect(slugify('Cidade Verde (Mangabeira)'), 'cidade-verde-mangabeira');
      expect(slugify('João Pessoa'), 'joao-pessoa');
    });

    test('remove hifens das pontas e colapsa separadores', () {
      expect(slugify('  --Bairro!!  do   Sol--  '), 'bairro-do-sol');
    });

    test('string sem caracteres válidos vira vazio', () {
      expect(slugify('!!! ??? ...'), '');
    });
  });
}
