import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_brand.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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

    final result = await ref.read(authServiceProvider).loginGoogle();

    if (!mounted) return;
    setState(() => _isLoadingGoogle = false);

    // Em caso de sucesso, o redirect do router leva para /home (ou para o
    // gate de consentimento) reagindo à mudança de authState.
    if (!result.success) {
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

    final result = await ref
        .read(authServiceProvider)
        .login(_emailController.text.trim(), _passwordController.text);

    if (!mounted) return;

    setState(() => _isLoading = false);

    // Sucesso → o redirect do router assume a navegação (home / verificação de
    // e-mail / consentimento, conforme o estado da conta).
    if (!result.success) {
      setState(() => _errorMessage = result.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Erro ao fazer login')),
      );
    }
  }

  Future<void> _handleEsqueceuSenha() async {
    final pal = context.pal;
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    bool enviando = false;

    await showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: pal.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Recuperar senha',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: pal.ink,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digite seu email e enviaremos um link para você redefinir sua senha.',
                    style: TextStyle(fontSize: 14, color: pal.muted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    style: TextStyle(fontSize: 14, color: pal.ink),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(color: pal.hint, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: pal.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: pal.ink, width: 1.5),
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
                    style: TextStyle(color: AppColors.hint),
                  ),
                ),
                ElevatedButton(
                  onPressed: enviando
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          setDialogState(() => enviando = true);
                          final result = await ref
                              .read(authServiceProvider)
                              .recuperarSenha(email);
                          if (!ctx.mounted) return;
                          // Fecha o teclado antes de fechar o diálogo: do
                          // contrário o fechamento do teclado (que redimensiona
                          // a tela) corre com o pop do Navigator e o app
                          // quebra com 'Failed assertion: _dependents.isEmpty'.
                          FocusScope.of(ctx).unfocus();
                          Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message ?? '')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pal.ink,
                    foregroundColor: pal.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: enviando
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: pal.surface,
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

    // Descarta o controller só depois do fechamento do diálogo terminar,
    // pelo mesmo motivo do unfocus acima.
    WidgetsBinding.instance.addPostFrameCallback((_) => emailCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double baseWidth = 430.0;
    final double paddingLateral = (38.0 / baseWidth) * screenWidth;

    return Scaffold(
      backgroundColor: AuthBrand.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackground()),

          // 3. Conteúdo
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: paddingLateral,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                context.go(Routes.inicial);
                              },
                              child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.arrow_back,
                                      color: Colors.white)),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: SizedBox(
                                  height: (screenWidth - 32) * 124 / 611,
                                  child: OverflowBox(
                                    minWidth: screenWidth - 32,
                                    maxWidth: screenWidth - 32,
                                    alignment: Alignment.center,
                                    child:
                                        const EcoHubWordmark(trimPadding: true),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 24),
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
                                      tooltip: _senhaVisivel
                                          ? 'Ocultar senha'
                                          : 'Mostrar senha',
                                      icon: Icon(
                                        _senhaVisivel
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                        color: AuthBrand.hint,
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
                                          color: Color(0xFFFFB4AB),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AuthBrand.ink,
                                        foregroundColor: AuthBrand.background,
                                        disabledBackgroundColor: AuthBrand.ink
                                            .withValues(alpha: 0.6),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(50),
                                        ),
                                        textStyle: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: AuthBrand.background,
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
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: AuthBrand.ink,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AuthBrand.ink,
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
                                        onPressed:
                                            (_isLoading || _isLoadingGoogle)
                                                ? null
                                                : _handleLoginGoogle,
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: AuthBrand.surface,
                                          side: const BorderSide(
                                            color: AuthBrand.border,
                                            width: 1,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
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
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AuthBrand.ink,
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
                                                  const Flexible(
                                                      child: Text(
                                                    'Logar com Google',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: AuthBrand.ink,
                                                    ),
                                                  )),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  Center(
                                    child: GestureDetector(
                                      onTap: () {
                                        context.push(Routes.cadastro);
                                      },
                                      child: RichText(
                                        text: const TextSpan(
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            color: AuthBrand.ink,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: 'Não tem conta? ',
                                            ),
                                            TextSpan(
                                              text: 'Cadastre-se',
                                              style: TextStyle(
                                                color: AuthBrand.green,
                                                fontWeight: FontWeight.w600,
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: AuthBrand.ink,
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
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AuthBrand.ink,
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
          fontFamily: 'Inter', fontSize: 14, color: AuthBrand.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AuthBrand.hint,
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuthBrand.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuthBrand.green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 1.5),
        ),
        filled: true,
        fillColor: AuthBrand.surface,
        isDense: true,
      ),
    );
  }
}
