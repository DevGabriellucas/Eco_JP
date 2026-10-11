import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../features/auth/providers/auth_providers.dart';
import '../theme/app_icons.dart';
import '../theme/brand_fonts.dart';
import '../theme/marca_cores.dart';
import '../widgets/marca/botao_primario.dart';
import '../widgets/marca/botao_secundario.dart';
import '../widgets/marca/corpo_rolavel.dart';
import '../widgets/marca/icone_svg.dart';
import '../widgets/marca/medidas_marca.dart';

/// Tela exibida quando o usuário entrou com e-mail/senha mas ainda não
/// confirmou o e-mail. Bloqueia o acesso ao app até a confirmação.
///
/// O link sai no cadastro; aqui a confirmação é checada em segundo plano, com
/// reenvio (com tempo de espera) e troca de conta.
class VerificacaoEmailPage extends ConsumerStatefulWidget {
  const VerificacaoEmailPage({super.key});

  @override
  ConsumerState<VerificacaoEmailPage> createState() =>
      _VerificacaoEmailPageState();
}

class _VerificacaoEmailPageState extends ConsumerState<VerificacaoEmailPage>
    with WidgetsBindingObserver {
  late final _authService = ref.read(authServiceProvider);

  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _verificando = false;
  bool _enviando = false;
  bool _saindo = false;
  bool _confirmado = false;

  // Recarga em andamento, compartilhada: com rede lenta o timer chamava de
  // novo antes da anterior terminar e as recargas se empilhavam.
  Future<bool>? _checagem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Não envia e-mail ao abrir: o cadastro já envia assim que a conta tem
    // nome, e reenviar a cada abertura da tela (ou a cada login de conta não
    // confirmada) estourava o limite do Firebase e invalidava o link
    // anterior. Quem precisar usa "Reenviar".
    // O status de verificação não chega pelo authStateChanges, então checamos
    // periodicamente enquanto a tela está aberta.
    _iniciarPoll();
  }

  void _iniciarPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checarVerificacao(silencioso: true),
    );
  }

  // Quem confirma pelo app de e-mail volta para cá: confere na hora em vez de
  // esperar o próximo ciclo do timer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_confirmado) return;
        _checarVerificacao(silencioso: true);
        _iniciarPoll();
      // Em segundo plano não consulta a rede (bateria e dados); volta a
      // conferir quando o app reabre.
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _poll?.cancel();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _iniciarCooldown() {
    setState(() => _cooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _reenviar() async {
    if (_cooldown > 0 || _enviando) return;
    setState(() => _enviando = true);
    final result = await _authService.enviarEmailVerificacao();
    if (!mounted) return;
    setState(() => _enviando = false);
    if (result.success) _iniciarCooldown();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message ?? '')));
  }

  Future<void> _checarVerificacao({bool silencioso = false}) async {
    if (_verificando) return;
    if (!silencioso) setState(() => _verificando = true);
    final ok = await (_checagem ??= _authService
        .recarregarEVerificarEmail()
        .whenComplete(() => _checagem = null));
    if (!mounted) return;
    if (ok) {
      // Confirmado: o botão segue carregando até o router trocar de tela
      // (ele ainda carrega perfil e consentimento). Antes voltava ao normal
      // e a tela ficava parada, sem sinal de que algo acontecia.
      setState(() => _verificando = true);
      _confirmado = true;
      _poll?.cancel();
      // O e-mail confirmado não chega pelo authStateChanges; invalidar o
      // provider força uma nova emissão com emailVerified=true e o redirect
      // do router libera o acesso (home ou consentimento).
      ref.invalidate(authStateChangesProvider);
    } else if (!silencioso) {
      setState(() => _verificando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ainda não recebemos a confirmação. Abra o link no seu e-mail e tente de novo.',
          ),
        ),
      );
    }
  }

  Future<void> _sair() async {
    if (_saindo) return;
    // Um toque só: antes um segundo toque chamava o logout de novo.
    setState(() => _saindo = true);
    _poll?.cancel();
    // O logout emite null no authStateChanges e o redirect leva à tela inicial.
    try {
      await _authService.sair();
    } finally {
      if (mounted) setState(() => _saindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.emailAtual ?? 'seu e-mail';
    final largura = MediaQuery.sizeOf(context).width;

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
            // Três itens com spaceBetween: o bloco de conteúdo fica
            // centralizado no espaço acima dos botões, que ficam no pé.
            builder: (context, margem) => Padding(
              padding: EdgeInsets.fromLTRB(margem, 16, margem, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox.shrink(),
                  _Conteudo(email: email, largura: largura),
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: _acoes(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _acoes() {
    final esperando = _cooldown > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BotaoPrimario(
          texto: 'Já confirmei',
          carregando: _verificando,
          onPressed: _verificando ? null : () => _checarVerificacao(),
          icone: IconeSvg(
            AppIcons.check,
            cor: context.marca.sobreDestaque,
          ),
        ),
        const SizedBox(height: 12),
        BotaoSecundario(
          texto: esperando
              ? 'Reenviar e-mail em ${_cooldown}s'
              : 'Reenviar e-mail',
          carregando: _enviando,
          onPressed: (esperando || _enviando) ? null : _reenviar,
          icone: IconeSvg(
            AppIcons.send,
            cor: esperando ? context.marca.textoApoio : context.marca.texto,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saindo ? null : _sair,
          style: TextButton.styleFrom(
            foregroundColor: context.marca.destaque,
            minimumSize: const Size(48, 48),
            textStyle: BrandFonts.label.copyWith(fontSize: 15),
          ),
          child: const Text('Usar outra conta'),
        ),
      ],
    );
  }
}

/// Ilustração, título, e-mail e aviso. Não depende do estado da tela: o
/// contador do reenvio reconstrói só os botões.
class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.email, required this.largura});

  final String email;
  final double largura;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: RepaintBoundary(
            child: SvgPicture.asset(
              context.marca.ilustracaoEmail,
              width: (largura * 0.67).clamp(200.0, 300.0),
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Confirme seu e-mail',
          textAlign: TextAlign.center,
          style: BrandFonts.heading.copyWith(color: context.marca.texto),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: BrandFonts.body.copyWith(
              fontSize: 16,
              color: context.marca.textoApoio,
            ),
            children: [
              const TextSpan(text: 'Enviamos um link de confirmação para\n'),
              TextSpan(
                text: email,
                style: BrandFonts.label.copyWith(
                  color: context.marca.texto,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.marca.superficie,
            borderRadius: BorderRadius.circular(MedidasMarca.raio),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: IconeSvg(
                  AppIcons.clock,
                  cor: context.marca.linkSecundario,
                  tamanho: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A tela libera o acesso automaticamente. Não chegou? '
                  'Confira o spam ou peça outro abaixo.',
                  style: BrandFonts.body.copyWith(
                    fontSize: 14,
                    color: context.marca.textoApoio,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
