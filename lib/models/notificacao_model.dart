import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacaoModel {
  final String id;
  final String tipo; // 'comentario', 'curtida' ou 'conquista'
  final String deUsuarioNome;
  final String ocorrenciaId;
  final String ocorrenciaTitulo;
  final String? conquistaTitulo; // Para notificações de conquista
  final DateTime? dataCriacao;
  final bool lida;

  NotificacaoModel({
    required this.id,
    required this.tipo,
    required this.deUsuarioNome,
    required this.ocorrenciaId,
    required this.ocorrenciaTitulo,
    this.conquistaTitulo,
    this.dataCriacao,
    this.lida = false,
  });

  Map<String, dynamic> toMap() => {
    'tipo': tipo,
    'deUsuarioNome': deUsuarioNome,
    'ocorrenciaId': ocorrenciaId,
    'ocorrenciaTitulo': ocorrenciaTitulo,
    // Só grava o campo em notificações de conquista. Incluí-lo como null nas
    // demais adicionaria uma chave extra que a regra do Firestore rejeita
    // (hasOnly), quebrando toda notificação de comentário/curtida.
    if (conquistaTitulo != null) 'conquistaTitulo': conquistaTitulo,
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
      conquistaTitulo: map['conquistaTitulo'],
      dataCriacao: map['dataCriacao'] != null
          ? (map['dataCriacao'] as Timestamp).toDate()
          : null,
      lida: map['lida'] ?? false,
    );
  }
}
