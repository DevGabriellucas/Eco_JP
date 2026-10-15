import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/denuncias/providers/denuncia_providers.dart';
import '../../models/occurrence_types.dart';
import '../../models/ocorrencia_model.dart';
import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/notificacao_service.dart';
import '../../services/usuario_service.dart';
import '../../utils/cloudinary_image.dart';
import '../../utils/imagem_cacheada.dart';
import '../../utils/reacao_ocorrencia.dart';
import '../../theme/app_theme.dart';
import '../../widgets/occurrence_card.dart';
import '../detalhe_ocorrencia_page.dart';

class PerfilPublicoPage extends ConsumerWidget {
  final String userId;
  final String fallbackName;
  final String? fallbackPhotoUrl;

  const PerfilPublicoPage({
    super.key,
    required this.userId,
    required this.fallbackName,
    this.fallbackPhotoUrl,
  });

  static final _usuarioService = UsuarioService();
  static final _authService = AuthService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocorrenciaRepository = ref.watch(ocorrenciaRepositoryProvider);
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.surface,
      appBar: AppBar(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: CustomPaint(
          painter: _PublicProfileContourPainter(
            color: pal.border.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.75,
            ),
          ),
        ),
        title: const Text(
          'Perfil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Compartilhar perfil',
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: 'Confira o perfil de $fallbackName no EcoJP.',
                subject: 'Perfil no EcoJP',
              ),
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<UsuarioModel?>(
        stream: _usuarioService.observarPerfil(userId),
        builder: (context, perfilSnap) {
          final perfil = perfilSnap.data ??
              UsuarioModel(
                uid: userId,
                nome: fallbackName,
                fotoUrl: fallbackPhotoUrl,
              );

          return StreamBuilder<List<OcorrenciaModel>>(
            stream: ocorrenciaRepository.listarPorUsuario(userId),
            builder: (context, ocorrenciasSnap) {
              final ocorrencias = (ocorrenciasSnap.data ?? const [])
                  .where((o) => !o.anonima)
                  .toList()
                ..sort((a, b) {
                  final da = a.dataCriacao;
                  final db = b.dataCriacao;
                  if (da == null && db == null) return 0;
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return db.compareTo(da);
                });

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    color: pal.surface,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PublicProfileContourPainter(
                              color: pal.border.withValues(
                                alpha: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.3
                                    : 0.75,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: Column(
                            children: [
                              _ProfileHeader(perfil: perfil),
                              const SizedBox(height: 16),
                              _SocialBar(
                                usuarioService: _usuarioService,
                                currentUid: _authService.currentUser?.uid,
                                profileUid: userId,
                                publicCount: ocorrencias.length,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ImpactoCard(ocorrencias: ocorrencias),
                        const SizedBox(height: 16),
                        _ContribuicaoCard(ocorrencias: ocorrencias),
                        const SizedBox(height: 16),
                        Text(
                          'Denúncias públicas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: pal.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (ocorrencias.isEmpty)
                          const _EmptyPublicPosts()
                        else
                          for (final ocorrencia in ocorrencias)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PublicOccurrenceTile(
                                occurrence: ocorrencia,
                                nomeAutor: perfil.nome.trim().isNotEmpty
                                    ? perfil.nome
                                    : fallbackName,
                                fotoAutor: perfil.fotoUrl ?? fallbackPhotoUrl,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetalheOcorrenciaPage(
                                      occurrence: ocorrencia,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UsuarioModel perfil;

  const _ProfileHeader({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = perfil.fotoUrl != null && perfil.fotoUrl!.isNotEmpty;
    final pal = context.pal;
    return Row(
      children: [
        CircleAvatar(
          radius: 29,
          backgroundColor: pal.primary.withValues(alpha: 0.14),
          backgroundImage: hasPhoto
              ? imagemCacheada(cloudinaryAvatar(perfil.fotoUrl!, radius: 29))
              : null,
          child: hasPhoto
              ? null
              : Text(
                  perfil.iniciais,
                  style: TextStyle(
                    color: pal.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                perfil.nome.trim().isEmpty ? 'Usuário' : perfil.nome.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: pal.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: pal.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      perfil.bairro.trim().isEmpty
                          ? 'João Pessoa'
                          : '${perfil.bairro.trim()}, João Pessoa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pal.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialBar extends StatefulWidget {
  final UsuarioService usuarioService;
  final String? currentUid;
  final String profileUid;
  final int publicCount;

  const _SocialBar({
    required this.usuarioService,
    required this.currentUid,
    required this.profileUid,
    required this.publicCount,
  });

  @override
  State<_SocialBar> createState() => _SocialBarState();
}

class _SocialBarState extends State<_SocialBar> {
  bool _saving = false;

  bool get _isOwnProfile => widget.currentUid == widget.profileUid;

  Future<void> _toggleFollow(bool seguindo) async {
    final uid = widget.currentUid;
    if (uid == null || _saving || _isOwnProfile) return;
    setState(() => _saving = true);
    try {
      await widget.usuarioService.definirSeguindo(
        uid: uid,
        alvoUid: widget.profileUid,
        seguir: !seguindo,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: widget.usuarioService.contarSeguidores(widget.profileUid),
      initialData: 0,
      builder: (context, seguidoresSnap) {
        return StreamBuilder<int>(
          stream: widget.usuarioService.contarSeguindo(widget.profileUid),
          initialData: 0,
          builder: (context, seguindoSnap) {
            Widget metricas({required bool seguir}) => Row(
                  children: [
                    Expanded(
                      child: _SocialCount(
                        label: 'Denúncias',
                        value: widget.publicCount,
                      ),
                    ),
                    Expanded(
                      child: _SocialCount(
                        label: 'Seguidores',
                        value: seguidoresSnap.data ?? 0,
                      ),
                    ),
                    Expanded(
                      child: _SocialCount(
                        label: 'Seguindo',
                        value: seguindoSnap.data ?? 0,
                      ),
                    ),
                    if (seguir) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        height: 40,
                        child: StreamBuilder<bool>(
                          stream: widget.usuarioService.observarSeguindo(
                            widget.currentUid!,
                            widget.profileUid,
                          ),
                          initialData: false,
                          builder: (context, seguindoUsuarioSnap) {
                            final seguindo = seguindoUsuarioSnap.data == true;
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            return ElevatedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _toggleFollow(seguindo),
                              icon: Icon(
                                seguindo ? Icons.check : Icons.add,
                                size: 17,
                              ),
                              label: Text(seguindo ? 'Seguindo' : 'Seguir'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: seguindo
                                    ? context.pal.surfaceAlt
                                    : context.pal.primary,
                                foregroundColor: seguindo
                                    ? context.pal.ink
                                    : isDark
                                        ? context.pal.background
                                        : Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );

            return metricas(
              seguir: !_isOwnProfile && widget.currentUid != null,
            );
          },
        );
      },
    );
  }
}

class _SocialCount extends StatelessWidget {
  final String label;
  final int value;

  const _SocialCount({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: pal.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: pal.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ImpactoCard extends StatelessWidget {
  final List<OcorrenciaModel> ocorrencias;

  const _ImpactoCard({required this.ocorrencias});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final resolvidas = ocorrencias
        .where(
            (o) => o.verificada && o.statusOficial == StatusOficial.resolvida)
        .length;
    final verificadas = ocorrencias.where((o) => o.verificada).length;
    final taxa = ocorrencias.isEmpty
        ? 0
        : (resolvidas * 100 / ocorrencias.length).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Impacto & Contribuição',
            style: TextStyle(
              color: pal.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _ImpactBox(
                      value: ocorrencias.length, label: 'Denúncias')),
              const SizedBox(width: 8),
              Expanded(
                child: _ImpactBox(
                  value: verificadas,
                  label: 'Verificadas',
                  showDot: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ImpactBox(
                  value: resolvidas,
                  label: 'Resolvidas',
                  showDot: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ImpactBox(value: '$taxa%', label: 'Taxa de Resolução'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactBox extends StatelessWidget {
  const _ImpactBox({
    required this.value,
    required this.label,
    this.showDot = false,
  });

  final Object value;
  final String label;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: pal.background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: pal.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (showDot) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: pal.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pal.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicOccurrenceTile extends ConsumerStatefulWidget {
  final OcorrenciaModel occurrence;
  final String nomeAutor;
  final String? fotoAutor;
  final VoidCallback onTap;

  const _PublicOccurrenceTile({
    required this.occurrence,
    required this.nomeAutor,
    required this.fotoAutor,
    required this.onTap,
  });

  @override
  ConsumerState<_PublicOccurrenceTile> createState() =>
      _PublicOccurrenceTileState();
}

class _PublicOccurrenceTileState extends ConsumerState<_PublicOccurrenceTile> {
  final _authService = AuthService();
  final _notificacaoService = NotificacaoService();

  Future<void> _reagir({required bool like}) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para reagir à denúncia.')),
      );
      return;
    }
    await reagirOcorrencia(
      context: context,
      ocorrencia: widget.occurrence,
      uid: uid,
      isLike: like,
      ocorrenciaRepository: ref.read(ocorrenciaRepositoryProvider),
      notificacaoService: _notificacaoService,
      onMudou: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OccurrenceCard(
      occurrence: widget.occurrence,
      nomeAutor: widget.nomeAutor,
      fotoAutor: widget.fotoAutor,
      onLike: () => _reagir(like: true),
      onDislike: () => _reagir(like: false),
      onComment: widget.onTap,
      onOpen: widget.onTap,
    );
  }
}

class _EmptyPublicPosts extends StatelessWidget {
  const _EmptyPublicPosts();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: Text(
        'Nenhuma denúncia pública neste perfil.',
        textAlign: TextAlign.center,
        style: TextStyle(color: pal.muted, fontSize: 13),
      ),
    );
  }
}

/// Distribuição das denúncias públicas por categoria.
class _ContribuicaoCard extends StatelessWidget {
  final List<OcorrenciaModel> ocorrencias;

  const _ContribuicaoCard({required this.ocorrencias});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final porCategoria = <OccurrenceType, int>{};
    for (final o in ocorrencias) {
      final tipo = OccurrenceTypeParser.fromString(o.tipoLixo);
      porCategoria[tipo] = (porCategoria[tipo] ?? 0) + 1;
    }
    final categorias = porCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maiorValor = categorias.isEmpty ? 0 : categorias.first.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final corBarraSecundaria =
        isDark ? const Color(0xFF77B9CC) : const Color(0xFF287D96);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Denúncias por tipo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (categorias.isEmpty)
            Text(
              'Ainda não há denúncias para categorizar.',
              style: TextStyle(fontSize: 12, color: pal.muted),
            )
          else
            for (var i = 0; i < categorias.length; i++) ...[
              _CategoriaBar(
                tipo: categorias[i].key,
                valor: categorias[i].value,
                maiorValor: maiorValor,
                cor: i == 0 ? pal.primary : corBarraSecundaria,
              ),
              if (i != categorias.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// Barra horizontal e contagem para cada categoria registrada.
class _CategoriaBar extends StatelessWidget {
  const _CategoriaBar({
    required this.tipo,
    required this.valor,
    required this.maiorValor,
    required this.cor,
  });

  final OccurrenceType tipo;
  final int valor;
  final int maiorValor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Icon(tipo.icon, size: 14, color: pal.muted),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 98,
          child: Text(
            tipo.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: pal.ink),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: maiorValor == 0 ? 0 : valor / maiorValor,
              backgroundColor: pal.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(cor),
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$valor',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10, color: pal.muted),
          ),
        ),
      ],
    );
  }
}

class _PublicProfileContourPainter extends CustomPainter {
  const _PublicProfileContourPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < 8; i++) {
      final y = -42.0 + i * 22;
      final path = Path()
        ..moveTo(-20, y)
        ..cubicTo(size.width * 0.16, y + 54, size.width * 0.27, y - 38,
            size.width * 0.48, y + 1)
        ..cubicTo(size.width * 0.69, y + 50, size.width * 0.81, y - 50,
            size.width + 20, y + 7);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PublicProfileContourPainter oldDelegate) =>
      oldDelegate.color != color;
}
