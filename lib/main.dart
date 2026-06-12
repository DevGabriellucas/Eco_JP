import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/cadastro_page.dart';
import 'pages/home_shell.dart';
import 'pages/inicial_page.dart';
import 'pages/form_ocorrencia_page.dart';
import 'services/auth_service.dart';
import 'pages/mapPage/map_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    // Se o Firebase não inicializar, mostra uma tela de erro em vez de tela branca.
    runApp(const _AppErroInicializacao());
  }
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
                  style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const InicialPage(),
      routes: {
        '/inicial': (context) => const InicialPage(),
        '/login': (context) => const LoginPage(),
        '/cadastro': (context) => const CadastroPage(),
        '/home': (context) => const AuthCheck(),
        '/form-ocorrencia': (context) => const FormOcorrenciaPage(),
        '/map-page': (context) => const MapPage(),
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

        if (snapshot.hasData) {
          return const HomeShell();
        }

        return const LoginPage();
      },
    );
  }
}
