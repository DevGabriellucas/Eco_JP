import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CloudinaryConfigException implements Exception {
  final String message;

  const CloudinaryConfigException(this.message);

  @override
  String toString() => message;
}

class CloudinaryUploadException implements Exception {
  final String message;

  const CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}

class CloudinaryService {
  // Cloud name e unsigned upload preset sao configuracoes publicas do app.
  // Nunca coloque API Secret aqui. Para outro ambiente, sobrescreva com:
  //   --dart-define=CLOUDINARY_CLOUD_NAME=...
  //   --dart-define=CLOUDINARY_UPLOAD_PRESET=...
  static const String _envCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dmdghbgac',
  );
  static const String _envUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'Eco_JP',
  );

  final String _cloudName;
  final String _uploadPreset;
  final http.Client _client;

  /// [cloudName] e [uploadPreset] sao injetaveis para testes.
  /// Em runtime, usam o padrao do EcoJP ou valores passados via --dart-define.
  CloudinaryService({
    http.Client? client,
    String? cloudName,
    String? uploadPreset,
  }) : _client = client ?? http.Client(),
       _cloudName = cloudName ?? _envCloudName,
       _uploadPreset = uploadPreset ?? _envUploadPreset;

  bool get isConfigured =>
      _cloudName.trim().isNotEmpty && _uploadPreset.trim().isNotEmpty;

  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!isConfigured) {
      throw const CloudinaryConfigException(
        'Configure CLOUDINARY_CLOUD_NAME e CLOUDINARY_UPLOAD_PRESET.',
      );
    }

    final request =
        http.MultipartRequest(
            'POST',
            Uri.https('api.cloudinary.com', '/v1_1/$_cloudName/image/upload'),
          )
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: safeFileName(fileName),
            ),
          );

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : null;

      throw CloudinaryUploadException(
        message ?? 'Erro ao enviar imagem para o Cloudinary.',
      );
    }

    final secureUrl = json['secure_url'];

    if (secureUrl is! String || secureUrl.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary nao retornou a URL segura da imagem.',
      );
    }

    return secureUrl;
  }

  @visibleForTesting
  String safeFileName(String fileName) {
    final sanitized = fileName.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );

    if (sanitized.isEmpty || !sanitized.contains('.')) {
      return 'ocorrencia.jpg';
    }

    return sanitized;
  }
}
