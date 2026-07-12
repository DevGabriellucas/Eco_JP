import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eco_jp/models/denuncia_moderacao_model.dart';

void main() {
  group('DenunciaModeracaoModel.fromMap', () {
    test('denúncia de ocorrência é interpretada corretamente', () {
      final criadoEm = DateTime(2026, 7, 1, 10, 30);
      final model = DenunciaModeracaoModel.fromMap({
        'alvoTipo': 'ocorrencia',
        'ocorrenciaId': 'oc-1',
        'comentarioId': null,
        'denuncianteId': 'user-1',
        'motivo': 'Conteúdo ofensivo',
        'detalhe': 'Texto com xingamento',
        'status': 'pendente',
        'criadoEm': Timestamp.fromDate(criadoEm),
      }, 'den-1');

      expect(model.id, 'den-1');
      expect(model.alvoTipo, 'ocorrencia');
      expect(model.isComentario, isFalse);
      expect(model.ocorrenciaId, 'oc-1');
      expect(model.comentarioId, isNull);
      expect(model.motivo, 'Conteúdo ofensivo');
      expect(model.status, 'pendente');
      expect(model.criadoEm, criadoEm);
      expect(model.resolvidoPor, isNull);
    });

    test('denúncia de comentário expõe isComentario e comentarioId', () {
      final model = DenunciaModeracaoModel.fromMap({
        'alvoTipo': 'comentario',
        'ocorrenciaId': 'oc-2',
        'comentarioId': 'com-9',
        'denuncianteId': 'user-2',
        'motivo': 'Spam',
        'status': 'pendente',
      }, 'den-2');

      expect(model.isComentario, isTrue);
      expect(model.comentarioId, 'com-9');
    });

    test('valores ausentes recebem defaults seguros', () {
      final model = DenunciaModeracaoModel.fromMap({}, 'den-3');

      expect(model.alvoTipo, 'ocorrencia');
      expect(model.ocorrenciaId, '');
      expect(model.motivo, '');
      expect(model.status, 'pendente');
      expect(model.criadoEm, isNull);
    });

    test('denúncia resolvida carrega auditoria', () {
      final resolvidoEm = DateTime(2026, 7, 2, 9);
      final model = DenunciaModeracaoModel.fromMap({
        'alvoTipo': 'ocorrencia',
        'ocorrenciaId': 'oc-3',
        'denuncianteId': 'user-3',
        'motivo': 'Abuso',
        'status': 'revisada',
        'resolvidoPor': 'autoridade-1',
        'resolvidoEm': Timestamp.fromDate(resolvidoEm),
      }, 'den-4');

      expect(model.status, 'revisada');
      expect(model.resolvidoPor, 'autoridade-1');
      expect(model.resolvidoEm, resolvidoEm);
    });
  });
}
