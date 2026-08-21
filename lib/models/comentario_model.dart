import 'package:cloud_firestore/cloud_firestore.dart';

class ComentarioModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String texto;
  final DateTime? dataCriacao;

  // Resposta a outro comentário (null = comentário raiz).
  final String? parentId;

  // Curtidas no comentário.
  final List<String> likedBy;
  final int likes;
  final bool userLiked; // derivado de likedBy + usuário atual

  // Moderação: quando true, foi ocultado pela autoridade após denúncia de abuso.
  final bool oculto;

  // Selo de verificado: true quando o autor é uma conta de órgão/autoridade.
  // Gravado na criação (o app já sabe o papel do usuário logado). Exibido como
  // selo azul estilo redes sociais ao lado do nome.
  final bool autorAutoridade;

  ComentarioModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.texto,
    this.dataCriacao,
    this.parentId,
    List<String>? likedBy,
    this.likes = 0,
    this.userLiked = false,
    this.oculto = false,
    this.autorAutoridade = false,
  }) : likedBy = likedBy ?? [];

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'texto': texto,
    'dataCriacao': FieldValue.serverTimestamp(),
    'parentId': parentId,
    'likedBy': <String>[],
    'likes': 0,
    // Só grava o campo quando true, para não poluir os comentários comuns e
    // manter compatibilidade com a regra (campo opcional).
    if (autorAutoridade) 'autorAutoridade': true,
  };

  factory ComentarioModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? currentUserId,
  }) {
    final likedBy = List<String>.from(map['likedBy'] ?? []);
    return ComentarioModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Usuário',
      userPhotoUrl: map['userPhotoUrl'],
      texto: map['texto'] ?? '',
      dataCriacao: map['dataCriacao'] != null
          ? (map['dataCriacao'] as Timestamp).toDate()
          : null,
      parentId: map['parentId'] as String?,
      likedBy: likedBy,
      likes: map['likes'] ?? likedBy.length,
      userLiked: currentUserId != null && likedBy.contains(currentUserId),
      oculto: map['oculto'] == true,
      autorAutoridade: map['autorAutoridade'] == true,
    );
  }
}
