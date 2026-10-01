import 'package:eco_jp/services/rota_coleta_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('carrega o cronograma do asset (assets/data/ declarado no pubspec)',
      () async {
    // Falha com "Unable to load asset" se assets/data/ sair do pubspec.yaml —
    // o erro que deixava o guia de coleta vazio em produção.
    final rotas = await RotaColetaService().carregarRotas();
    expect(rotas, isNotEmpty);
    expect(rotas.every((r) => r.bairro.trim().isNotEmpty), isTrue);
  });
}
