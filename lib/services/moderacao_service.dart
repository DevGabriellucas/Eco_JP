import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/denuncia_moderacao_model.dart';
import 'analytics_service.dart';
import 'ocorrencia_service.dart';

class ModeracaoService {
  static final ModeracaoService instance = ModeracaoService();

  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('denuncias_moderacao');

  final OcorrenciaService _ocorrenciaService = OcorrenciaService();
  final AnalyticsService _analytics = AnalyticsService();

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

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
      unawaited(_analytics.denunciaDeAbusoCriada(alvoTipo: alvoTipo));
    } catch (e) {
      debugPrint('Erro ao denunciar conteúdo: $e');
      rethrow;
    }
  }

  // ── FILA DE MODERAÇÃO (autoridade) ────────────────────────────────────────

  /// Denúncias de abuso ainda pendentes, mais antigas primeiro.
  Stream<List<DenunciaModeracaoModel>> listarPendentes() {
    return _ref
        .where('status', isEqualTo: 'pendente')
        .orderBy('criadoEm', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => DenunciaModeracaoModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Resolve uma denúncia de abuso. [decisao]: 'revisada' (mantém o conteúdo)
  /// ou 'rejeitada' (denúncia improcedente). Grava auditoria de quem/quando.
  Future<void> resolver(
    String denunciaId, {
    required String decisao,
  }) async {
    try {
      await _ref.doc(denunciaId).update({
        'status': decisao,
        'resolvidoPor': _currentUserId,
        'resolvidoEm': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Erro ao resolver denúncia de moderação: $e');
      rethrow;
    }
  }

  /// Oculta o conteúdo alvo (ocorrência ou comentário) de uma denúncia e marca
  /// a denúncia como revisada. Delega a ocultação ao OcorrenciaService.
  Future<void> ocultarAlvo(DenunciaModeracaoModel denuncia) async {
    try {
      if (denuncia.isComentario && denuncia.comentarioId != null) {
        await _ocorrenciaService.definirComentarioOculto(
          denuncia.ocorrenciaId,
          denuncia.comentarioId!,
          oculto: true,
        );
      } else {
        await _ocorrenciaService.definirOculto(
          denuncia.ocorrenciaId,
          oculto: true,
        );
      }
      await resolver(denuncia.id, decisao: 'revisada');
    } catch (e) {
      debugPrint('Erro ao ocultar alvo da denúncia: $e');
      rethrow;
    }
  }
}
