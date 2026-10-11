import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/auth_service.dart';
import '../../../services/consent_service.dart';
import '../../../services/role_service.dart';
import '../../../services/usuario_service.dart';
import '../../../utils/cloudinary_image.dart';

/// Ponto único de acesso ao [AuthService] via injeção de dependência.
///
/// O [AuthService] já isola o `FirebaseAuth`/`GoogleSignIn` e retorna tipos de
/// domínio ([AuthResult]/[User]), então cumpre o papel de repositório de auth.
/// Expor por provider elimina os múltiplos `AuthService()` soltos e torna a
/// dependência mockável nos testes.
final authServiceProvider =
    Provider<AuthService>((ref) => AuthService.instance);

/// Acesso ao serviço de consentimento (LGPD) por injeção.
final consentServiceProvider =
    Provider<ConsentService>((ref) => ConsentService.instance);

/// Acesso ao serviço de papéis (role) por injeção.
final roleServiceProvider =
    Provider<RoleService>((ref) => RoleService.instance);

/// Estado de autenticação do Firebase, reativo. Substitui o `StreamBuilder`
/// que ficava no `main.dart`. O router escuta este provider para redirecionar.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Indica, de forma reativa, se o usuário logado tem papel de autoridade.
///
/// Ponto único de acesso — antes 5 telas (`home_page`, `home_shell`,
/// `detalhe_ocorrencia_page`, `estatisticas_page`, `perfil_page`) faziam cada
/// uma sua própria leitura/observação independente de `roles/{uid}`. Depende
/// de [authStateChangesProvider]: recalcula quando o usuário muda e emite
/// `false` enquanto não há sessão (sem UID não há papel a consultar).
final isAutoridadeProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(false);
  return ref.watch(roleServiceProvider).observarAutoridade(user.uid);
});

/// True enquanto a tela de cadastro cria a conta, reserva o nome e grava o
/// perfil. O router não tira o usuário de /cadastro nesse intervalo: antes o
/// redirect trocava para /verificacao-email logo após criar a conta, a página
/// era desmontada no meio da reserva e um nome em uso apagava a conta em
/// silêncio, sem mensagem nenhuma.
final cadastroEmAndamentoProvider = StateProvider<bool>((ref) => false);

/// Acesso ao [UsuarioService] por injeção (testes trocam por um fake).
final usuarioServiceProvider =
    Provider<UsuarioService>((ref) => UsuarioService.instance);

/// Garante que o usuário logado (e verificado) tenha perfil com nome
/// reservado — ver [UsuarioService.garantirPerfil]. Cobre o primeiro login
/// Google, que não passa pelo cadastro. Falha de rede não trava o acesso
/// (tenta de novo no próximo login).
///
/// Só depois do consentimento (LGPD): o perfil é público (nome e foto do
/// Google) e reserva o nome. Antes ele era criado assim que a conta entrava,
/// e quem tocava em "Não concordo" saía deixando os dados gravados. Agora,
/// sem aceite, nada é gravado; quando o aceite é registrado,
/// [consentStatusProvider] recalcula e este provider cria o perfil.
final perfilGarantidoProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return true;
  final apenasSenha =
      user.providerData.every((p) => p.providerId == 'password');
  if (apenasSenha && !user.emailVerified) return true;
  if (await ref.watch(consentStatusProvider.future)) return true;
  try {
    // Com limite: sem ele, rede ruim deixava o app parado na splash.
    await ref
        .read(usuarioServiceProvider)
        .garantirPerfil(
          user.uid,
          nomeSugerido: user.displayName,
          fotoUrl: fotoPublicaPermitida(user.photoURL),
        )
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('Não foi possível garantir o perfil: $e');
  }
  return true;
});

/// Indica se o usuário logado ainda precisa consentir (LGPD).
///
/// Depende de [authStateChangesProvider]: recalcula quando o usuário muda.
/// Retorna `false` (não precisa) quando não há usuário ou quando a conta é
/// só-senha ainda não verificada — nesses casos a trava de consentimento não
/// se aplica e o gate de e-mail vem antes.
final consentStatusProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return false;

  final apenasSenha =
      user.providerData.every((p) => p.providerId == 'password');
  if (apenasSenha && !user.emailVerified) return false;

  // Rede de segurança: o ConsentService já limita a ida ao servidor e cai no
  // cache local. Passou disto, trata como "precisa consentir" (falha
  // fechada). Sem limite nenhum o app ficava na splash.
  return ref
      .watch(consentServiceProvider)
      .precisaConsentir(user.uid)
      .timeout(const Duration(seconds: 15), onTimeout: () => true);
});
