class UsuarioModel {
  final String uid;
  final String nome;
  final String bio;
  final String bairro;
  final String? fotoUrl;

  UsuarioModel({
    required this.uid,
    this.nome = '',
    this.bio = '',
    this.bairro = '',
    this.fotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {'nome': nome, 'bio': bio, 'bairro': bairro, 'fotoUrl': fotoUrl};
  }

  factory UsuarioModel.fromMap(Map<String, dynamic> map, String uid) {
    return UsuarioModel(
      uid: uid,
      nome: map['nome'] ?? '',
      bio: map['bio'] ?? '',
      bairro: map['bairro'] ?? '',
      fotoUrl: map['fotoUrl'],
    );
  }

  UsuarioModel copyWith({
    String? nome,
    String? bio,
    String? bairro,
    String? fotoUrl,
  }) {
    return UsuarioModel(
      uid: uid,
      nome: nome ?? this.nome,
      bio: bio ?? this.bio,
      bairro: bairro ?? this.bairro,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }

  // Iniciais para o avatar (ex: "Gabriel Lucas" -> "GL")
  String get iniciais {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      return partes.first.substring(0, 1).toUpperCase();
    }
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }
}
