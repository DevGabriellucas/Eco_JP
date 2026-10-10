import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/brand_colors.dart';
import '../theme/brand_fonts.dart';
import '../utils/margem_responsiva.dart';

/// Login por e-mail/senha ou Google. Depois do login quem navega é o
/// redirect do router (home, verificação de e-mail ou consentimento).
///
/// Medidas do mockup do Figma (frame de ~360 de largura).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

const _margem = 24.0;
// Em tablet e paisagem o formulário não estica: coluna de até 440 dp,
// centralizada.
const _larguraMaxConteudo = 440.0;
const _raio = 12.0;
const _alturaBotao = 52.0;

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingGoogle = false;
  bool _senhaVisivel = false;
  String? _errorMessage;

  bool get _ocupado => _isLoading || _isLoadingGoogle;

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
    // Sucesso: o redirect do router leva para /home (ou para o gate de
    // consentimento) reagindo à mudança de authState.
    setState(() {
      _isLoadingGoogle = false;
      if (!result.success) {
        _errorMessage = result.message ?? 'Erro ao entrar com Google';
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_ocupado) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(authServiceProvider)
        .login(_emailController.text.trim(), _passwordController.text);

    if (!mounted) return;
    // Sucesso: o redirect do router assume a navegação (home / verificação
    // de e-mail / consentimento, conforme o estado da conta). O erro aparece
    // só abaixo da senha; antes saía também num snackbar, repetido.
    setState(() {
      _isLoading = false;
      if (!result.success) {
        _errorMessage = result.message ?? 'Erro ao fazer login';
      }
    });
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
              backgroundColor: BrandColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Recuperar senha',
                style: BrandFonts.label.copyWith(
                  fontSize: 18,
                  color: BrandColors.textOnLight,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digite seu email e enviaremos um link para você '
                    'redefinir sua senha.',
                    style: BrandFonts.body.copyWith(
                      fontSize: 14,
                      color: BrandColors.textOnLightMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    style: _estiloCampo,
                    decoration: _decoracaoCampo(hint: 'seu@email.com'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.textOnLightMuted,
                    textStyle: BrandFonts.label.copyWith(fontSize: 14),
                  ),
                  child: const Text('Cancelar'),
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
                          // Erro (e-mail inválido, sem rede): mantém o diálogo
                          // aberto com o texto digitado, para corrigir e
                          // tentar de novo — antes fechava e perdia tudo.
                          if (!result.success) {
                            setDialogState(() => enviando = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(result.message ?? '')),
                            );
                            return;
                          }
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
                    backgroundColor: BrandColors.primary,
                    foregroundColor: BrandColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_raio),
                    ),
                    textStyle: BrandFonts.label.copyWith(fontSize: 14),
                  ),
                  child: enviando
                      ? const _Carregando(cor: BrandColors.onPrimary)
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

  void _voltar() {
    // Veio da inicial por push: volta para ela no mesmo slide. Sem tela
    // anterior (link externo, redirect), vai para a inicial.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.inicial);
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        systemNavigationBarColor: BrandColors.surfaceLight,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Scaffold(
          backgroundColor: BrandColors.surfaceLight,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Curvas de nível no canto superior direito, como no mockup.
              Positioned(
                top: 0,
                right: 0,
                child: RepaintBoundary(
                  child: SvgPicture.asset(
                    AppIllustrations.contourLinesLight,
                    width: largura * 320 / 360,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  // Altura mínima = tela: o rodapé fica no pé quando sobra
                  // espaço e rola junto quando não cabe (teclado, tela
                  // baixa). Antes era SliverFillRemaining, que mede a altura
                  // intrínseca do formulário inteiro a cada layout — a cada
                  // frame da animação do teclado.
                  builder: (context, c) => SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: _conteudo(
                        largura,
                        margemResponsiva(
                          c.maxWidth,
                          margemMinima: _margem,
                          larguraMaxima: _larguraMaxConteudo,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo(double largura, double margem) {
    // spaceBetween com altura mínima: formulário em cima, rodapé embaixo,
    // sem Spacer (que exigiria altura limitada) nem medição intrínseca.
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _formulario(largura, margem),
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 8),
          child: _RodapeCadastro(),
        ),
      ],
    );
  }

  Widget _formulario(double largura, double margem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            // O IconButton tem 12 de folga interna: a seta fica na margem.
            padding: EdgeInsets.only(left: margem - 12, top: 4),
            child: IconButton(
              tooltip: 'Voltar',
              onPressed: _voltar,
              icon: SvgPicture.asset(
                AppIcons.arrowBack,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  BrandColors.textOnLight,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margem),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: SvgPicture.asset(
                  AppLogos.ecohubOnLight,
                  width: (largura * 137 / 360).clamp(120.0, 180.0),
                  semanticsLabel: 'ecohub',
                ),
              ),
              const SizedBox(height: 36),
              Text(
                'Entrar',
                style: BrandFonts.heading.copyWith(
                  color: BrandColors.textOnLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Acompanhe e registre denúncias na sua cidade.',
                style: BrandFonts.body.copyWith(
                  fontSize: 16,
                  color: BrandColors.textOnLightMuted,
                ),
              ),
              const SizedBox(height: 24),
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Campo(
                      rotulo: 'EMAIL',
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        style: _estiloCampo,
                        decoration: _decoracaoCampo(
                          hint: 'seu@email.com',
                          prefixo: AppIcons.message,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Campo(
                      rotulo: 'SENHA',
                      child: TextField(
                        controller: _passwordController,
                        obscureText: !_senhaVisivel,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _handleLogin(),
                        style: _estiloCampo,
                        decoration: _decoracaoCampo(
                          hint: 'Sua senha',
                          erro: _errorMessage != null,
                          sufixo: IconButton(
                            tooltip: _senhaVisivel
                                ? 'Ocultar senha'
                                : 'Mostrar senha',
                            onPressed: () =>
                                setState(() => _senhaVisivel = !_senhaVisivel),
                            // Só existe o ícone de olho fechado nos assets.
                            icon: const _IconeSvg(AppIcons.eyeClosed),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage!,
                    style: BrandFonts.body.copyWith(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _ocupado ? null : _handleEsqueceuSenha,
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.linkSecondary,
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    textStyle: BrandFonts.label.copyWith(fontSize: 14),
                  ),
                  child: const Text('Esqueceu a senha?'),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                // Desabilitado também durante o login Google (dois logins em
                // paralelo).
                onPressed: _ocupado ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.primary,
                  foregroundColor: BrandColors.onPrimary,
                  disabledBackgroundColor:
                      BrandColors.primary.withValues(alpha: 0.6),
                  disabledForegroundColor: BrandColors.onPrimary,
                  minimumSize: const Size.fromHeight(_alturaBotao),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_raio),
                  ),
                  textStyle: BrandFonts.label,
                ),
                child: _isLoading
                    ? const _Carregando(cor: BrandColors.onPrimary)
                    : const Text('Logar'),
              ),
              const SizedBox(height: 20),
              const _Divisor(),
              const SizedBox(height: 20),
              _BotaoGoogle(
                carregando: _isLoadingGoogle,
                onPressed: _ocupado ? null : _handleLoginGoogle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final _estiloCampo = BrandFonts.body.copyWith(
  fontSize: 16,
  height: 1.25,
  color: BrandColors.textOnLight,
);

InputDecoration _decoracaoCampo({
  required String hint,
  String? prefixo,
  Widget? sufixo,
  bool erro = false,
}) {
  OutlineInputBorder borda(Color cor, double largura) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(_raio),
        borderSide: BorderSide(color: cor, width: largura),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: _estiloCampo.copyWith(color: BrandColors.textOnLightMuted),
    filled: true,
    fillColor: BrandColors.surfaceLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: prefixo == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: _IconeSvg(prefixo),
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    suffixIcon: sufixo,
    enabledBorder: borda(
      erro ? AppColors.danger : BrandColors.neutralSoft,
      1,
    ),
    focusedBorder: borda(
      erro ? AppColors.danger : BrandColors.primary,
      1.5,
    ),
  );
}

/// Ícone dos campos: os SVGs vêm do Figma claros (para fundo escuro); aqui o
/// fundo é branco, então pinta com o cinza de apoio.
class _IconeSvg extends StatelessWidget {
  const _IconeSvg(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: 20,
      height: 20,
      excludeFromSemantics: true,
      colorFilter: const ColorFilter.mode(
        BrandColors.textOnLightMuted,
        BlendMode.srcIn,
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({required this.rotulo, required this.child});

  final String rotulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: BrandFonts.caption.copyWith(
            letterSpacing: 1.5,
            color: BrandColors.textOnLight,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _Divisor extends StatelessWidget {
  const _Divisor();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: BrandColors.neutralSoft)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou',
            style: BrandFonts.caption.copyWith(
              color: BrandColors.textOnLightMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: BrandColors.neutralSoft)),
      ],
    );
  }
}

class _BotaoGoogle extends StatelessWidget {
  const _BotaoGoogle({required this.carregando, required this.onPressed});

  final bool carregando;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: BrandColors.surfaceLight,
        foregroundColor: BrandColors.textOnLight,
        side: const BorderSide(color: BrandColors.neutralSoft),
        minimumSize: const Size.fromHeight(_alturaBotao),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_raio),
        ),
        textStyle: BrandFonts.label.copyWith(fontSize: 15),
      ),
      child: carregando
          ? const _Carregando(cor: BrandColors.textOnLight)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AppLogos.google,
                  width: 20,
                  height: 20,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Logar com Google',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

class _RodapeCadastro extends StatelessWidget {
  const _RodapeCadastro();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Não tem conta?',
          style: BrandFonts.body.copyWith(
            fontSize: 15,
            color: BrandColors.textOnLightMuted,
          ),
        ),
        TextButton(
          onPressed: () => context.push(Routes.cadastro),
          style: TextButton.styleFrom(
            foregroundColor: BrandColors.primary,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle: BrandFonts.label.copyWith(fontSize: 15),
          ),
          child: const Text('Cadastre-se'),
        ),
      ],
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando({required this.cor});

  final Color cor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: cor),
    );
  }
}
