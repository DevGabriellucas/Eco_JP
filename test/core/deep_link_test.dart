import 'package:eco_jp/core/deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ocorrenciaIdFromUri', () {
    test('formato com host: ecojp://ocorrencia/<id>', () {
      expect(ocorrenciaIdFromUri(Uri.parse('ecojp://ocorrencia/abc123')),
          'abc123');
    });

    test('formato com path: ecojp:///ocorrencia/<id>', () {
      expect(ocorrenciaIdFromUri(Uri.parse('ecojp:///ocorrencia/abc123')),
          'abc123');
    });

    test('ida e volta com deepLinkOcorrencia', () {
      expect(ocorrenciaIdFromUri(Uri.parse(deepLinkOcorrencia('xyz'))), 'xyz');
    });

    test('outro esquema ou sem id devolve null', () {
      expect(ocorrenciaIdFromUri(Uri.parse('https://ocorrencia/abc')), isNull);
      expect(ocorrenciaIdFromUri(Uri.parse('ecojp://ocorrencia')), isNull);
      expect(ocorrenciaIdFromUri(Uri.parse('ecojp://perfil/abc')), isNull);
    });
  });
}
