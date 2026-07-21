import 'package:eco_jp/utils/cloudinary_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rawUpload =
      'https://res.cloudinary.com/dmdghbgac/image/upload/v1699999999/Eco_JP/foto.jpg';

  group('cloudinaryOtimizada', () {
    test('injeta f_auto,q_auto,c_limit,w_ logo após /upload/', () {
      final r = cloudinaryOtimizada(rawUpload, larguraLogica: 400);
      expect(
        r,
        'https://res.cloudinary.com/dmdghbgac/image/upload/'
        'f_auto,q_auto,c_limit,w_400/v1699999999/Eco_JP/foto.jpg',
      );
    });

    test('escala a largura pelo devicePixelRatio', () {
      final r = cloudinaryOtimizada(
        rawUpload,
        larguraLogica: 400,
        devicePixelRatio: 3,
      );
      expect(r, contains('w_1200'));
    });

    test('com altura usa c_fill e adiciona h_ e g_auto', () {
      final r = cloudinaryOtimizada(
        rawUpload,
        larguraLogica: 60,
        alturaLogica: 60,
        crop: 'fill',
      );
      expect(r, contains('c_fill'));
      expect(r, contains('w_60'));
      expect(r, contains('h_60'));
      expect(r, contains('g_auto'));
    });

    test('é idempotente — URL já otimizada volta inalterada', () {
      final uma = cloudinaryOtimizada(rawUpload, larguraLogica: 400);
      final duas = cloudinaryOtimizada(uma, larguraLogica: 800);
      expect(duas, uma);
    });

    test('URL que não é do Cloudinary volta intacta', () {
      const google = 'https://lh3.googleusercontent.com/a/foto=s96-c';
      expect(cloudinaryOtimizada(google, larguraLogica: 96), google);
    });

    test('URL do Cloudinary sem /upload/ volta intacta', () {
      const estranha = 'https://res.cloudinary.com/dmdghbgac/raw/v1/x.json';
      expect(cloudinaryOtimizada(estranha, larguraLogica: 400), estranha);
    });

    test('funciona para URL sem segmento de versão', () {
      const semVersao =
          'https://res.cloudinary.com/dmdghbgac/image/upload/Eco_JP/foto.jpg';
      final r = cloudinaryOtimizada(semVersao, larguraLogica: 200);
      expect(
        r,
        'https://res.cloudinary.com/dmdghbgac/image/upload/'
        'f_auto,q_auto,c_limit,w_200/Eco_JP/foto.jpg',
      );
    });

    test('limita a largura mínima e máxima (clamp 16..2000)', () {
      final mini = cloudinaryOtimizada(rawUpload, larguraLogica: 1);
      expect(mini, contains('w_16'));
      final maxi = cloudinaryOtimizada(
        rawUpload,
        larguraLogica: 5000,
        devicePixelRatio: 3,
      );
      expect(maxi, contains('w_2000'));
    });
  });

  group('cloudinaryAvatar', () {
    test('pede imagem quadrada a 3x do raio', () {
      final r = cloudinaryAvatar(rawUpload, radius: 46);
      // 46 * 2 * 3 = 276
      expect(r, contains('w_276'));
      expect(r, contains('h_276'));
      expect(r, contains('c_fill'));
    });

    test('não toca em URL de fora do Cloudinary', () {
      const google = 'https://lh3.googleusercontent.com/a/foto=s96-c';
      expect(cloudinaryAvatar(google, radius: 20), google);
    });
  });

  group('cacheLarguraPx', () {
    test('converte px lógicos para físicos com o dpr', () {
      expect(cacheLarguraPx(100, 2), 200);
    });

    test('aplica o mesmo clamp 16..2000', () {
      expect(cacheLarguraPx(1, 1), 16);
      expect(cacheLarguraPx(5000, 3), 2000);
    });
  });
}
