import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_icons.dart';
import '../../theme/brand_fonts.dart';
import '../../theme/marca_cores.dart';
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
  /// Devolve `false` quando o aceite ficou na fila offline (sem internet):
  /// a tela avisa que ele será enviado quando a conexão voltar.
  final Future<bool> Function() onAceitar;

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
  bool _saindo = false;

  /// Um toque só: antes um segundo toque chamava o logout de novo.
  Future<void> _recusar() async {
    setState(() => _saindo = true);
    try {
      await widget.onRecusar();
    } finally {
      if (mounted) setState(() => _saindo = false);
    }
  }

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
    // Pego antes do await: a tela sai logo depois do aceite, e o messenger do
    // app (que sobrevive à troca de tela) mostra o aviso na tela seguinte.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final confirmado = await widget.onAceitar();
      if (!confirmado) {
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'Sem conexão: seu aceite será registrado quando a internet '
              'voltar.',
            ),
          ),
        );
      }
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
        systemNavigationBarColor: context.marca.fundo,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2.0,
        child: Scaffold(
          backgroundColor: context.marca.fundo,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final margem = margemResponsiva(
                  c.maxWidth,
                  margemMinima: MedidasMarca.margemLateral,
                  larguraMaxima: MedidasMarca.larguraMaxConteudo,
                );
                final explicacao = Padding(
                  padding: EdgeInsets.fromLTRB(margem, 24, margem, 16),
                  child: const _Explicacao(),
                );
                final divisoria = Divider(
                  height: 1,
                  thickness: 1,
                  color: context.marca.borda,
                );
                final acoes = Padding(
                  padding: EdgeInsets.fromLTRB(margem, 12, margem, 8),
                  child: _acoes(),
                );

                // Tela baixa (paisagem, fonte grande): a área de aceite fixa
                // não caberia (estourava em 640x320 com fonte 2x), então a
                // página inteira rola.
                if (c.maxHeight < 560) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [explicacao, divisoria, acoes],
                    ),
                  );
                }
                // Normal: a explicação rola; aceite e botões ficam fixos.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: SingleChildScrollView(child: explicacao)),
                    divisoria,
                    acoes,
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
          onPressed: (_processando || _saindo) ? null : _recusar,
          style: TextButton.styleFrom(
            foregroundColor: context.marca.texto,
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
          style: BrandFonts.heading.copyWith(color: context.marca.texto),
        ),
        const SizedBox(height: 8),
        Text(
          'Antes de continuar, precisamos do seu consentimento sobre como os '
          'seus dados são tratados no EcoJP.',
          style: BrandFonts.body.copyWith(
            fontSize: 16,
            color: context.marca.textoApoio,
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
                Expanded(
                  child: VerticalDivider(
                    width: 2,
                    thickness: 2,
                    color: context.marca.borda,
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
                  color: context.marca.texto,
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
      decoration: BoxDecoration(
        color: context.marca.superficie,
        shape: BoxShape.circle,
      ),
      child: IconeSvg(
        icone,
        cor: context.marca.destaque,
        tamanho: tamanhoIcone,
      ),
    );
  }
}
