import 'package:eco_jp/utils/texto.dart';
import 'package:flutter_test/flutter_test.dart';

// Constrói caracteres invisíveis por code point — sem literais invisíveis no
// código-fonte do teste.
String cp(int c) => String.fromCharCode(c);

void main() {
  group('sanitizarTexto', () {
    test('apara espaços nas pontas', () {
      expect(sanitizarTexto('  olá  '), 'olá');
    });

    test('remove zero-width space no meio (não conta para o tamanho)', () {
      final entrada = 'a${cp(0x200B)}b${cp(0xFEFF)}c';
      expect(sanitizarTexto(entrada), 'abc');
    });

    test('remove override bidirecional (spoofing RLO)', () {
      final entrada = '${cp(0x202E)}admin${cp(0x202C)}';
      expect(sanitizarTexto(entrada), 'admin');
    });

    test('remove isolates bidirecionais', () {
      final entrada = '${cp(0x2066)}texto${cp(0x2069)}';
      expect(sanitizarTexto(entrada), 'texto');
    });

    test('remove controle C0 mas preserva \\n e \\t', () {
      final entrada = 'linha1${cp(0x00)}${cp(0x07)}\nlinha2\tfim';
      expect(sanitizarTexto(entrada), 'linha1\nlinha2\tfim');
    });

    test('remove controle C1 (0x80–0x9F)', () {
      final entrada = 'x${cp(0x85)}y';
      expect(sanitizarTexto(entrada), 'xy');
    });

    test('texto só de zero-width vira vazio (rejeitável por tamanho)', () {
      final entrada = '${cp(0x200B)}${cp(0x200C)}${cp(0x200D)}';
      expect(sanitizarTexto(entrada), '');
    });

    test('preserva acentos e emoji legítimos', () {
      expect(sanitizarTexto('Ação 🌱 João'), 'Ação 🌱 João');
    });
  });

  group('sanitizarLinhaUnica', () {
    test('troca quebras de linha por espaço e colapsa espaços', () {
      expect(sanitizarLinhaUnica('a\n\nb   c\td'), 'a b c d');
    });

    test('também remove invisíveis', () {
      final entrada = 'Rua${cp(0x200B)}  das   Flores';
      expect(sanitizarLinhaUnica(entrada), 'Rua das Flores');
    });
  });
}
