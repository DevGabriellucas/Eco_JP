import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_jp/models/occurrence_types.dart';
import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcorrenciaModel.toMap', () {
    test('contadores de reação sempre começam zerados', () {
      final model = OcorrenciaModel(
        id: 'abc',
        titulo: 'Lixo acumulado',
        descricao: 'Descarte irregular na esquina',
        localizacao: 'Bessa, João Pessoa',
        latitude: -7.0931,
        longitude: -34.8400,
        tipoLixo: 'Lixo',
        likes: 99, // mesmo que o objeto tenha valores,
        dislikes: 99, // o toMap deve zerar para criação
      );

      final map = model.toMap();

      expect(map['likes'], 0);
      expect(map['dislikes'], 0);
      expect(map['comments'], 0);
      expect(map['likedBy'], isEmpty);
      expect(map['dislikedBy'], isEmpty);
      expect(map['status'], 'Pendente');
    });
  });

  group('OcorrenciaModel.fromMap', () {
    Map<String, dynamic> baseMap() => {
      'titulo': 'Esgoto aberto',
      'descricao': 'Vazamento na calçada',
      'localizacao': 'Manaíra',
      'latitude': -7.1,
      'longitude': -34.84,
      'tipoLixo': 'Esgoto',
      'status': 'Pendente',
      'dataCriacao': Timestamp.fromDate(DateTime(2026, 6, 10, 14, 30)),
      'usuarioId': 'user-1',
      'likedBy': ['user-2', 'user-3'],
      'dislikedBy': <String>[],
      'likes': 2,
      'dislikes': 0,
      'comments': 5,
    };

    test('userLiked reflete presença do usuário atual em likedBy', () {
      final curtiu = OcorrenciaModel.fromMap(
        baseMap(),
        'doc-1',
        currentUserId: 'user-2',
      );
      final naoCurtiu = OcorrenciaModel.fromMap(
        baseMap(),
        'doc-1',
        currentUserId: 'user-9',
      );

      expect(curtiu.userLiked, isTrue);
      expect(naoCurtiu.userLiked, isFalse);
      expect(naoCurtiu.userDisliked, isFalse);
    });

    test('converte Timestamp do Firestore em DateTime', () {
      final model = OcorrenciaModel.fromMap(baseMap(), 'doc-1');

      expect(model.dataCriacao, DateTime(2026, 6, 10, 14, 30));
      expect(model.id, 'doc-1');
      expect(model.likes, 2);
      expect(model.comments, 5);
    });

    test('campos ausentes caem em valores padrão seguros', () {
      final model = OcorrenciaModel.fromMap({'titulo': 'Só título'}, 'doc-2');

      expect(model.titulo, 'Só título');
      expect(model.descricao, '');
      expect(model.latitude, 0);
      expect(model.longitude, 0);
      expect(model.status, 'Pendente');
      expect(model.dataCriacao, isNull);
      expect(model.likedBy, isEmpty);
      expect(model.likes, 0);
      expect(model.userLiked, isFalse);
    });

    test('statusOficial: string do Firestore vira o enum correspondente', () {
      final model = OcorrenciaModel.fromMap(
        baseMap()..['statusOficial'] = 'encaminhada',
        'doc-1',
      );

      expect(model.statusOficial, StatusOficial.encaminhada);
    });

    test('statusOficial: ausente ou desconhecido vira null', () {
      final semStatus = OcorrenciaModel.fromMap(baseMap(), 'doc-1');
      final statusInvalido = OcorrenciaModel.fromMap(
        baseMap()..['statusOficial'] = 'valor_que_nao_existe',
        'doc-1',
      );

      expect(semStatus.statusOficial, isNull);
      expect(statusInvalido.statusOficial, isNull);
    });
  });

  group('StatusOficial (fronteira de serialização)', () {
    test('round-trip valor <-> enum é estável para todos os status', () {
      for (final status in StatusOficial.values) {
        expect(StatusOficialInfo.fromString(status.valor), status);
      }
    });
  });
}
