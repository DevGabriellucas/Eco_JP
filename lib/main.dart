import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/cadastro_page.dart';
import 'pages/home_shell.dart';
import 'pages/inicial_page.dart';
import 'pages/form_ocorrencia_page.dart';
import 'pages/verificacao_email_page.dart';
import 'pages/legal/consentimento_page.dart';
import 'services/auth_service.dart';
import 'services/consent_service.dart';
import 'theme/app_theme.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        await FirebaseAppCheck.instance.activate(
          // Em produção Android usa Play Integrity (validado pela Play Store).
          // Em debug/emulador usa o provider de depuração pra não bloquear testes.
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          // Mesma lógica no Apple: App Attest em produção (exige dispositivo
          // real e conta Apple Developer), debug provider só em kDebugMode —
          // sem isso, o App Check ficava sem proteção real em builds iOS
          // de produção mesmo fora do modo debug.
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestProvider(),
        );

        // Crashlytics: desativado em debug (evita poluir o console com
        // crashes de desenvolvimento) e captura erros do Flutter framework +
        // erros não tratados fora dele (o runZonedGuarded cobre o resto).
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          !kDebugMode,
        );
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

        runApp(const MyApp());
      } catch (e) {
        // Se o Firebase não inicializar, mostra uma tela de erro em vez de tela branca.
        runApp(const _AppErroInicializacao());
      }
    },
    (error, stack) {
      // Erros fora da árvore de widgets (streams, futures soltos) também vão
      // pro Crashlytics, quando o Firebase já foi inicializado com sucesso.
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

class _AppErroInicializacao extends StatelessWidget {
  const _AppErroInicializacao();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A1018),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.cloud_off, color: Colors.white70, size: 64),
                SizedBox(height: 20),
                Text(
                  'Não foi possível conectar ao servidor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Verifique sua conexão com a internet e abra o aplicativo novamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoJP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthCheck(),
      routes: {
        '/inicial': (context) => const InicialPage(),
        '/login': (context) => const LoginPage(),
        '/cadastro': (context) => const CadastroPage(),
        '/home': (context) => const AuthCheck(),
        '/form-ocorrencia': (context) => const FormOcorrenciaPage(),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          // Contas por e-mail/senha só acessam o app após confirmar o e-mail.
          // Contas Google já vêm com o e-mail verificado e passam direto.
          final apenasSenha = user.providerData.every(
            (p) => p.providerId == 'password',
          );
          if (apenasSenha && !user.emailVerified) {
            return const VerificacaoEmailPage();
          }
          // Trava de consentimento (LGPD): pega contas Google e usuários
          // anteriores à política atual, que não passaram pelo aceite.
          return _ConsentGate(uid: user.uid);
        }

        return const InicialPage();
      },
    );
  }
}

/// Verifica o consentimento do usuário e, se necessário, exibe a tela de
/// aceite antes de liberar o app. Contas que aceitaram no cadastro passam
/// direto (já têm o registro de consentimento na versão atual).
class _ConsentGate extends StatefulWidget {
  final String uid;
  const _ConsentGate({required this.uid});

  @override
  State<_ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<_ConsentGate> {
  final _consentService = ConsentService();
  bool? _precisaConsentir; // null enquanto carrega

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    final precisa = await _consentService.precisaConsentir(widget.uid);
    if (mounted) setState(() => _precisaConsentir = precisa);
  }

  @override
  Widget build(BuildContext context) {
    if (_precisaConsentir == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_precisaConsentir!) {
      return ConsentimentoPage(
        onAceitar: () async {
          await _consentService.registrar(widget.uid);
          if (mounted) setState(() => _precisaConsentir = false);
        },
      );
    }
    return const HomeShell();
  }
}
