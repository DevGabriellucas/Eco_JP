import 'package:eco_jp/pages/form_ocorrencia/controllers/location_controller.dart';
import 'package:eco_jp/services/geolocation/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // GeocodingService com http.Client real, mas os testes abaixo só exercitam
  // caminhos que NÃO tocam a rede (short-circuit por coordenadas já resolvidas
  // ou lógica puramente síncrona).
  late LocationController controller;

  setUp(() => controller = LocationController(geo: GeocodingService()));
  tearDown(() => controller.dispose());

  group('coordenadaValida', () {
    test('aceita coordenadas dentro dos limites', () {
      expect(LocationController.coordenadaValida(-7.11, -34.86), isTrue);
    });

    test('rejeita nulos, (0,0) e fora dos limites', () {
      expect(LocationController.coordenadaValida(null, -34.86), isFalse);
      expect(LocationController.coordenadaValida(-7.11, null), isFalse);
      expect(LocationController.coordenadaValida(0, 0), isFalse);
      expect(LocationController.coordenadaValida(91, 10), isFalse);
      expect(LocationController.coordenadaValida(10, 181), isFalse);
    });
  });

  group('selecionarSugestao', () {
    test('preenche endereço + coordenadas e limpa as sugestões', () {
      controller.sugestoes = const [
        EnderecoSugestao(descricao: 'A'),
        EnderecoSugestao(descricao: 'B'),
      ];
      controller.mostrarSug = true;
      var notificacoes = 0;
      controller.addListener(() => notificacoes++);

      controller.selecionarSugestao(
        const EnderecoSugestao(
          descricao: 'Rua X, João Pessoa',
          lat: -7.11,
          lon: -34.86,
        ),
      );

      expect(controller.enderecoCtrl.text, 'Rua X, João Pessoa');
      expect(controller.latitude, -7.11);
      expect(controller.longitude, -34.86);
      expect(controller.sugestoes, isEmpty);
      expect(controller.mostrarSug, isFalse);
      expect(controller.coordenadasConfirmadas, isTrue);
      expect(notificacoes, greaterThanOrEqualTo(1));
    });
  });

  group('onEnderecoChanged', () {
    test('reeditar o endereço invalida as coordenadas anteriores', () {
      // Simula uma sugestão previamente escolhida.
      controller.selecionarSugestao(
        const EnderecoSugestao(descricao: 'Rua X', lat: -7.11, lon: -34.86),
      );
      expect(controller.coordenadasConfirmadas, isTrue);

      // Texto curto (<2) não dispara busca de rede, só a limpeza síncrona.
      controller.onEnderecoChanged('');

      expect(controller.latitude, isNull);
      expect(controller.longitude, isNull);
      expect(controller.mostrarSug, isFalse);
      expect(controller.sugestoes, isEmpty);
    });
  });

  group('resolverCoordenadas', () {
    test('usa as coordenadas já resolvidas sem tocar a rede', () async {
      controller.selecionarSugestao(
        const EnderecoSugestao(descricao: 'Rua X', lat: -7.11, lon: -34.86),
      );

      final (lat, lon) = await controller.resolverCoordenadas();

      expect(lat, -7.11);
      expect(lon, -34.86);
    });
  });
}
