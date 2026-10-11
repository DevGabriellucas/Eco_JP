import '../services/auth_service.dart';
import '../services/usuario_service.dart';

/// Nome e foto resolvidos para exibição do autor de uma ocorrência.
class AutorResolvido {
  const AutorResolvido({required this.nome, this.foto});

  final String nome;
  final String? foto;
}

/// Resolve nome/foto de exibição do autor de uma ocorrência, com a mesma
/// cascata de fallback usada no feed e na tela de detalhe: nome já salvo no
/// documento da ocorrência → perfil em `usuarios/{uid}` → e-mail (antes do
/// "@") se for o próprio usuário logado → "Usuário".
///
/// Não deve ser chamada para ocorrência anônima — quem chama decide o texto
/// de exibição desse caso ("Denunciante anônimo"), já que o UID real nem
/// chega a existir no documento público (proteção do denunciante, S2).
Future<AutorResolvido> resolverAutorOcorrencia({
  required String usuarioId,
  required String? nomeSalvo,
  required String? fotoSalva,
  required UsuarioService usuarioService,
  required AuthService authService,
}) async {
  final hasSavedName = nomeSalvo != null && nomeSalvo.trim().isNotEmpty;
  final hasSavedPhoto = fotoSalva != null && fotoSalva.isNotEmpty;

  if (hasSavedName && hasSavedPhoto) {
    return AutorResolvido(nome: nomeSalvo, foto: fotoSalva);
  }

  final perfil = await usuarioService.carregarPerfil(usuarioId);
  final nomePerfil = perfil?.nome.trim();
  final fotoPerfil = perfil?.fotoUrl;

  String nomeResolvido;
  if (hasSavedName) {
    nomeResolvido = nomeSalvo;
  } else if (nomePerfil != null && nomePerfil.isNotEmpty) {
    nomeResolvido = nomePerfil;
  } else if (usuarioId == authService.currentUser?.uid) {
    final email = authService.currentUser?.email;
    nomeResolvido = email != null ? email.split('@').first : 'Usuário';
  } else {
    nomeResolvido = 'Usuário';
  }

  final fotoResolvida = hasSavedPhoto
      ? fotoSalva
      : (fotoPerfil?.isNotEmpty == true ? fotoPerfil : null);

  return AutorResolvido(nome: nomeResolvido, foto: fotoResolvida);
}
