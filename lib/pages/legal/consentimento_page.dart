import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_icons.dart';
import '../../theme/brand_colors.dart';
import '../../theme/brand_fonts.dart';
import '../../utils/margem_responsiva.dart';
import '../../widgets/marca/aceite_termos.dart';
import '../../widgets/marca/botao_primario.dart';
import '../../widgets/marca/icone_svg.dart';
import '../../widgets/marca/medidas_marca.dart';
import 'documentos_legais.dart';

/// Tela de consentimento exibida quando o usuário ainda não aceitou os
/// documentos legais (ou aceitou uma versão antiga). Bloqueia o acesso ao
/// app até o aceite explícito. Usada principalmente por contas Google (que
/// não passam pelo formulário de cadastro) e por usuários já existentes
/// após uma atualização da política.
class ConsentimentoPage extends StatefulWidget {
  /// Chamado quando o usuário aceita. O responsável deve registrar o
  /// consentimento e liberar o acesso.
  final Future<void> Function() onAceitar;

  /// Chamado em "Não concordo": encerra a sessão. Sem esta saída a tela não
  /// tinha alternativa ao aceite (consentimento não era livre).
  final Future<void> Function() onRecusar;

  const ConsentimentoPage({
    super.key,
    required this.onAceitar,
    required this.onRecusar,
  });

  @override
  State<ConsentimentoPage> createState() => _ConsentimentoPageState();
}

class _Topico {
  const _Topico(this.icone, this.texto);

  final String icone;
  final String texto;
}

const _topicos = [
  _Topico(
    AppIcons.camera,
    'Coletamos nome, e-mail e o conteúdo das suas denúncias (fotos, vídeo, '
    'descrição e localização).',
  ),
  // Antes prometia "não aparecem para ninguém", mas a autoridade pode
  // identificar o autor (dono/info).
  _Topico(
    AppIcons.eyeClosed,
    'Você pode denunciar de forma anônima: seu nome e foto não aparecem para '
    'outros usuários, mas o órgão público responsável pode identificar o '
    'autor quando necessário.',
  ),
  _Topico(
    AppIcons.safeShield,
    'Denúncias podem ser triadas por órgãos públicos cadastrados '
    '(verificação e acompanhamento).',
  ),
  _Topico(
    AppIcons.trash,
    'Você pode excluir suas denúncias e apagar a sua conta e dados a '
    'qualquer momento.',
  ),
];

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        systemNavigationBarColor: BrandColors.surfaceLight,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Scaffold(
          backgroundColor: BrandColors.surfaceLight,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final margem = margemResponsiva(
                  c.maxWidth,
                  margemMinima: MedidasMarca.margemLateral,
                  larguraMaxima: MedidasMarca.larguraMaxConteudo,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A explicação rola; aceite e botões ficam fixos embaixo.
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(margem, 24, margem, 16),
                        child: const _Explicacao(),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: BrandColors.neutralSoft,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(margem, 12, margem, 8),
                      child: _acoes(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _acoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AceiteTermos(
          valor: _aceito,
          onChanged: _processando ? null : (v) => setState(() => _aceito = v),
          onAbrirPolitica: () => _abrirDocumento(
            'Política de Privacidade',
            kPoliticaPrivacidade,
          ),
          onAbrirTermos: () => _abrirDocumento('Termos de Uso', kTermosDeUso),
        ),
        const SizedBox(height: 12),
        BotaoPrimario(
          texto: 'Concordar e continuar',
          carregando: _processando,
          onPressed: (_aceito && !_processando) ? _confirmar : null,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _processando ? null : widget.onRecusar,
          style: TextButton.styleFrom(
            foregroundColor: BrandColors.textOnLight,
            minimumSize: const Size(48, 48),
            textStyle: BrandFonts.label.copyWith(fontSize: 15),
          ),
          child: const Text('Não concordo / sair'),
        ),
      ],
    );
  }
}

class _Explicacao extends StatelessWidget {
  const _Explicacao();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Circulo(
          icone: AppIcons.safeShield,
          lado: 48,
          tamanhoIcone: 24,
        ),
        const SizedBox(height: 20),
        Text(
          'Privacidade e Termos',
          style: BrandFonts.heading.copyWith(color: BrandColors.textOnLight),
        ),
        const SizedBox(height: 8),
        Text(
          'Antes de continuar, precisamos do seu consentimento sobre como os '
          'seus dados são tratados no EcoJP.',
          style: BrandFonts.body.copyWith(
            fontSize: 16,
            color: BrandColors.textOnLightMuted,
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < _topicos.length; i++)
          _ItemLinhaDoTempo(
            topico: _topicos[i],
            ultimo: i == _topicos.length - 1,
          ),
      ],
    );
  }
}

/// Um item da linha do tempo: ícone num círculo, linha ligando ao próximo e
/// o texto ao lado.
class _ItemLinhaDoTempo extends StatelessWidget {
  const _ItemLinhaDoTempo({required this.topico, required this.ultimo});

  final _Topico topico;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight só aqui (4 itens estáticos): a linha vertical acompanha
    // a altura do texto, que muda com a largura e o tamanho da fonte.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              _Circulo(icone: topico.icone, lado: 32, tamanhoIcone: 16),
              if (!ultimo)
                const Expanded(
                  child: VerticalDivider(
                    width: 2,
                    thickness: 2,
                    color: BrandColors.neutralSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: ultimo ? 0 : 20),
              child: Text(
                topico.texto,
                style: BrandFonts.body.copyWith(
                  fontSize: 15,
                  color: BrandColors.textOnLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({
    required this.icone,
    required this.lado,
    required this.tamanhoIcone,
  });

  final String icone;
  final double lado;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: BrandColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: IconeSvg(
        icone,
        cor: BrandColors.primary,
        tamanho: tamanhoIcone,
      ),
    );
  }
}
