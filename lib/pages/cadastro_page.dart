import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../models/usuario_model.dart';
import '../services/usuario_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/brand_fonts.dart';
import '../theme/marca_cores.dart';
import '../utils/texto.dart';
import '../widgets/marca/aceite_termos.dart';
import '../widgets/marca/botao_primario.dart';
import '../widgets/marca/botao_voltar.dart';
import '../widgets/marca/campo_marca.dart';
import '../widgets/marca/corpo_rolavel.dart';
import '../widgets/marca/icone_svg.dart';
import '../widgets/marca/rodape_link.dart';
import '../widgets/marca/texto_erro.dart';
import 'legal/documentos_legais.dart';

/// Cadastro por e-mail/senha: cria a conta, reserva o nome público, grava
/// perfil e consentimento e envia o e-mail de confirmação. Depois o redirect
/// do router leva à verificação de e-mail.
///
/// Medidas do mockup do Figma (frame de ~360 de largura).
class CadastroPage extends ConsumerStatefulWidget {
  const CadastroPage({super.key});

  @override
  ConsumerState<CadastroPage> createState() => _CadastroPageState();
}

/// Pontuação simples de 0 a 4 para a força da senha. Cada critério atendido
/// (tamanho, variação de caixa, números e símbolos) soma um ponto.
int forcaSenha(String s) {
  if (s.isEmpty) return 0;
  var score = 0;
  if (s.length >= 6) score++;
  if (s.length >= 10) score++;
  if (RegExp(r'[A-Z]').hasMatch(s) && RegExp(r'[a-z]').hasMatch(s)) score++;
  if (RegExp(r'[0-9]').hasMatch(s)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(s)) score++;
  return score.clamp(0, 4);
}

