import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../theme/app_icons.dart';
import '../theme/brand_colors.dart';
import '../theme/brand_fonts.dart';
import '../widgets/marca/botao_primario.dart';
import '../widgets/marca/botao_secundario.dart';
import '../widgets/marca/botao_voltar.dart';
import '../widgets/marca/campo_marca.dart';
import '../widgets/marca/corpo_rolavel.dart';
import '../widgets/marca/icone_svg.dart';
import '../widgets/marca/indicador_carregando.dart';
import '../widgets/marca/medidas_marca.dart';
import '../widgets/marca/rodape_link.dart';
import '../widgets/marca/texto_erro.dart';

/// Login por e-mail/senha ou Google. Depois do login quem navega é o
/// redirect do router (home, verificação de e-mail ou consentimento).
///
/// Medidas do mockup do Figma (frame de ~360 de largura).
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
  // Borda vermelha nos campos só para erro de e-mail/senha; erro do login
  // Google aparece no texto, mas não marca a senha.
  bool _erroCredenciais = false;
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
      _erroCredenciais = false;
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
      _erroCredenciais = false;
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
        _erroCredenciais = true;
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
              // Diálogo abre fora da árvore da tela (sem o limite de fonte):
              // com fonte grande e teclado aberto o conteúdo não cabia.
              scrollable: true,
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
                    style: estiloCampoMarca,
                    decoration: decoracaoCampoMarca(hint: 'seu@email.com'),
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
                      borderRadius: BorderRadius.circular(MedidasMarca.raio),
                    ),
                    textStyle: BrandFonts.label.copyWith(fontSize: 14),
                  ),
                  child: enviando
                      ? const IndicadorCarregando(cor: BrandColors.onPrimary)
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
    final largura = MediaQuery.sizeOf(context).width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        systemNavigationBarColor: BrandColors.surfaceLight,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2.0,
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
                    // Teto de 480 de referência: em tablet o desenho ficava 2,2x
                    // maior, com traço grosso.
                    width: (largura < 480 ? largura : 480) * 320 / 360,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              CorpoRolavel(
                builder: (context, margem) => _conteudo(largura, margem),
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
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: RodapeLink(
            pergunta: 'Não tem conta?',
            acao: 'Cadastre-se',
            onPressed: () => context.push(Routes.cadastro),
          ),
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
            child: const BotaoVoltar(rotaSemAnterior: Routes.inicial),
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
                    CampoMarca(
                      rotulo: 'EMAIL',
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        style: estiloCampoMarca,
                        decoration: decoracaoCampoMarca(
                          hint: 'seu@email.com',
                          prefixo: AppIcons.message,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    CampoMarca(
                      rotulo: 'SENHA',
                      child: TextField(
                        controller: _passwordController,
                        obscureText: !_senhaVisivel,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _handleLogin(),
                        style: estiloCampoMarca,
                        decoration: decoracaoCampoMarca(
                          hint: 'Sua senha',
                          erro: _erroCredenciais,
                          sufixo: IconButton(
                            tooltip: _senhaVisivel
                                ? 'Ocultar senha'
                                : 'Mostrar senha',
                            onPressed: () =>
                                setState(() => _senhaVisivel = !_senhaVisivel),
                            // Só existe o ícone de olho fechado nos assets.
                            icon: const IconeSvg(AppIcons.eyeClosed),
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
                  child: TextoErro(_errorMessage!),
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
              BotaoPrimario(
                texto: 'Logar',
                carregando: _isLoading,
                // Desabilitado também durante o login Google (dois logins em
                // paralelo).
                onPressed: _ocupado ? null : _handleLogin,
              ),
              const SizedBox(height: 20),
              const _Divisor(),
              const SizedBox(height: 20),
              BotaoSecundario(
                texto: 'Logar com Google',
                carregando: _isLoadingGoogle,
                onPressed: _ocupado ? null : _handleLoginGoogle,
                icone: SvgPicture.asset(
                  AppLogos.google,
                  width: 20,
                  height: 20,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
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
