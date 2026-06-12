import 'package:cloud_firestore/cloud_firestore.dart';

class ComentarioModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String texto;
  final DateTime? dataCriacao;

  ComentarioModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.texto,
    this.dataCriacao,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'texto': texto,
    'dataCriacao': FieldValue.serverTimestamp(),
  };

  factory ComentarioModel.fromMap(Map<String, dynamic> map, String id) {
    return ComentarioModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Usuário',
      userPhotoUrl: map['userPhotoUrl'],
      texto: map['texto'] ?? '',
      dataCriacao: map['dataCriacao'] != null
          ? (map['dataCriacao'] as Timestamp).toDate()
          : null,
    );
  }
}
