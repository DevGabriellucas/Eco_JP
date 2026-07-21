import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/auth_service.dart';
import '../../../services/consent_service.dart';
import '../../../services/role_service.dart';

/// Ponto único de acesso ao [AuthService] via injeção de dependência.
///
/// O [AuthService] já isola o `FirebaseAuth`/`GoogleSignIn` e retorna tipos de
/// domínio ([AuthResult]/[User]), então cumpre o papel de repositório de auth.
/// Expor por provider elimina os múltiplos `AuthService()` soltos e torna a
/// dependência mockável nos testes.
final authServiceProvider = Provider<AuthService>((ref) => AuthService.instance);

/// Acesso ao serviço de consentimento (LGPD) por injeção.
final consentServiceProvider =
    Provider<ConsentService>((ref) => ConsentService.instance);

/// Acesso ao serviço de papéis (role) por injeção.
final roleServiceProvider = Provider<RoleService>((ref) => RoleService.instance);

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

/// Indica se o usuário logado ainda precisa consentir (LGPD).
///
/// Depende de [authStateChangesProvider]: recalcula quando o usuário muda.
/// Retorna `false` (não precisa) quando não há usuário ou quando a conta é
/// só-senha ainda não verificada — nesses casos a trava de consentimento não
/// se aplica e o gate de e-mail vem antes.
final consentStatusProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return false;

  final apenasSenha = user.providerData.every((p) => p.providerId == 'password');
  if (apenasSenha && !user.emailVerified) return false;

  return ref.watch(consentServiceProvider).precisaConsentir(user.uid);
});
