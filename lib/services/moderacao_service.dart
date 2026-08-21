import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/comentario_repository.dart';
import '../data/repositories/ocorrencia_repository.dart';
import '../models/denuncia_moderacao_model.dart';
import 'analytics_service.dart';

class ModeracaoService {
  static final ModeracaoService instance = ModeracaoService();

  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('denuncias_moderacao');

  final OcorrenciaRepository _ocorrenciaRepository = OcorrenciaRepository();
  final ComentarioRepository _comentarioRepository = ComentarioRepository();
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

  // Teto de leitura da fila de moderação — mesmo raciocínio do
  // OcorrenciaRepository.tetoAgregado: evita baixar a coleção inteira à
  // medida que o volume de denúncias de abuso cresce.
  static const int _tetoFila = 200;

  /// Denúncias de abuso ainda pendentes, mais antigas primeiro.
  Stream<List<DenunciaModeracaoModel>> listarPendentes() {
    return _ref
        .where('status', isEqualTo: 'pendente')
        .orderBy('criadoEm', descending: false)
        .limit(_tetoFila)
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
  /// a denúncia como revisada. Delega a ocultação aos repositórios.
  Future<void> ocultarAlvo(DenunciaModeracaoModel denuncia) async {
    try {
      if (denuncia.isComentario && denuncia.comentarioId != null) {
        await _comentarioRepository.definirComentarioOculto(
          denuncia.ocorrenciaId,
          denuncia.comentarioId!,
          oculto: true,
        );
      } else {
        await _ocorrenciaRepository.definirOculto(
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
