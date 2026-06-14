import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthResult {
  final bool success;
  final String? message;
  final User? user;

  AuthResult({required this.success, this.message, this.user});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AuthResult> cadastrar(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Email e senha nao podem estar vazios.',
        );
      }

      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return AuthResult(
        success: true,
        user: result.user,
        message: 'Cadastro realizado com sucesso!',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mensagemCadastro(e));
    } catch (e) {
      return AuthResult(success: false, message: 'Erro inesperado: $e');
    }
  }

  Future<AuthResult> login(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Email e senha nao podem estar vazios.',
        );
      }

      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return AuthResult(
        success: true,
        user: result.user,
        message: 'Login realizado com sucesso!',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mensagemLogin(e));
    } catch (e) {
      return AuthResult(success: false, message: 'Erro inesperado: $e');
    }
  }

  Future<AuthResult> loginGoogle() async {
    try {
      if (kIsWeb) {
        // Web: usa popup do Firebase Auth (não precisa de clientId no código)
        final result = await _auth.signInWithPopup(GoogleAuthProvider());
        return AuthResult(
          success: true,
          user: result.user,
          message: 'Login realizado com sucesso!',
        );
      }

      // Mobile (Android / iOS): usa o pacote google_sign_in
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          return AuthResult(success: false, message: 'Login cancelado.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final result = await _auth.signInWithCredential(credential);
        return AuthResult(
          success: true,
          user: result.user,
          message: 'Login realizado com sucesso!',
        );
      }

      // Outras plataformas (Windows, Linux, macOS)
      return AuthResult(
        success: false,
        message: 'Login com Google não disponível nesta plataforma.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mensagemLogin(e));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erro ao entrar com Google: $e',
      );
    }
  }

  Future<AuthResult> recuperarSenha(String email) async {
    try {
      if (email.trim().isEmpty) {
        return AuthResult(
          success: false,
          message: 'Informe o email para recuperar a senha.',
        );
      }
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult(
        success: true,
        message:
            'Enviamos um link de recuperação para o seu email. Verifique a caixa de entrada (e o spam).',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _mensagemRecuperacao(e));
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Erro ao enviar email de recuperação: $e',
      );
    }
  }

  Future<void> sair() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  String _mensagemCadastro(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'A senha e muito fraca. Use pelo menos 6 caracteres.';
      case 'email-already-in-use':
        return 'Este email ja esta registrado.';
      case 'invalid-email':
        return 'Email invalido.';
      case 'operation-not-allowed':
        return 'Cadastro por email/senha nao esta ativado no Firebase Auth.';
      case 'network-request-failed':
        return 'Falha de internet. Verifique a conexao do celular.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      default:
        return 'Erro no cadastro (${e.code}): ${e.message ?? 'sem detalhes'}';
    }
  }

  String _mensagemRecuperacao(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email inválido. Confira se digitou corretamente.';
      case 'missing-email':
        return 'Informe o email para recuperar a senha.';
      case 'user-not-found':
        return 'Não encontramos uma conta com esse email.';
      case 'network-request-failed':
        return 'Falha de internet. Verifique a conexão do celular.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      default:
        return 'Não foi possível enviar o email de recuperação '
            '(${e.code}): ${e.message ?? 'sem detalhes'}';
    }
  }

  String _mensagemLogin(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Usuario nao encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'user-disabled':
        return 'Usuario desabilitado.';
      case 'invalid-email':
        return 'Email invalido.';
      case 'invalid-credential':
        return 'Email ou senha invalidos.';
      case 'network-request-failed':
        return 'Falha de internet. Verifique a conexao do celular.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      default:
        return 'Erro no login (${e.code}): ${e.message ?? 'sem detalhes'}';
    }
  }
}
