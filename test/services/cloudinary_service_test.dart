import 'dart:convert';
import 'dart:typed_data';

import 'package:eco_jp/services/cloudinary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  group('CloudinaryService.isConfigured', () {
    test('false quando cloud name ou preset estão vazios', () {
      final service = CloudinaryService(cloudName: '', uploadPreset: '');
      expect(service.isConfigured, isFalse);
    });

    test('true quando ambos estão preenchidos', () {
      final service = CloudinaryService(
        cloudName: 'demo',
        uploadPreset: 'preset',
      );
      expect(service.isConfigured, isTrue);
    });
  });

  group('CloudinaryService.uploadImage', () {
    test('lança CloudinaryConfigException sem configuração', () {
      final service = CloudinaryService(cloudName: '', uploadPreset: '');

      expect(
        () => service.uploadImage(bytes: bytes, fileName: 'foto.jpg'),
        throwsA(isA<CloudinaryConfigException>()),
      );
    });

    test('retorna secure_url em upload bem-sucedido', () async {
      final mock = MockClient.streaming((request, bodyStream) async {
        expect(request.url.host, 'api.cloudinary.com');
        expect(request.url.path, contains('/demo/image/upload'));
        final body = jsonEncode({
          'secure_url': 'https://res.cloudinary.com/demo/foto.jpg',
        });
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      });

      final service = CloudinaryService(
        client: mock,
        cloudName: 'demo',
        uploadPreset: 'preset',
      );

      final url = await service.uploadImage(bytes: bytes, fileName: 'foto.jpg');

      expect(url, 'https://res.cloudinary.com/demo/foto.jpg');
    });

    test(
      'lança CloudinaryUploadException com mensagem da API em erro',
      () async {
        final mock = MockClient.streaming((request, bodyStream) async {
          final body = jsonEncode({
            'error': {'message': 'Upload preset inválido'},
          });
          return http.StreamedResponse(Stream.value(utf8.encode(body)), 400);
        });

        final service = CloudinaryService(
          client: mock,
          cloudName: 'demo',
          uploadPreset: 'preset',
        );

        expect(
          () => service.uploadImage(bytes: bytes, fileName: 'foto.jpg'),
          throwsA(
            isA<CloudinaryUploadException>().having(
              (e) => e.message,
              'message',
              'Upload preset inválido',
            ),
          ),
        );
      },
    );
  });

  group('CloudinaryService.safeFileName', () {
    final service = CloudinaryService(
      cloudName: 'demo',
      uploadPreset: 'preset',
    );

    test('remove caracteres especiais e espaços', () {
      expect(
        service.safeFileName('minha foto (1)!.jpg'),
        'minha_foto__1__.jpg',
      );
    });

    test('usa fallback para nomes vazios ou sem extensão', () {
      expect(service.safeFileName(''), 'ocorrencia.jpg');
      expect(service.safeFileName('semextensao'), 'ocorrencia.jpg');
    });
  });
}
