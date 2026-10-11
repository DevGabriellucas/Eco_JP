import 'package:eco_jp/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Pega caminho quebrado (arquivo renomeado ou subpasta fora do pubspec)
  // antes de virar ícone em branco na tela.
  for (final caminho in [
    ...AppIcons.todos,
    ...AppIllustrations.todos,
    ...AppLogos.todos,
  ]) {
    test('asset existe: $caminho', () async {
      final dados = await rootBundle.load(caminho);
      expect(dados.lengthInBytes, greaterThan(0));
    });
  }
}
