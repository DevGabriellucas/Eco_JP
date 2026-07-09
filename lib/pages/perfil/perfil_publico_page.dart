import 'package:flutter/material.dart';

import '../../models/occurrence_types.dart';
import '../../models/ocorrencia_model.dart';
import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/ocorrencia_service.dart';
import '../../services/usuario_service.dart';
import '../detalhe_ocorrencia_page.dart';

class PerfilPublicoPage extends StatelessWidget {
  final String userId;
  final String fallbackName;
  final String? fallbackPhotoUrl;

  PerfilPublicoPage({
    super.key,
    required this.userId,
    required this.fallbackName,
    this.fallbackPhotoUrl,
  });

  final UsuarioService _usuarioService = UsuarioService();
  final OcorrenciaService _ocorrenciaService = OcorrenciaService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Perfil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: StreamBuilder<UsuarioModel?>(
        stream: _usuarioService.observarPerfil(userId),
        builder: (context, perfilSnap) {
          final perfil =
              perfilSnap.data ??
              UsuarioModel(
                uid: userId,
                nome: fallbackName,
                fotoUrl: fallbackPhotoUrl,
              );

          return StreamBuilder<List<OcorrenciaModel>>(
            stream: _ocorrenciaService.listarPorUsuario(userId),
            builder: (context, ocorrenciasSnap) {
              final ocorrencias =
                  (ocorrenciasSnap.data ?? const [])
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _ProfileHeader(perfil: perfil),
                  const SizedBox(height: 16),
                  _SocialBar(
                    usuarioService: _usuarioService,
                    currentUid: _authService.currentUser?.uid,
                    profileUid: userId,
                  ),
                  const SizedBox(height: 16),
                  _StatsRow(ocorrencias: ocorrencias),
                  const SizedBox(height: 22),
                  const Text(
                    'Denúncias públicas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ocorrencias.isEmpty)
                    const _EmptyPublicPosts()
                  else
                    for (final ocorrencia in ocorrencias)
                      _PublicOccurrenceTile(
                        occurrence: ocorrencia,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetalheOcorrenciaPage(occurrence: ocorrencia),
                          ),
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
    return Column(
      children: [
        CircleAvatar(
          radius: 46,
          backgroundColor: const Color(0xFFE8F5E9),
          backgroundImage: hasPhoto ? NetworkImage(perfil.fotoUrl!) : null,
          child: hasPhoto
              ? null
              : Text(
                  perfil.iniciais,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          perfil.nome.trim().isEmpty ? 'Usuário' : perfil.nome.trim(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (perfil.bairro.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 4),
              Text(
                perfil.bairro.trim(),
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        if (perfil.bio.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            perfil.bio.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _SocialBar extends StatefulWidget {
  final UsuarioService usuarioService;
  final String? currentUid;
  final String profileUid;

  const _SocialBar({
    required this.usuarioService,
    required this.currentUid,
    required this.profileUid,
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
            final stats = Row(
              children: [
                Expanded(
                  child: _SocialCount(
                    label: 'Seguidores',
                    value: seguidoresSnap.data ?? 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SocialCount(
                    label: 'Seguindo',
                    value: seguindoSnap.data ?? 0,
                  ),
                ),
              ],
            );

            if (_isOwnProfile || widget.currentUid == null) return stats;

            return Column(
              children: [
                stats,
                const SizedBox(height: 12),
                StreamBuilder<bool>(
                  stream: widget.usuarioService.observarSeguindo(
                    widget.currentUid!,
                    widget.profileUid,
                  ),
                  initialData: false,
                  builder: (context, seguindoUsuarioSnap) {
                    final seguindo = seguindoUsuarioSnap.data == true;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _toggleFollow(seguindo),
                        icon: Icon(
                          seguindo
                              ? Icons.person_remove_outlined
                              : Icons.person_add_alt_1_outlined,
                          size: 18,
                        ),
                        label: Text(seguindo ? 'Seguindo' : 'Seguir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: seguindo
                              ? const Color(0xFFF3F4F6)
                              : const Color(0xFF16A34A),
                          foregroundColor: seguindo
                              ? const Color(0xFF111827)
                              : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<OcorrenciaModel> ocorrencias;

  const _StatsRow({required this.ocorrencias});

  @override
  Widget build(BuildContext context) {
    final resolvidas = ocorrencias
        .where((o) => o.verificada && o.statusOficial == 'resolvida')
        .length;
    final verificadas = ocorrencias.where((o) => o.verificada).length;

    return Row(
      children: [
        Expanded(
          child: _StatBox(label: 'Denúncias', value: ocorrencias.length),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(label: 'Verificadas', value: verificadas),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(label: 'Resolvidas', value: resolvidas),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicOccurrenceTile extends StatelessWidget {
  final OcorrenciaModel occurrence;
  final VoidCallback onTap;

  const _PublicOccurrenceTile({required this.occurrence, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = OccurrenceTypeParser.fromString(occurrence.tipoLixo);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                _Thumb(occurrence: occurrence, type: type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        occurrence.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        occurrence.localizacao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(type.icon, size: 13, color: type.color),
                          const SizedBox(width: 4),
                          Text(
                            type.label,
                            style: TextStyle(
                              color: type.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final OcorrenciaModel occurrence;
  final OccurrenceType type;

  const _Thumb({required this.occurrence, required this.type});

  @override
  Widget build(BuildContext context) {
    final url = occurrence.imagensUrls.isNotEmpty
        ? occurrence.imagensUrls.first
        : occurrence.imagemUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 58,
      height: 58,
      color: type.color.withValues(alpha: 0.12),
      child: Icon(type.icon, color: type.color, size: 24),
    );
  }
}

class _EmptyPublicPosts extends StatelessWidget {
  const _EmptyPublicPosts();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Text(
        'Nenhuma denúncia pública neste perfil.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
      ),
    );
  }
}
