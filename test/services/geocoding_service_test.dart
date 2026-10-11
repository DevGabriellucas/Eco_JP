import 'dart:convert';

import 'package:eco_jp/services/geolocation/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeocodingService.reverseGeocode', () {
    http.Response json(Object corpo, [int status = 200]) => http.Response(
          jsonEncode(corpo),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    test('usa o Nominatim quando ele traz rua e bairro', () async {
      final geo = GeocodingService(
        client: MockClient((req) async {
          expect(req.url.host, 'nominatim.openstreetmap.org');
          return json({
            'address': {
              'road': 'Avenida Epitácio Pessoa',
              'suburb': 'Tambauzinho',
              'city': 'João Pessoa',
            },
          });
        }),
      );

      final r = await geo.reverseGeocode(-7.12, -34.85);

      expect(r?.endereco, 'Avenida Epitácio Pessoa, Tambauzinho, João Pessoa');
      expect(r?.bairro, 'Tambauzinho');
    });

    test('cai no Photon quando o Nominatim recusa', () async {
      final hosts = <String>[];
      final geo = GeocodingService(
        client: MockClient((req) async {
          hosts.add(req.url.host);
          if (req.url.host == 'nominatim.openstreetmap.org') {
            return json({'error': 'blocked'}, 403);
          }
          return json({
            'features': [
              {
                'properties': {
                  'street': 'Rua das Trincheiras',
                  'district': 'Centro',
                  'city': 'João Pessoa',
                },
              },
            ],
          });
        }),
      );

      final r = await geo.reverseGeocode(-7.12, -34.88);

      expect(hosts, ['nominatim.openstreetmap.org', 'photon.komoot.io']);
      expect(r?.endereco, 'Rua das Trincheiras, Centro, João Pessoa');
      expect(r?.bairro, 'Centro');
    });

    test('só a cidade não conta como endereço', () async {
      final geo = GeocodingService(
        client: MockClient((req) async {
          if (req.url.host == 'nominatim.openstreetmap.org') {
            return json({
              'address': {'city': 'João Pessoa'},
            });
          }
          return json({'features': <Object>[]});
        }),
      );

      expect(await geo.reverseGeocode(-7.12, -34.88), isNull);
    });
  });
}
