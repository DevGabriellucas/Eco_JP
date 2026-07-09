import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Tela exibida quando o usuário entrou com e-mail/senha mas ainda não
/// confirmou o e-mail. Bloqueia o acesso ao app até a confirmação.
///
/// Envia o link automaticamente ao abrir, checa a confirmação em segundo plano
/// e oferece reenvio (com tempo de espera) e troca de conta.
class VerificacaoEmailPage extends StatefulWidget {
  const VerificacaoEmailPage({super.key});

  @override
  State<VerificacaoEmailPage> createState() => _VerificacaoEmailPageState();
}

class _VerificacaoEmailPageState extends State<VerificacaoEmailPage> {
  final _authService = AuthService();

  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _verificando = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _enviarInicial();
    // O status de verificação não chega pelo authStateChanges, então checamos
    // periodicamente enquanto a tela está aberta.
    _poll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checarVerificacao(silencioso: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _enviarInicial() async {
    final result = await _authService.enviarEmailVerificacao();
    if (!mounted) return;
    if (result.success) _iniciarCooldown();
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
    final ok = await _authService.recarregarEVerificarEmail();
    if (!mounted) return;
    if (!silencioso) setState(() => _verificando = false);
    if (ok) {
      _poll?.cancel();
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else if (!silencioso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ainda nao recebemos a confirmacao. Abra o link no seu e-mail e tente de novo.',
          ),
        ),
      );
    }
  }

  Future<void> _sair() async {
    _poll?.cancel();
    await _authService.sair();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/inicial', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.emailAtual ?? 'seu e-mail';

    return Scaffold(
      backgroundColor: const Color(0xFF0A1018),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: Color(0xFF2C2C2C),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Confirme seu e-mail',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF6B7280),
                      ),
                      children: [
                        const TextSpan(
                          text: 'Enviamos um link de confirmacao para\n',
                        ),
                        TextSpan(
                          text: email,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const TextSpan(
                          text:
                              '.\n\nAbra o e-mail, toque no link e volte aqui. '
                              'A tela libera o acesso automaticamente.',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _verificando
                          ? null
                          : () => _checarVerificacao(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2C),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF2C2C2C,
                        ).withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: _verificando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Ja confirmei'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: (_cooldown > 0 || _enviando) ? null : _reenviar,
                    child: Text(
                      _cooldown > 0
                          ? 'Reenviar e-mail em ${_cooldown}s'
                          : 'Reenviar e-mail',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _cooldown > 0
                            ? const Color(0xFFBDBDBD)
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const Divider(height: 24, color: Color(0xFFEEEEEE)),
                  TextButton(
                    onPressed: _sair,
                    child: const Text(
                      'Usar outra conta',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
