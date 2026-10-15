import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/notificacao_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';
import '../theme/brand_fonts.dart';
import '../utils/tempo_relativo.dart';
import 'detalhe_ocorrencia_page.dart';
import '../theme/app_theme.dart';

class NotificacoesPage extends ConsumerStatefulWidget {
  const NotificacoesPage({super.key});

  @override
  ConsumerState<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends ConsumerState<NotificacoesPage> {
  final _authService = AuthService();
  final _service = NotificacaoService();
  bool _abrindo = false;

  late final String? _uid = _authService.currentUser?.uid;
  // Criada uma vez (uma stream nova a cada build reabria o listener).
  late final Stream<List<NotificacaoModel>>? _notificacoes = switch (_uid) {
    final uid? => _service.listar(uid),
    null => null,
  };

  @override
  void dispose() {
    // Marca como lidas ao SAIR da tela. Marcando na abertura, o destaque de
    // "não lida" sumia em um segundo, antes de a pessoa ver o que era novo.
    final uid = _uid;
    if (uid != null) _service.marcarTodasComoLidas(uid);
    super.dispose();
  }

  // Busca a denúncia da notificação e abre a tela de detalhes.
  // Para notificações de conquista, só marca como lida (sem navegar).
  Future<void> _abrirDenuncia(NotificacaoModel n) async {
    if (n.tipo == 'conquista') return; // Conquistas não navegam

    if (_abrindo) return;
    setState(() => _abrindo = true);
    try {
      // null também quando a denúncia foi ocultada pela moderação.
      final ocorrencia = await ref
          .read(ocorrenciaRepositoryProvider)
          .buscarPorId(n.ocorrenciaId);
      if (!mounted) return;
      if (ocorrencia == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Essa denúncia não está mais disponível.'),
          ),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalheOcorrenciaPage(occurrence: ocorrencia),
        ),
      );
    } catch (_) {
      // Sem rede, a busca lançava sem tratamento (crash "fatal").
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Não foi possível abrir a denúncia. Verifique a conexão.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _abrindo = false);
    }
  }

  // Agrupa as notificações em seções por data, preservando a ordem (mais
  // recentes primeiro) com que chegam do serviço.
  List<Object> _comCabecalhos(List<NotificacaoModel> notificacoes) {
    final itens = <Object>[];
    String? grupoAtual;
    for (final n in notificacoes) {
      final grupo =
          grupoPorData(n.dataCriacao) == 'Hoje' ? 'Hoje' : 'Anteriores';
      if (grupo != grupoAtual) {
        grupoAtual = grupo;
        itens.add(grupo); // cabeçalho (String)
      }
      itens.add(n); // item (NotificacaoModel)
    }
    return itens;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final pal = context.pal;

    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notificações',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: pal.ink,
          ),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Faça login para ver suas notificações.'))
          : StreamBuilder<List<NotificacaoModel>>(
              stream: _notificacoes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notificacoes = snapshot.data ?? [];
                if (notificacoes.isEmpty) {
                  return const _Vazio();
                }
                final itens = _comCabecalhos(notificacoes);
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: itens.length,
                  itemBuilder: (_, i) {
                    final item = itens[i];
                    if (item is String) {
                      return _CabecalhoGrupo(titulo: item);
                    }
                    return _NotificacaoTile(
                      item as NotificacaoModel,
                      onTap: () => _abrirDenuncia(item),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _CabecalhoGrupo extends StatelessWidget {
  final String titulo;
  const _CabecalhoGrupo({required this.titulo});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.background,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        titulo.toUpperCase(),
        style: BrandFonts.caption.copyWith(
          color: pal.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Ícone, cor e frase de cada tipo de notificação — comentário/curtida (ação
// de outro usuário), status_* (avanço do ciclo oficial) e conquista.
({IconData icone, Color cor, String frase}) _infoNotificacao(String tipo) {
  switch (tipo) {
    case 'comentario':
      return (
        icone: Icons.chat_bubble,
        cor: const Color(0xFF3B82F6),
        frase: 'comentou na sua denúncia',
      );
    case 'curtida':
      return (
        icone: Icons.favorite,
        cor: const Color(0xFF4CAF50),
        frase: 'curtiu a sua denúncia',
      );
    case 'conquista':
      return (
        icone: Icons.star_rounded,
        cor: const Color(0xFFFFD700),
        frase: 'nova conquista desbloqueada',
      );
    case 'status_em_analise':
      return (
        icone: Icons.search,
        cor: AppColors.warning,
        frase: 'está analisando sua denúncia',
      );
    case 'status_confirmada':
      return (
        icone: Icons.verified,
        cor: AppColors.success,
        frase: 'confirmou sua denúncia',
      );
    case 'status_nao_confirmada':
      return (
        icone: Icons.cancel,
        cor: AppColors.danger,
        frase: 'não confirmou sua denúncia',
      );
    case 'status_encaminhada':
      return (
        icone: Icons.send,
        cor: const Color(0xFF3B82F6),
        frase: 'encaminhou sua denúncia ao órgão responsável',
      );
    case 'status_resolvida':
      return (
        icone: Icons.check_circle,
        cor: AppColors.success,
        frase: 'marcou sua denúncia como resolvida',
      );
    default:
      return (
        icone: Icons.notifications,
        cor: AppColors.muted,
        frase: 'interagiu com sua denúncia',
      );
  }
}

class _NotificacaoTile extends StatelessWidget {
  final NotificacaoModel n;
  final VoidCallback onTap;
  const _NotificacaoTile(this.n, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = _infoNotificacao(n.tipo);
    final conquista = n.tipo == 'conquista';
    final corAcao = switch (n.tipo) {
      'comentario' => const Color(0xFF2F8DA6),
      'curtida' => const Color(0xFFD45E5E),
      _ => info.cor,
    };
    final tituloConquista = n.conquistaTitulo ?? 'Conquista desbloqueada';
    final descricaoConquista = _descricaoConquista(tituloConquista);
    final fundo = n.lida
        ? pal.background
        : pal.primary.withValues(alpha: isDark ? 0.08 : 0.09);

    return Container(
      color: fundo,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 11, 16, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarNotificacao(
                conquista: conquista,
                nome: n.deUsuarioNome,
                iconeAcao: info.icone,
                corAcao: corAcao,
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (conquista)
                      Text.rich(
                        TextSpan(
                          style: TextStyle(color: pal.ink, fontSize: 14),
                          children: [
                            const TextSpan(
                              text: 'Conquista desbloqueada: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: tituloConquista,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          style: TextStyle(color: pal.ink, fontSize: 14),
                          children: [
                            TextSpan(
                              text: n.deUsuarioNome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: ' ${info.frase}'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      conquista ? descricaoConquista : n.ocorrenciaTitulo,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: pal.muted,
                      ),
                    ),
                    if (n.dataCriacao != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        tempoRelativo(n.dataCriacao),
                        style: BrandFonts.caption.copyWith(
                          fontSize: 10,
                          color: pal.muted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!n.lida) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: pal.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarNotificacao extends StatelessWidget {
  const _AvatarNotificacao({
    required this.conquista,
    required this.nome,
    required this.iconeAcao,
    required this.corAcao,
    required this.isDark,
  });

  final bool conquista;
  final String nome;
  final IconData iconeAcao;
  final Color corAcao;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    if (conquista) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: pal.primary,
        child: Icon(
          Icons.shield_outlined,
          size: 21,
          color: isDark ? pal.background : Colors.white,
        ),
      );
    }

    final iniciais = _iniciais(nome);
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isDark
                ? pal.primary.withValues(alpha: 0.13)
                : const Color(0xFFDDF4EA),
            child: Text(
              iniciais,
              style: TextStyle(
                color: isDark ? pal.primary : const Color(0xFF08785B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: corAcao,
                shape: BoxShape.circle,
                border: Border.all(color: pal.background, width: 1.5),
              ),
              child: Icon(
                iconeAcao,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _iniciais(String nome) {
  final palavras = nome.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  if (palavras.isEmpty) return '??';
  final lista = palavras.toList();
  final primeiro = lista.first;
  if (primeiro == primeiro.toUpperCase() && primeiro.length > 1) {
    return primeiro.substring(0, 2);
  }
  return lista.length == 1
      ? primeiro.substring(0, 1).toUpperCase()
      : '${primeiro[0]}${lista.last[0]}'.toUpperCase();
}

String _descricaoConquista(String titulo) {
  return switch (titulo) {
    'Voz da comunidade' => '50 curtidas recebidas',
    'Primeira voz' => 'Primeira denúncia registrada',
    'Guardião ativo' => '5 denúncias registradas',
    'Vigilante' => '25 denúncias registradas',
    'Impacto real' => 'Denúncia resolvida pela autoridade',
    'Transformador' => '5 denúncias resolvidas',
    'Verificador' => 'Verificação de denúncias da comunidade',
    _ => '',
  };
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(220, 132),
                        painter: _NotificacaoContourPainter(
                          color: pal.border.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                    ? 0.55
                                    : 0.9,
                          ),
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: pal.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: pal.border),
                        ),
                        child: Icon(
                          Icons.notifications_none,
                          size: 25,
                          color: pal.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Você ainda não tem notificações',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: pal.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Avisaremos quando alguém interagir\ncom as suas denúncias.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: pal.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificacaoContourPainter extends CustomPainter {
  const _NotificacaoContourPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < 7; i++) {
      final offset = i * 11.0;
      final path = Path()
        ..moveTo(-8, 24 + offset)
        ..cubicTo(34, 8 + offset, 26, 62 + offset, 67, 45 + offset)
        ..cubicTo(107, 27 + offset, 127, 21 + offset, 139, 0 + offset)
        ..cubicTo(159, 22 + offset, 138, 71 + offset, 179, 71 + offset)
        ..cubicTo(198, 71 + offset, 202, 56 + offset, 228, 68 + offset);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NotificacaoContourPainter oldDelegate) =>
      oldDelegate.color != color;
}
