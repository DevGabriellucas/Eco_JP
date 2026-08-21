import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../models/usuario_model.dart';
import '../services/usuario_service.dart';
import 'legal/documentos_legais.dart';
import '../theme/app_theme.dart';

class CadastroPage extends ConsumerStatefulWidget {
  const CadastroPage({super.key});

  @override
  ConsumerState<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends ConsumerState<CadastroPage> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usuarioService = UsuarioService();
  bool _isLoading = false;
  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  bool _aceitouTermos = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Atualiza o medidor de força conforme o usuário digita a senha.
    _passwordController.addListener(_onSenhaChanged);
  }

  void _onSenhaChanged() => setState(() {});

  // Pontuação simples de 0 a 4 para a força da senha. Cada critério atendido
  // (tamanho, variação de caixa, números e símbolos) soma um ponto.
  int _forcaSenha(String s) {
    if (s.isEmpty) return 0;
    var score = 0;
    if (s.length >= 6) score++;
    if (s.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(s) && RegExp(r'[a-z]').hasMatch(s)) score++;
    if (RegExp(r'[0-9]').hasMatch(s)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(s)) score++;
    return score.clamp(0, 4);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onSenhaChanged);
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
      setState(
        () => _errorMessage = 'Você precisa aceitar os termos para continuar',
      );
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

    // Exige pelo menos "razoável" no medidor (score 2 de 4) — o mínimo do
    // próprio Firebase é só 6 caracteres, insuficiente contra senhas comuns.
    if (_forcaSenha(_passwordController.text) < 2) {
      const msg =
          'Escolha uma senha mais forte: use letras maiúsculas e '
          'minúsculas, números ou símbolos.';
      setState(() => _errorMessage = msg);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(msg)));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Captura os serviços enquanto o widget está montado: as escritas abaixo
    // seguem mesmo depois que o redirect do router troca a tela para a
    // verificação de e-mail (senão o `ref` ficaria inválido).
    final authService = ref.read(authServiceProvider);
    final consentService = ref.read(consentServiceProvider);
    final nome = _nomeController.text.trim();

    // Cria a conta PRIMEIRO: a checagem de nome único lê a coleção `usuarios`,
    // que as Firestore Rules só liberam para usuários autenticados. Por isso a
    // validação de nome vem depois da criação (com rollback se o nome colidir).
    final result = await authService.cadastrar(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!result.success) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Erro ao cadastrar')),
      );
      return;
    }

    final uid = result.user?.uid;
    if (uid == null) return;

    try {
      // Nome já em uso por outra conta: desfaz este cadastro para não deixar
      // conta órfã. O redirect reage ao delete voltando à tela inicial.
      if (await _usuarioService.nomeEmUso(nome, ignorarUid: uid)) {
        await result.user?.delete();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Esse nome já está em uso. Escolha outro.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esse nome já está em uso. Escolha outro.'),
          ),
        );
        return;
      }

      // Cria o perfil com o nome, salva o nome no Auth (usado em notificações)
      // e registra o consentimento aceito (LGPD art. 8 §1). O redirect leva à
      // verificação de e-mail automaticamente.
      await _usuarioService.salvarPerfil(UsuarioModel(uid: uid, nome: nome));
      await result.user?.updateDisplayName(nome);
      await consentService.registrar(uid);
    } catch (e) {
      // Falha pós-criação (rede/permissão): NÃO deixa a UI travada no loading
      // (bug que a reordenação anterior causava). O redirect já levou o usuário
      // à verificação de e-mail; a conta existe e o perfil pode ser completado.
      debugPrint('Erro pós-cadastro: $e');
      if (mounted) setState(() => _isLoading = false);
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
    final pal = context.pal;
    final linkStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: pal.ink,
      decoration: TextDecoration.underline,
    );
    final textStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 13,
      color: pal.muted,
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
            activeColor: pal.ink,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Li e aceito a ', style: textStyle),
              GestureDetector(
                onTap: () => _abrirDocumento(
                  'Política de Privacidade',
                  kPoliticaPrivacidade,
                ),
                child: Text('Política de Privacidade', style: linkStyle),
              ),
              Text(' e os ', style: textStyle),
              GestureDetector(
                onTap: () => _abrirDocumento('Termos de Uso', kTermosDeUso),
                child: Text('Termos de Uso', style: linkStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double logoSize = (screenWidth * 0.32).clamp(110.0, 150.0);
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
                errorBuilder: (context, error, stackTrace) =>
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
                              child: SvgPicture.asset(
                                'assets/icons/seta.svg',
                                width: 44,
                                height: 44,
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                                color: pal.surface,
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
                                      tooltip: _senhaVisivel
                                          ? 'Ocultar senha'
                                          : 'Mostrar senha',
                                      icon: Icon(
                                        _senhaVisivel
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                        color: pal.hint,
                                      ),
                                      onPressed: () => setState(
                                        () => _senhaVisivel = !_senhaVisivel,
                                      ),
                                    ),
                                  ),
                                  if (_passwordController.text.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _MedidorForcaSenha(
                                      forca: _forcaSenha(
                                        _passwordController.text,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  _buildLabel('Repetir Senha'),
                                  const SizedBox(height: 8),
                                  _buildInput(
                                    controller: _confirmPasswordController,
                                    hint: 'Senha',
                                    obscure: !_confirmarSenhaVisivel,
                                    suffix: IconButton(
                                      tooltip: _confirmarSenhaVisivel
                                          ? 'Ocultar senha'
                                          : 'Mostrar senha',
                                      icon: Icon(
                                        _confirmarSenhaVisivel
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                        color: pal.hint,
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
                                      onPressed: _isLoading
                                          ? null
                                          : _handleCadastro,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: pal.ink,
                                        foregroundColor: pal.surface,
                                        disabledBackgroundColor: pal.ink
                                            .withValues(alpha: 0.6),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: pal.surface,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Cadastrar'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () {
                                      context.go(Routes.login);
                                    },
                                    child: Text(
                                      'Já tem conta? Faça login',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: pal.ink,
                                        decoration: TextDecoration.underline,
                                        decorationColor: pal.ink,
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
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: context.pal.ink,
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
    final pal = context.pal;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(fontFamily: 'Roboto', fontSize: 14, color: pal.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          color: pal.hint,
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: pal.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: pal.ink, width: 1.5),
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
        fillColor: pal.surface,
        isDense: true,
      ),
    );
  }
}

// Barra de força da senha: 3 segmentos coloridos + rótulo. Recebe uma
// pontuação de 0 a 4 calculada em _forcaSenha.
class _MedidorForcaSenha extends StatelessWidget {
  final int forca;

  const _MedidorForcaSenha({required this.forca});

  @override
  Widget build(BuildContext context) {
    // 0-2 = fraca (1 segmento), 3 = média (2 segmentos), 4 = forte (3).
    final int nivel = forca <= 2 ? 1 : (forca == 3 ? 2 : 3);
    final Color cor = switch (nivel) {
      1 => AppColors.danger,
      2 => const Color(0xFFF59E0B),
      _ => AppColors.success,
    };
    final String label = switch (nivel) {
      1 => 'Senha fraca',
      2 => 'Senha média',
      _ => 'Senha forte',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final aceso = i < nivel;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5,
                  decoration: BoxDecoration(
                    color: aceso ? cor : context.pal.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cor,
          ),
        ),
      ],
    );
  }
}
