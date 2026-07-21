import 'package:flutter/material.dart';

import 'documentos_legais.dart';
import '../../theme/app_theme.dart';

/// Tela de consentimento exibida quando o usuário ainda não aceitou os
/// documentos legais (ou aceitou uma versão antiga). Bloqueia o acesso ao
/// app até o aceite explícito. Usada principalmente por contas Google (que
/// não passam pelo formulário de cadastro) e por usuários já existentes
/// após uma atualização da política.
class ConsentimentoPage extends StatefulWidget {
  /// Chamado quando o usuário aceita. O responsável deve registrar o
  /// consentimento e liberar o acesso.
  final Future<void> Function() onAceitar;

  const ConsentimentoPage({super.key, required this.onAceitar});

  @override
  State<ConsentimentoPage> createState() => _ConsentimentoPageState();
}

class _ConsentimentoPageState extends State<ConsentimentoPage> {
  bool _aceito = false;
  bool _processando = false;

  void _abrirDocumento(String titulo, String conteudo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentoLegalPage(titulo: titulo, conteudo: conteudo),
      ),
    );
  }

  Future<void> _confirmar() async {
    if (!_aceito || _processando) return;
    setState(() => _processando = true);
    try {
      await widget.onAceitar();
    } catch (_) {
      if (!mounted) return;
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível registrar agora. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final linkStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: pal.ink,
      decoration: TextDecoration.underline,
    );
    final textStyle = TextStyle(fontSize: 14, color: pal.muted);

    return Scaffold(
      backgroundColor: pal.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Icon(
                Icons.privacy_tip_outlined,
                size: 44,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              Text(
                'Privacidade e Termos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: pal.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Antes de continuar, precisamos do seu consentimento sobre como '
                'os seus dados são tratados no EcoJP.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: pal.muted,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Topico(
                        icone: Icons.location_on_outlined,
                        texto:
                            'Coletamos nome, e-mail e o conteúdo das suas '
                            'denúncias (fotos, vídeo, descrição e localização).',
                      ),
                      _Topico(
                        icone: Icons.visibility_off_outlined,
                        texto:
                            'Você pode denunciar de forma anônima — seu nome e '
                            'foto não aparecem para ninguém.',
                      ),
                      _Topico(
                        icone: Icons.shield_outlined,
                        texto:
                            'Denúncias podem ser triadas por órgãos públicos '
                            'cadastrados (verificação e acompanhamento).',
                      ),
                      _Topico(
                        icone: Icons.delete_outline,
                        texto:
                            'Você pode excluir suas denúncias e apagar a sua '
                            'conta e dados a qualquer momento.',
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _aceito,
                      onChanged: _processando
                          ? null
                          : (v) => setState(() => _aceito = v ?? false),
                      activeColor: AppColors.success,
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
                          child: Text(
                            'Política de Privacidade',
                            style: linkStyle,
                          ),
                        ),
                        Text(' e os ', style: textStyle),
                        GestureDetector(
                          onTap: () =>
                              _abrirDocumento('Termos de Uso', kTermosDeUso),
                          child: Text('Termos de Uso', style: linkStyle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_aceito && !_processando) ? _confirmar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pal.ink,
                    foregroundColor: pal.surface,
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _processando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: pal.surface,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Concordar e continuar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
}

class _Topico extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Topico({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: context.pal.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
