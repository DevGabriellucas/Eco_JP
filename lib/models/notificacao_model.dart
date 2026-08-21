import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacaoModel {
  final String id;
  final String tipo; // 'comentario' ou 'curtida'
  final String deUsuarioNome;
  final String ocorrenciaId;
  final String ocorrenciaTitulo;
  final DateTime? dataCriacao;
  final bool lida;

  NotificacaoModel({
    required this.id,
    required this.tipo,
    required this.deUsuarioNome,
    required this.ocorrenciaId,
    required this.ocorrenciaTitulo,
    this.dataCriacao,
    this.lida = false,
  });

  Map<String, dynamic> toMap() => {
    'tipo': tipo,
    'deUsuarioNome': deUsuarioNome,
    'ocorrenciaId': ocorrenciaId,
    'ocorrenciaTitulo': ocorrenciaTitulo,
    'dataCriacao': FieldValue.serverTimestamp(),
    'lida': false,
  };

  factory NotificacaoModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificacaoModel(
      id: id,
      tipo: map['tipo'] ?? '',
      deUsuarioNome: map['deUsuarioNome'] ?? 'Alguém',
      ocorrenciaId: map['ocorrenciaId'] ?? '',
      ocorrenciaTitulo: map['ocorrenciaTitulo'] ?? '',
      dataCriacao: map['dataCriacao'] != null
          ? (map['dataCriacao'] as Timestamp).toDate()
          : null,
      lida: map['lida'] ?? false,
    );
  }
}
