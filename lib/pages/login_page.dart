import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isLoadingGoogle = false;
  bool _senhaVisivel = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLoginGoogle() async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    final result = await _authService.loginGoogle();

    if (!mounted) return;
    setState(() => _isLoadingGoogle = false);

    if (result.success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() => _errorMessage = result.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Erro ao entrar com Google')),
      );
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() => _errorMessage = result.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Erro ao fazer login')),
      );
    }
  }

  Future<void> _handleEsqueceuSenha() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    bool enviando = false;

    await showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Recuperar senha',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Digite seu email e enviaremos um link para você redefinir sua senha.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: const TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF1A1A1A),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFF8A8A8A)),
                  ),
                ),
                ElevatedButton(
                  onPressed: enviando
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          setDialogState(() => enviando = true);
                          final result = await _authService.recuperarSenha(email);
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message ?? '')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );

    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double logoSize = (screenWidth * 0.52).clamp(170.0, 240.0);
    const double baseWidth = 430.0;
    final double paddingLateral = (38.0 / baseWidth) * screenWidth;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1018),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          // 1. Imagem de Fundo (20% opacidade)
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/images/joaopessoa.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) =>
                    Container(color: const Color(0xFF0A1018)),
              ),
            ),
          ),

          // 2. Gradiente Suavizado
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33FFFFFF), Color(0x4D000000)],
                  stops: [0.28, 0.80],
                ),
              ),
            ),
          ),

          // 3. Conteúdo
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: paddingLateral),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context)
                              .pushReplacementNamed('/inicial');
                        },
                        child: SvgPicture.asset(
                          'assets/icons/seta.svg',
                          width: 44,
                          height: 44,
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: SizedBox(
                            width: logoSize,
                            height: logoSize,
                            child: Image.asset(
                              'assets/images/logo_ecojp.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLabel('Email'),
                            const SizedBox(height: 8),
                            _buildInput(
                              controller: _emailController,
                              hint: 'Email',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('Senha'),
                            const SizedBox(height: 8),
                            _buildInput(
                              controller: _passwordController,
                              hint: 'Senha',
                              obscure: !_senhaVisivel,
                              suffix: IconButton(
                                icon: Icon(
                                  _senhaVisivel
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: const Color(0xFFBDBDBD),
                                ),
                                onPressed: () => setState(
                                  () => _senhaVisivel = !_senhaVisivel,
                                ),
                              ),
                            ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFF2C2C2C)
                                          .withValues(alpha: 0.6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Logar'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _handleEsqueceuSenha,
                              child: const Text(
                                'Esqueceu a senha?',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF1A1A1A),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            if (kIsWeb ||
                                defaultTargetPlatform ==
                                    TargetPlatform.android ||
                                defaultTargetPlatform ==
                                    TargetPlatform.iOS) ...[
                              const SizedBox(height: 24),
                              Center(
                                child: OutlinedButton(
                                  onPressed: (_isLoading || _isLoadingGoogle)
                                      ? null
                                      : _handleLoginGoogle,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoadingGoogle
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SvgPicture.asset(
                                              'assets/icons/google_icon.svg',
                                              width: 20,
                                              height: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Logar com Google',
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushNamed('/cadastro');
                                },
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    children: [
                                      TextSpan(text: 'Não tem conta? '),
                                      TextSpan(
                                        text: 'Cadastre-se',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          color: Color(0xFFBDBDBD),
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
    );
  }
}
