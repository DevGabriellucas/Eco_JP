import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/utils/reacao_ocorrencia.dart';
import 'package:flutter_test/flutter_test.dart';

OcorrenciaModel novaOcorrencia() => OcorrenciaModel(
  id: 'occ1',
  titulo: 'Buraco na rua',
  descricao: 'Buraco grande e perigoso.',
  localizacao: 'Centro',
  latitude: -7.11,
  longitude: -34.86,
  tipoLixo: 'Buraco',
);

void main() {
  const uid = 'user1';

  group('aplicarLikeOtimista', () {
    test('curte do zero: liga userLiked, +1 like, adiciona uid', () {
      final o = novaOcorrencia();
      aplicarLikeOtimista(o, uid);
      expect(o.userLiked, isTrue);
      expect(o.likes, 1);
      expect(o.likedBy, contains(uid));
    });

    test('clicar de novo desfaz o like', () {
      final o = novaOcorrencia();
      aplicarLikeOtimista(o, uid);
      aplicarLikeOtimista(o, uid);
      expect(o.userLiked, isFalse);
      expect(o.likes, 0);
      expect(o.likedBy, isNot(contains(uid)));
    });

    test('curtir quando já tinha descurtido troca dislike -> like', () {
      final o = novaOcorrencia();
      aplicarDislikeOtimista(o, uid);
      aplicarLikeOtimista(o, uid);
      expect(o.userLiked, isTrue);
      expect(o.userDisliked, isFalse);
      expect(o.likes, 1);
      expect(o.dislikes, 0);
      expect(o.likedBy, contains(uid));
      expect(o.dislikedBy, isNot(contains(uid)));
    });
  });

  group('aplicarDislikeOtimista', () {
    test('descurte do zero: liga userDisliked, +1 dislike', () {
      final o = novaOcorrencia();
      aplicarDislikeOtimista(o, uid);
      expect(o.userDisliked, isTrue);
      expect(o.dislikes, 1);
      expect(o.dislikedBy, contains(uid));
    });

    test('descurtir quando já tinha curtido troca like -> dislike', () {
      final o = novaOcorrencia();
      aplicarLikeOtimista(o, uid);
      aplicarDislikeOtimista(o, uid);
      expect(o.userDisliked, isTrue);
      expect(o.userLiked, isFalse);
      expect(o.dislikes, 1);
      expect(o.likes, 0);
    });

    test('like e dislike nunca coexistem para o mesmo usuário', () {
      final o = novaOcorrencia();
      aplicarLikeOtimista(o, uid);
      aplicarDislikeOtimista(o, uid);
      aplicarLikeOtimista(o, uid);
      expect(o.userLiked && o.userDisliked, isFalse);
      expect(o.likedBy.contains(uid) && o.dislikedBy.contains(uid), isFalse);
    });
  });

  group('ReacaoSnapshot', () {
    test('restaura o estado anterior após uma mudança otimista', () {
      final o = novaOcorrencia();
      aplicarLikeOtimista(o, uid); // estado "curtido"
      final snap = ReacaoSnapshot.de(o);

      // Simula uma mudança que precisará ser revertida.
      aplicarDislikeOtimista(o, uid);
      expect(o.userDisliked, isTrue);

      snap.restaurarEm(o);
      expect(o.userLiked, isTrue);
      expect(o.userDisliked, isFalse);
      expect(o.likes, 1);
      expect(o.dislikes, 0);
      expect(o.likedBy, contains(uid));
    });

    test('snapshot copia as listas (não referencia as originais)', () {
      final o = novaOcorrencia();
      aplicarLikeOtimista(o, uid);
      final snap = ReacaoSnapshot.de(o);
      o.likedBy.add('outro'); // muta a lista viva
      // A cópia do snapshot não deve ter sido afetada.
      expect(snap.likedBy, contains(uid));
      expect(snap.likedBy, isNot(contains('outro')));
    });
  });
}
