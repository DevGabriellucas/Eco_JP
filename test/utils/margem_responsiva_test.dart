import 'package:eco_jp/utils/margem_responsiva.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double margem(double largura) =>
      margemResponsiva(largura, margemMinima: 24, larguraMaxima: 440);

  test('celular: mantém a margem mínima', () {
    expect(margem(360), 24);
    expect(margem(412), 24);
  });

  test('exatamente no limite: margem mínima', () {
    expect(margem(488), 24);
  });

  test('tablet: centraliza o conteúdo na largura máxima', () {
    expect(margem(800), 180);
    expect(800 - 2 * margem(800), 440);
  });
}
