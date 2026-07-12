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
  final String? videoUrl;

  // Proteção do denunciante (Fase 2). Quando true, usuarioNome/usuarioFotoUrl
  // nunca são preenchidos e a UI exibe "Denunciante anônimo" para todos,
  // inclusive autoridade. usuarioId permanece (necessário para regras de
  // dono/edição), mas nunca é associado a um nome na interface.
  final bool anonima;

  // Listas de reação persistidas no Firestore
  List<String> likedBy;
  List<String> dislikedBy;

  // Campos de UI — derivados das listas acima
  int likes;
  int dislikes;
  int comments;
  bool userLiked;
  bool userDisliked;

  // Verificação oficial por autoridade (Fase 3). Adicionados via update por
  // uma conta com papel 'autoridade'; ausentes em denúncias comuns.
  bool verificada;
  String? verificadaPorNome;
  DateTime? verificadaEm;

  // Ciclo de vida oficial da autoridade. Valores de statusOficial:
  //   null            → pendente (ou, se verificada==true, confirmada)
  //   'em_analise'    → autoridade vai ao local checar
  //   'nao_confirmada'→ foi ao local e o problema não existia
  //   'encaminhada'   → confirmada e encaminhada ao órgão responsável
  //   'resolvida'     → confirmada e tratada pelo órgão
  // 'confirmada' é representado por verificada == true && statusOficial == null.
  String? statusOficial;
  DateTime? encaminhadaEm;
  DateTime? resolvidaEm;
  bool fixada;

  // Moderação (Fase 3): quando true, a ocorrência foi ocultada pela autoridade
  // após denúncia de abuso e não deve aparecer no feed do cidadão.
  bool oculto;

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
    this.videoUrl,
    List<String>? likedBy,
    List<String>? dislikedBy,
    this.likes = 0,
    this.dislikes = 0,
    this.comments = 0,
    this.userLiked = false,
    this.userDisliked = false,
    this.verificada = false,
    this.verificadaPorNome,
    this.verificadaEm,
    this.statusOficial,
    this.encaminhadaEm,
    this.resolvidaEm,
    this.fixada = false,
    this.anonima = false,
    this.oculto = false,
  }) : likedBy = likedBy ?? [],
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
      // Denúncia anônima: o UID real não vai no documento público (protege
      // o denunciante de correlação entre denúncias). Fica só na subcoleção
      // privada ocorrencias/{id}/dono/info, criada pelo OcorrenciaService
      // logo após este documento — ver cadastrarOcorrencia().
      'usuarioId': anonima ? null : usuarioId,
      'usuarioNome': usuarioNome,
      'usuarioFotoUrl': usuarioFotoUrl,
      'imagemUrl': imagemUrl,
      'imagensUrls': imagensUrls,
      'videoUrl': videoUrl,
      'anonima': anonima,
      'likes': 0,
      'dislikes': 0,
      'comments': 0,
      'likedBy': [],
      'dislikedBy': [],
      'fixada': false,
      // Fixo por enquanto (app é só João Pessoa hoje). Gravar isso desde já
      // evita migração retroativa de dados quando o app expandir para outros
      // municípios da Paraíba — dados novos já nascem particionados.
      'municipioId': 'joao-pessoa',
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
      videoUrl: map['videoUrl'] as String?,
      imagemUrl: map['imagemUrl'],
      imagensUrls: List<String>.from(map['imagensUrls'] ?? []),
      likedBy: likedBy,
      dislikedBy: dislikedBy,
      likes: map['likes'] ?? likedBy.length,
      dislikes: map['dislikes'] ?? dislikedBy.length,
      comments: map['comments'] ?? 0,
      userLiked: currentUserId != null && likedBy.contains(currentUserId),
      userDisliked: currentUserId != null && dislikedBy.contains(currentUserId),
      verificada: map['verificada'] == true,
      verificadaPorNome: map['verificadaPorNome'],
      verificadaEm: map['verificadaEm'] != null
          ? (map['verificadaEm'] as Timestamp).toDate()
          : null,
      statusOficial: map['statusOficial'] as String?,
      encaminhadaEm: map['encaminhadaEm'] != null
          ? (map['encaminhadaEm'] as Timestamp).toDate()
          : null,
      resolvidaEm: map['resolvidaEm'] != null
          ? (map['resolvidaEm'] as Timestamp).toDate()
          : null,
      fixada: map['fixada'] == true,
      anonima: map['anonima'] == true,
      oculto: map['oculto'] == true,
    );
  }
}
