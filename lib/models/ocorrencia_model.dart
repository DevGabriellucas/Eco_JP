import 'package:cloud_firestore/cloud_firestore.dart';

class OcorrenciaModel {
  final String id;
  final String titulo;
  final String descricao;
  final String localizacao;
  final double latitude;
  final double longitude;
  final String tipoLixo;
  final String status;
  final DateTime? dataCriacao;
  final String? usuarioId;
  final String? usuarioNome;
  final String? usuarioFotoUrl;
  final String? imagemUrl;
  final List<String> imagensUrls;

  // Listas de reação persistidas no Firestore
  List<String> likedBy;
  List<String> dislikedBy;

  // Campos de UI — derivados das listas acima
  int likes;
  int dislikes;
  int comments;
  bool userLiked;
  bool userDisliked;

  OcorrenciaModel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.localizacao,
    required this.latitude,
    required this.longitude,
    required this.tipoLixo,
    this.status = 'Pendente',
    this.dataCriacao,
    this.usuarioId,
    this.usuarioNome,
    this.usuarioFotoUrl,
    this.imagemUrl,
    this.imagensUrls = const [],
    List<String>? likedBy,
    List<String>? dislikedBy,
    this.likes = 0,
    this.dislikes = 0,
    this.comments = 0,
    this.userLiked = false,
    this.userDisliked = false,
  })  : likedBy = likedBy ?? [],
        dislikedBy = dislikedBy ?? [];

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'localizacao': localizacao,
      'latitude': latitude,
      'longitude': longitude,
      'tipoLixo': tipoLixo,
      'status': status,
      'dataCriacao': dataCriacao ?? FieldValue.serverTimestamp(),
      'usuarioId': usuarioId,
      'usuarioNome': usuarioNome,
      'usuarioFotoUrl': usuarioFotoUrl,
      'imagemUrl': imagemUrl,
      'imagensUrls': imagensUrls,
      'likes': 0,
      'dislikes': 0,
      'comments': 0,
      'likedBy': [],
      'dislikedBy': [],
    };
  }

  factory OcorrenciaModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? currentUserId,
  }) {
    final likedBy = List<String>.from(map['likedBy'] ?? []);
    final dislikedBy = List<String>.from(map['dislikedBy'] ?? []);
    return OcorrenciaModel(
      id: id,
      titulo: map['titulo'] ?? '',
      descricao: map['descricao'] ?? '',
      localizacao: map['localizacao'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      tipoLixo: map['tipoLixo'] ?? '',
      status: map['status'] ?? 'Pendente',
      dataCriacao: map['dataCriacao'] != null
          ? (map['dataCriacao'] as Timestamp).toDate()
          : null,
      usuarioId: map['usuarioId'],
      usuarioNome: map['usuarioNome'],
      usuarioFotoUrl: map['usuarioFotoUrl'],
      imagemUrl: map['imagemUrl'],
      imagensUrls: List<String>.from(map['imagensUrls'] ?? []),
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      likes: map['likes'] ?? likedBy.length,
      dislikes: map['dislikes'] ?? dislikedBy.length,
      comments: map['comments'] ?? 0,
      userLiked: currentUserId != null && likedBy.contains(currentUserId),
      userDisliked: currentUserId != null && dislikedBy.contains(currentUserId),
    );
  }
}
