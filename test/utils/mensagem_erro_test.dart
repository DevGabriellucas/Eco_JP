import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_jp/services/cloudinary_service.dart';
import 'package:eco_jp/services/rate_limiter.dart';
import 'package:eco_jp/utils/mensagem_erro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mensagemErro', () {
    test('rate limit informa o tempo de espera', () {
      final msg = mensagemErro(
        const RateLimitException(Duration(seconds: 4)),
        acao: 'enviar a denúncia',
      );
      expect(msg, contains('5s')); // segundosRestantes = inSeconds + 1
      expect(msg, contains('rápido demais'));
    });

    test('erro de upload do Cloudinary fala em imagem', () {
      final msg = mensagemErro(
        const CloudinaryUploadException('falhou'),
        acao: 'enviar a denúncia',
      );
      expect(msg, contains('imagem'));
    });

    test('permission-denied usa a ação no texto', () {
      final msg = mensagemErro(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        acao: 'excluir o comentário',
      );
      expect(msg, contains('permissão'));
      expect(msg, contains('excluir o comentário'));
    });

    test('unavailable vira mensagem de offline', () {
      final msg = mensagemErro(
        FirebaseException(plugin: 'firestore', code: 'unavailable'),
        acao: 'salvar o perfil',
      );
      expect(msg.toLowerCase(), contains('conexão'));
    });

    test('unauthenticated fala em sessão expirada', () {
      final msg = mensagemErro(
        FirebaseException(plugin: 'firestore', code: 'unauthenticated'),
        acao: 'curtir',
      );
      expect(msg.toLowerCase(), contains('sessão'));
    });

    test('código desconhecido cai no fallback com a ação', () {
      final msg = mensagemErro(
        FirebaseException(plugin: 'firestore', code: 'algo-inesperado'),
        acao: 'enviar a denúncia',
      );
      expect(msg, 'Não foi possível enviar a denúncia. Tente novamente.');
    });

    test('erro totalmente desconhecido cai no fallback', () {
      final msg = mensagemErro(Exception('boom'), acao: 'salvar o perfil');
      expect(msg, 'Não foi possível salvar o perfil. Tente novamente.');
    });
  });
}
