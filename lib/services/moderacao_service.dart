import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ModeracaoService {
  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('denuncias_moderacao');

  Future<void> denunciarOcorrencia({
    required String ocorrenciaId,
    required String denuncianteId,
    required String motivo,
    String? detalhe,
  }) async {
    await _criarDenuncia(
      alvoTipo: 'ocorrencia',
      ocorrenciaId: ocorrenciaId,
      denuncianteId: denuncianteId,
      motivo: motivo,
      detalhe: detalhe,
    );
  }

  Future<void> denunciarComentario({
    required String ocorrenciaId,
    required String comentarioId,
    required String denuncianteId,
    required String motivo,
    String? detalhe,
  }) async {
    await _criarDenuncia(
      alvoTipo: 'comentario',
      ocorrenciaId: ocorrenciaId,
      comentarioId: comentarioId,
      denuncianteId: denuncianteId,
      motivo: motivo,
      detalhe: detalhe,
    );
  }

  Future<void> _criarDenuncia({
    required String alvoTipo,
    required String ocorrenciaId,
    String? comentarioId,
    required String denuncianteId,
    required String motivo,
    String? detalhe,
  }) async {
    try {
      await _ref.add({
        'alvoTipo': alvoTipo,
        'ocorrenciaId': ocorrenciaId,
        'comentarioId': comentarioId,
        'denuncianteId': denuncianteId,
        'motivo': motivo,
        'detalhe': detalhe?.trim(),
        'status': 'pendente',
        'criadoEm': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Erro ao denunciar conteúdo: $e');
      rethrow;
    }
  }
}