class _CadastroPageState extends ConsumerState<CadastroPage> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _senhaVisivel = false;
  bool _aceitouTermos = false;
  String? _errorMessage;

  // Só na hora de gravar: criar o serviço já toca no Firestore.
  UsuarioService get _usuarioService => UsuarioService.instance;

  static const _maxNome = 40;

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
      _falhar('Informe seu nome');
      return;
    }

    // O nome vira o ID da reserva de unicidade, e esse ID é o slug do nome.
    // Um nome só de pontuação não gera slug e não teria como ser reservado —
    // recusa aqui, antes de criar a conta, em vez de falhar depois.
    if (UsuarioService.idDoNome(_nomeController.text) == null) {
      _falhar('Use ao menos uma letra ou número no nome');
      return;
    }

    if (!_aceitouTermos) {
      _falhar('Aceite a Política de Privacidade e os Termos de Uso');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _falhar('As senhas não coincidem');
      return;
    }

    // Exige pelo menos "razoável" no medidor (score 2 de 4) — o mínimo do
    // próprio Firebase é só 6 caracteres, insuficiente contra senhas comuns.
    if (forcaSenha(_passwordController.text) < 2) {
      _falhar(
        'Escolha uma senha mais forte: use letras maiúsculas e minúsculas, '
        'números ou símbolos.',
      );
      return;
    }

    // Mesmo texto que o perfil vai gravar (salvarPerfil higieniza) e mesmo
    // limite das regras (nome ≤ 40 em usuarios e nomes_reservados).
    final nome = sanitizarLinhaUnica(_nomeController.text);
    if (nome.length > _maxNome) {
      _falhar('Use um nome com até $_maxNome caracteres');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final consentService = ref.read(consentServiceProvider);
    final emAndamento = ref.read(cadastroEmAndamentoProvider.notifier);

    // Segura o redirect: sem isto, criar a conta levava na hora para
    // /verificacao-email e esta página era desmontada no meio da reserva.
    emAndamento.state = true;
    try {
      // Cria a conta PRIMEIRO: a reserva do nome escreve em
      // `nomes_reservados`, que as Rules só liberam para usuários
      // autenticados (com rollback se o nome colidir).
      final result = await authService.cadastrar(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!result.success) {
        _falhar(result.message ?? 'Erro ao cadastrar');
        return;
      }
      final user = result.user;
      if (user == null) return;

      // Reserva atômica pelas Rules (ver match /nomes_reservados). Nome
      // indisponível: desfaz a conta para não deixar órfã — e como a página
      // continua montada, a pessoa vê o motivo e pode trocar o nome.
      if (!await _usuarioService.reservarNome(nome, user.uid)) {
        await user.delete();
        _falhar('Esse nome já está em uso. Escolha outro.');
        return;
      }

      // Perfil, nome no Auth (usado em notificações) e consentimento
      // (LGPD art. 8 §1). O e-mail de verificação só sai agora que a conta
      // tem nome — antes ele chegava para contas já apagadas.
      await _usuarioService
          .salvarPerfil(UsuarioModel(uid: user.uid, nome: nome));
      await user.updateDisplayName(nome);
      await consentService.registrar(user.uid);
      await authService.enviarEmailVerificacao();
    } catch (e) {
      // Falha pós-criação (rede/permissão): a conta existe; o portão de
      // perfil (perfilGarantidoProvider) completa o que faltar após a
      // verificação do e-mail, reaproveitando a reserva se ela foi feita.
      debugPrint('Erro pós-cadastro: $e');
      // A conta existe e o redirect vai levar à confirmação, que diz
      // "Enviamos um link…": tenta mandar o e-mail mesmo assim (antes não
      // saía, e a pessoa esperava um link que nunca chegava). Se falhar de
      // novo, o "Reenviar" da tela continua lá.
      try {
        await authService.enviarEmailVerificacao();
      } catch (e2) {
        debugPrint('Envio do e-mail após erro no cadastro falhou: $e2');
      }
      if (mounted) setState(() => _isLoading = false);
    } finally {
      // Libera o redirect: com conta criada vai para a verificação; sem conta
      // (falha ou nome em uso) fica aqui.
      emAndamento.state = false;
    }
  }

  /// Mostra o erro acima do botão, uma vez só (antes saía também num
  /// snackbar, repetido).
  void _falhar(String mensagem) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = mensagem;
    });
  }

  void _abrirDocumento(String titulo, String conteudo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentoLegalPage(titulo: titulo, conteudo: conteudo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        systemNavigationBarColor: context.marca.fundo,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2.0,
        child: Scaffold(
          backgroundColor: context.marca.fundo,
          body: CorpoRolavel(
            // Formulário em cima, rodapé no pé (ou rolando junto).
            builder: (context, margem) => Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _formulario(margem),
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: RodapeLink(
                    pergunta: 'Já tem conta?',
                    acao: 'Faça login',
                    onPressed:
                        _isLoading ? null : () => context.go(Routes.login),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario(double margem) {
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
              const SizedBox(height: 12),
              Text(
                'Criar conta',
                style: BrandFonts.heading.copyWith(
                  color: context.marca.texto,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registre e acompanhe denúncias da sua cidade.',
                style: BrandFonts.body.copyWith(
                  fontSize: 16,
                  color: context.marca.textoApoio,
                ),
              ),
              const SizedBox(height: 24),
              AutofillGroup(child: _campos()),
              const SizedBox(height: 16),
              AceiteTermos(
                valor: _aceitouTermos,
                onChanged: _isLoading
                    ? null
                    : (v) => setState(() => _aceitouTermos = v),
                onAbrirPolitica: () => _abrirDocumento(
                  'Política de Privacidade',
                  kPoliticaPrivacidade,
                ),
                onAbrirTermos: () =>
                    _abrirDocumento('Termos de Uso', kTermosDeUso),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextoErro(_errorMessage!),
                ),
              const SizedBox(height: 16),
              BotaoPrimario(
                texto: 'Cadastrar',
                carregando: _isLoading,
                onPressed: _isLoading ? null : _handleCadastro,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _campos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoMarca(
          rotulo: 'NOME',
          child: TextField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            // Teto das regras, sem o contador "0/40".
            maxLength: _maxNome,
            inputFormatters: [
              FilteringTextInputFormatter.allow(caractereDeNome),
            ],
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) =>
                null,
            style: estiloCampoMarca(context),
            decoration: decoracaoCampoMarca(
              context,
              hint: 'Seu nome',
              prefixo: AppIcons.people,
            ),
          ),
        ),
        const SizedBox(height: 22),
        CampoMarca(
          rotulo: 'EMAIL',
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            style: estiloCampoMarca(context),
            decoration: decoracaoCampoMarca(
              context,
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
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            style: estiloCampoMarca(context),
            decoration: decoracaoCampoMarca(
              context,
              hint: 'Crie uma senha',
              sufixo: IconButton(
                tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                // Só existe o ícone de olho fechado nos assets.
                icon: const IconeSvg(AppIcons.eyeClosed),
              ),
            ),
          ),
        ),
        // Só o medidor reconstrói a cada tecla (antes a página inteira).
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _passwordController,
          builder: (context, valor, _) => valor.text.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: MedidorForcaSenha(forca: forcaSenha(valor.text)),
                ),
        ),
        const SizedBox(height: 22),
        CampoMarca(
          rotulo: 'REPETIR SENHA',
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _passwordController,
              _confirmPasswordController,
            ]),
            builder: (context, _) {
              final confere = _confirmPasswordController.text.isNotEmpty &&
                  _confirmPasswordController.text == _passwordController.text;
              return TextField(
                controller: _confirmPasswordController,
                // Segue o olho da senha: o mockup não tem olho próprio aqui.
                obscureText: !_senhaVisivel,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _handleCadastro(),
                style: estiloCampoMarca(context),
                decoration: decoracaoCampoMarca(
                  context,
                  hint: 'Repita a senha',
                  sufixo: confere
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: IconeSvg(
                            AppIcons.check,
                            cor: context.marca.destaque,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Barra de força da senha: 3 segmentos + rótulo. Recebe a pontuação de 0 a
/// 4 de [forcaSenha].
@visibleForTesting
class MedidorForcaSenha extends StatelessWidget {
  const MedidorForcaSenha({super.key, required this.forca});

  final int forca;

  @override
  Widget build(BuildContext context) {
    // Mesmo corte de _handleCadastro (aceita pontuação >= 2): 0-1 = fraca,
    // recusada (1 segmento); 2 = média (2); 3-4 = forte (3).
    final nivel = forca <= 1 ? 1 : (forca == 2 ? 2 : 3);
    final cor = switch (nivel) {
      1 => AppColors.danger,
      2 => AppColors.warning,
      _ => context.marca.destaque,
    };
    final rotulo = switch (nivel) {
      1 => 'Senha fraca',
      2 => 'Senha média',
      _ => 'Senha forte',
    };

    return Semantics(
      label: rotulo,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < nivel ? cor : context.marca.borda,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (nivel == 3) ...[
                IconeSvg(AppIcons.check, cor: cor, tamanho: 16),
                const SizedBox(width: 4),
              ],
              Text(
                rotulo,
                style: BrandFonts.label.copyWith(
                  fontSize: 13,
                  fontWeight: BrandFonts.medium,
                  color: cor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
