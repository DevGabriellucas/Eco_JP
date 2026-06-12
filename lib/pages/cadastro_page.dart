import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/usuario_service.dart';
import 'legal/documentos_legais.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  bool _isLoading = false;
  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  bool _aceitouTermos = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleCadastro() async {
    if (_nomeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Informe seu nome');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe seu nome')));
      return;
    }

    if (!_aceitouTermos) {
      setState(() =>
          _errorMessage = 'Você precisa aceitar os termos para continuar');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aceite a Política de Privacidade e os Termos de Uso'),
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'As senhas não coincidem');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('As senhas não coincidem')));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.cadastrar(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      // Cria o perfil já com o nome informado no cadastro.
      final uid = result.user?.uid;
      if (uid != null) {
        await _usuarioService.salvarPerfil(
          UsuarioModel(uid: uid, nome: _nomeController.text.trim()),
        );
        // Guarda o nome também no Auth (útil para exibir em notificações).
        await result.user?.updateDisplayName(_nomeController.text.trim());
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else {
      setState(() => _errorMessage = result.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Erro ao cadastrar')),
      );
    }
  }

  void _abrirDocumento(String titulo, String conteudo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentoLegalPage(titulo: titulo, conteudo: conteudo),
      ),
    );
  }

  Widget _buildAceiteTermos() {
    const linkStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
      decoration: TextDecoration.underline,
    );
    const textStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 13,
      color: Color(0xFF6B7280),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _aceitouTermos,
            onChanged: _isLoading
                ? null
                : (v) => setState(() => _aceitouTermos = v ?? false),
            activeColor: const Color(0xFF2C2C2C),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Li e aceito a ', style: textStyle),
              GestureDetector(
                onTap: () => _abrirDocumento(
                  'Política de Privacidade',
                  kPoliticaPrivacidade,
                ),
                child: const Text('Política de Privacidade', style: linkStyle),
              ),
              const Text(' e os ', style: textStyle),
              GestureDetector(
                onTap: () => _abrirDocumento('Termos de Uso', kTermosDeUso),
                child: const Text('Termos de Uso', style: linkStyle),
              ),
            ],
          ),
        ),
      ],
    );
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
                            _buildLabel('Nome'),
                            const SizedBox(height: 8),
                            _buildInput(
                              controller: _nomeController,
                              hint: 'Seu nome',
                            ),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 16),
                            _buildLabel('Repetir Senha'),
                            const SizedBox(height: 8),
                            _buildInput(
                              controller: _confirmPasswordController,
                              hint: 'Senha',
                              obscure: !_confirmarSenhaVisivel,
                              suffix: IconButton(
                                icon: Icon(
                                  _confirmarSenhaVisivel
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: const Color(0xFFBDBDBD),
                                ),
                                onPressed: () => setState(
                                  () => _confirmarSenhaVisivel =
                                      !_confirmarSenhaVisivel,
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
                            const SizedBox(height: 16),
                            _buildAceiteTermos(),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleCadastro,
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
                                    : const Text('Cadastrar'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context)
                                    .pushReplacementNamed('/login');
                              },
                              child: const Text(
                                'Já tem conta? Faça login',
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
