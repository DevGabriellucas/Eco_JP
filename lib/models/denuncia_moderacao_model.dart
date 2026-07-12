import 'package:cloud_firestore/cloud_firestore.dart';

/// Denúncia de conteúdo abusivo criada por um cidadão sobre uma ocorrência ou
/// comentário. Persistida em `denuncias_moderacao`. Apenas a autoridade lê e
/// resolve (ver ModeracaoService + firestore.rules).
class DenunciaModeracaoModel {
  final String id;
  final String alvoTipo; // 'ocorrencia' ou 'comentario'
  final String ocorrenciaId;
  final String? comentarioId; // presente quando alvoTipo == 'comentario'
  final String denuncianteId;
  final String motivo;
  final String? detalhe;
  final String status; // 'pendente', 'revisada' ou 'rejeitada'
  final DateTime? criadoEm;

  // Preenchidos pela autoridade ao resolver.
  final String? resolvidoPor;
  final DateTime? resolvidoEm;

  DenunciaModeracaoModel({
    required this.id,
    required this.alvoTipo,
    required this.ocorrenciaId,
    this.comentarioId,
    required this.denuncianteId,
    required this.motivo,
    this.detalhe,
    this.status = 'pendente',
    this.criadoEm,
    this.resolvidoPor,
    this.resolvidoEm,
  });

  bool get isComentario => alvoTipo == 'comentario';

  factory DenunciaModeracaoModel.fromMap(Map<String, dynamic> map, String id) {
    return DenunciaModeracaoModel(
      id: id,
      alvoTipo: map['alvoTipo'] ?? 'ocorrencia',
      ocorrenciaId: map['ocorrenciaId'] ?? '',
      comentarioId: map['comentarioId'] as String?,
      denuncianteId: map['denuncianteId'] ?? '',
      motivo: map['motivo'] ?? '',
      detalhe: map['detalhe'] as String?,
      status: map['status'] ?? 'pendente',
      criadoEm: map['criadoEm'] != null
          ? (map['criadoEm'] as Timestamp).toDate()
          : null,
      resolvidoPor: map['resolvidoPor'] as String?,
      resolvidoEm: map['resolvidoEm'] != null
          ? (map['resolvidoEm'] as Timestamp).toDate()
          : null,
    );
  }
}
