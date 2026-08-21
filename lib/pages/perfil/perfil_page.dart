import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/ocorrencia_repository.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/denuncias/providers/denuncia_providers.dart';
import '../../models/ocorrencia_model.dart';
import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../utils/cloudinary_image.dart';
import '../../utils/imagem_cacheada.dart';
import '../../utils/conquistas.dart';
import '../../services/usuario_service.dart';
import '../detalhe_ocorrencia_page.dart';
import 'configuracoes_conta_page.dart';
import '../../models/occurrence_types.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ocorrencia_actions.dart';
import 'editar_perfil_page.dart';

class _Cores {
  // Cinza do avatar (fundo do fallback) e laranja de destaque — iguais nos
  // dois temas. Os neutros (fundo/cartão/texto/borda) vêm de `context.pal`.
  static const avatarBg = Color(0xFF9E9E9E);
  static const laranja = Color(0xFFFF8A1F);
}

class PerfilPage extends ConsumerStatefulWidget {
  const PerfilPage({super.key});

  @override
  ConsumerState<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends ConsumerState<PerfilPage> {
  final _authService = AuthService();
  final _usuarioService = UsuarioService();

  OcorrenciaRepository get _ocorrenciaRepository =>
      ref.read(ocorrenciaRepositoryProvider);

  int _aba = 0; // 0 = Resumo, 1 = Minhas denúncias, 2 = Salvos

  static const _meses = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  String _membroDesde() {
    final criacao = _authService.currentUser?.metadata.creationTime;
    if (criacao == null) return '-';
    return '${_meses[criacao.month - 1]}/${criacao.year}';
  }

  void _abrirEdicao(UsuarioModel perfil) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditarPerfilPage(perfilAtual: perfil)),
    );
  }

  // Pull-to-refresh: os dados vêm de streams (atualizam sozinhos), então só
  // reconstruímos a tela e damos um pequeno tempo para o gesto completar.
  Future<void> _recarregar() async {
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final uid = _authService.currentUser?.uid;
    // Órgão não usa as seções de cidadão (impacto, conquistas, minhas
    // denúncias, salvos) — são recursos de gamificação/participação do cidadão.
    final isAutoridade = ref.watch(isAutoridadeProvider).value == true;
    final emailFallback =
        _authService.currentUser?.email?.split('@').first ?? 'Usuário';

    if (uid == null) {
      return Scaffold(
        backgroundColor: pal.surface,
        body: const Center(child: Text('Faça login para ver seu perfil.')),
      );
    }

    return Scaffold(
      backgroundColor: pal.surface,
      appBar: AppBar(
        backgroundColor: pal.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Text(
              'EcoJP',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: pal.ink,
              ),
            ),
            const SizedBox(width: 12),
            Text('Meu Perfil', style: TextStyle(fontSize: 15, color: pal.hint)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: pal.ink),
            tooltip: 'Conta e privacidade',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConfiguracoesContaPage()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: pal.border),
        ),
      ),
      body: StreamBuilder<UsuarioModel?>(
        stream: _usuarioService.observarPerfil(uid),
        builder: (context, perfilSnap) {
          final perfil =
              perfilSnap.data ?? UsuarioModel(uid: uid, nome: emailFallback);

          return StreamBuilder<List<OcorrenciaModel>>(
            stream: _ocorrenciaRepository.listarMinhasDenuncias(uid),
            builder: (context, ocSnap) {
              final ocorrencias = ocSnap.data ?? [];
              final stats = _calcularStats(ocorrencias);

              return RefreshIndicator(
                onRefresh: _recarregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    _cardPerfil(perfil),
                    // Seções de cidadão: só para contas comuns. O órgão vê
                    // apenas o cartão de perfil (dados da conta) — sem
                    // gamificação nem abas de participação.
                    if (!isAutoridade) ...[
                      const SizedBox(height: 24),
                      _abas(),
                      const SizedBox(height: 16),
                      if (_aba == 0) ...[
                        ..._secaoEstatisticas(stats),
                      ] else if (_aba == 1)
                        ..._secaoMinhasDenuncias(ocorrencias)
                      else
                        _secaoSalvos(uid),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _cardPerfil(UsuarioModel perfil) {
    final pal = context.pal;
    final incompleto =
        perfil.bairro.trim().isEmpty && perfil.bio.trim().isEmpty;
    final isAutoridade = ref.watch(isAutoridadeProvider).value == true;
    return Container(
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner em gradiente
              Container(
                height: 76,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.successStrong, AppColors.success],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 54, 20, 20),
                child: Column(
                  children: [
                    Text(
                      perfil.nome.trim().isEmpty ? 'Sem nome' : perfil.nome,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: pal.ink,
                      ),
                    ),
                    if (isAutoridade) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF22C55E,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield,
                              size: 14,
                              color: AppColors.successStrong,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Autoridade',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.successStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Membro desde ${_membroDesde()}',
                      style: TextStyle(fontSize: 13, color: pal.hint),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, size: 15, color: pal.hint),
                        const SizedBox(width: 4),
                        Text(
                          perfil.bairro.trim().isEmpty
                              ? 'Bairro não informado'
                              : perfil.bairro,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: pal.ink,
                          ),
                        ),
                      ],
                    ),
                    if (perfil.bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        perfil.bio,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: pal.hint,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (incompleto) ...[
                      const SizedBox(height: 14),
                      _nudgeCompletar(perfil),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Avatar sobreposto, com anel
          Positioned(
            top: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: pal.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: _avatar(perfil),
              ),
            ),
          ),
          // Botão editar sobre o banner
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: Colors.white,
              ),
              tooltip: 'Editar perfil',
              onPressed: () => _abrirEdicao(perfil),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nudgeCompletar(UsuarioModel perfil) {
    return GestureDetector(
      onTap: () => _abrirEdicao(perfil),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _Cores.laranja.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Cores.laranja.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: _Cores.laranja),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete seu perfil — adicione seu bairro e uma bio.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.pal.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _Cores.laranja),
          ],
        ),
      ),
    );
  }

  Widget _avatar(UsuarioModel perfil) {
    if (perfil.fotoUrl != null && perfil.fotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundColor: _Cores.avatarBg,
        backgroundImage: imagemCacheada(
          cloudinaryAvatar(perfil.fotoUrl!, radius: 42),
        ),
      );
    }
    return CircleAvatar(
      radius: 42,
      backgroundColor: _Cores.avatarBg,
      child: Text(
        perfil.iniciais,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A4A4A),
        ),
      ),
    );
  }

  Widget _cardStat(String label, String valor) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: pal.hint)),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: pal.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardCategoria(String? categoria) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        children: [
          Text(
            'Categoria mais reportada',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              color: _Cores.laranja,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              categoria ?? 'Nenhuma',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Abas (Resumo / Minhas denúncias) ──────────────────────────────────────

  Widget _abas() {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          Expanded(child: _abaBtn('Resumo', 0)),
          Expanded(child: _abaBtn('Minhas denúncias', 1)),
          Expanded(child: _abaBtn('Salvos', 2)),
        ],
      ),
    );
  }

  Widget _abaBtn(String label, int idx) {
    final pal = context.pal;
    final ativo = _aba == idx;
    return GestureDetector(
      onTap: () {
        if (_aba != idx) setState(() => _aba = idx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo ? pal.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ativo ? pal.border : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
            color: ativo ? pal.ink : pal.hint,
          ),
        ),
      ),
    );
  }

  // ── Seção: Estatísticas ───────────────────────────────────────────────────

  // Meu impacto: reconhecimento oficial das denúncias do usuário pela
  // autoridade (mais forte que o status que o próprio cidadão define).
  Widget _cardImpacto(_Stats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.successStrong, AppColors.success],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.volunteer_activism, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Meu impacto',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _impactoItem(
                  '${stats.verificadas}',
                  'Verificadas\npela autoridade',
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _impactoItem(
                  '${stats.resolvidasOficial}',
                  'Resolvidas\noficialmente',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _impactoItem(String valor, String label) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  List<Widget> _secaoEstatisticas(_Stats stats) {
    return [
      _cardImpacto(stats),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(child: _cardStat('Denúncias', '${stats.total}')),
          const SizedBox(width: 14),
          Expanded(child: _cardStat('Curtidas recebidas', '${stats.curtidas}')),
        ],
      ),
      const SizedBox(height: 14),
      _cardCategoria(stats.categoriaTop),
      const SizedBox(height: 14),
      _cardConquistas(stats),
    ];
  }

  // Conquistas (gamificação): badges derivados das estatísticas do usuário.
  // As desbloqueadas aparecem coloridas; as pendentes, esmaecidas com o
  // progresso atual (ex.: "3/5").
  Widget _cardConquistas(_Stats stats) {
    final pal = context.pal;
    final isAutoridade = ref.watch(isAutoridadeProvider).value == true;
    final conquistas = calcularConquistas(
      denuncias: stats.total,
      resolvidas: stats.resolvidasOficial,
      curtidas: stats.curtidas,
      isAutoridade: isAutoridade,
    );
    final desbloqueadas = conquistas.where((c) => c.desbloqueada).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 18, color: pal.ink),
              const SizedBox(width: 8),
              Text(
                'Conquistas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: pal.ink,
                ),
              ),
              const Spacer(),
              Text(
                '$desbloqueadas/${conquistas.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: pal.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in conquistas) _ConquistaBadge(conquista: c),
            ],
          ),
        ],
      ),
    );
  }

  // ── Seção: Minhas denúncias ───────────────────────────────────────────────

  List<Widget> _secaoMinhasDenuncias(List<OcorrenciaModel> ocorrencias) {
    if (ocorrencias.isEmpty) {
      return [_denunciasVazio()];
    }
    final ordenadas = [...ocorrencias]
      ..sort((a, b) {
        final da = a.dataCriacao;
        final db = b.dataCriacao;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da); // mais recentes primeiro
      });
    return [for (final o in ordenadas) _denunciaCard(o)];
  }

  Widget _denunciasVazio() {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: pal.hint),
          const SizedBox(height: 12),
          Text(
            'Você ainda não fez nenhuma denúncia',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: pal.hint),
          ),
        ],
      ),
    );
  }

  Widget _secaoSalvos(String uid) {
    return StreamBuilder<Set<String>>(
      stream: _usuarioService.observarFavoritosIds(uid),
      initialData: const <String>{},
      builder: (context, favSnap) {
        final favoritos = favSnap.data ?? const <String>{};
        if (favoritos.isEmpty) return _salvosVazio();

        return StreamBuilder<List<OcorrenciaModel>>(
          stream: _ocorrenciaRepository.observarPorIds(favoritos),
          builder: (context, ocorrenciasSnap) {
            final salvas =
                (ocorrenciasSnap.data ?? const <OcorrenciaModel>[]).toList()
                  ..sort((a, b) {
                    final da = a.dataCriacao;
                    final db = b.dataCriacao;
                    if (da == null && db == null) return 0;
                    if (da == null) return 1;
                    if (db == null) return -1;
                    return db.compareTo(da);
                  });

            if (salvas.isEmpty) return _salvosVazio();
            return Column(
              children: [
                for (final o in salvas)
                  _denunciaCard(
                    o,
                    gerenciar: false,
                    onRemoverSalvo: () => _removerSalvo(uid, o.id),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _salvosVazio() {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        children: [
          Icon(Icons.bookmark_border, size: 48, color: pal.hint),
          const SizedBox(height: 12),
          Text(
            'Nenhuma denúncia salva ainda',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: pal.hint),
          ),
        ],
      ),
    );
  }

  Future<void> _removerSalvo(String uid, String ocorrenciaId) async {
    try {
      await _usuarioService.removerFavorito(uid, ocorrenciaId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denúncia removida dos salvos.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível remover dos salvos.')),
      );
    }
  }

  Widget _denunciaCard(
    OcorrenciaModel o, {
    bool gerenciar = true,
    VoidCallback? onRemoverSalvo,
  }) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _mostrarDetalhes(o),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pal.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _denunciaThumb(o),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.titulo.trim().isEmpty ? 'Sem título' : o.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: pal.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 13, color: pal.hint),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              o.localizacao.trim().isEmpty
                                  ? 'Sem local'
                                  : o.localizacao,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: pal.hint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statusBadge(o.status),
                          const Spacer(),
                          Text(
                            _formatarData(o.dataCriacao),
                            style: TextStyle(fontSize: 11, color: pal.hint),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (gerenciar || onRemoverSalvo != null)
                        GestureDetector(
                          onTap: gerenciar
                              ? () => showOcorrenciaActions(
                                  context: context,
                                  ocorrencia: o,
                                  service: _ocorrenciaRepository,
                                )
                              : onRemoverSalvo,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: pal.ink.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: pal.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  gerenciar
                                      ? Icons.tune
                                      : Icons.bookmark_remove_outlined,
                                  size: 14,
                                  color: pal.ink,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  gerenciar
                                      ? 'Gerenciar denúncia'
                                      : 'Remover dos salvos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: pal.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _denunciaThumb(OcorrenciaModel o) {
    final url = o.imagemUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: (url != null && url.isNotEmpty)
          ? Builder(
              builder: (context) {
                final dpr = MediaQuery.devicePixelRatioOf(context);
                return Image(
                  image: imagemCacheada(
                    cloudinaryOtimizada(
                      url,
                      larguraLogica: 60,
                      alturaLogica: 60,
                      devicePixelRatio: dpr,
                      crop: 'fill',
                    ),
                    cacheWidth: cacheLarguraPx(60, dpr),
                  ),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto da denúncia: ${o.titulo}',
                  errorBuilder: (context, error, stackTrace) => _thumbPlaceholder(),
                );
              },
            )
          : _thumbPlaceholder(),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: _Cores.avatarBg,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 24,
        color: Colors.white,
      ),
    );
  }

  Widget _statusBadge(String status) {
    final s = OccurrenceStatusParser.fromString(status);
    final cor = s.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '';
    final dia = data.day.toString().padLeft(2, '0');
    return '$dia ${_meses[data.month - 1]} ${data.year}';
  }

  void _mostrarDetalhes(OcorrenciaModel o) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalheOcorrenciaPage(occurrence: o)),
    );
  }

  // ── Estatísticas ──────────────────────────────────────────────────────────

  _Stats _calcularStats(List<OcorrenciaModel> ocorrencias) {
    final base = ocorrencias.length;

    // categoria mais reportada (moda de tipoLixo)
    String? categoriaTop;
    if (ocorrencias.isNotEmpty) {
      final contagem = <String, int>{};
      for (final o in ocorrencias) {
        if (o.tipoLixo.trim().isEmpty) continue;
        contagem[o.tipoLixo] = (contagem[o.tipoLixo] ?? 0) + 1;
      }
      if (contagem.isNotEmpty) {
        categoriaTop = contagem.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }
    }

    // Total de curtidas recebidas somando os likes de todas as denúncias.
    final curtidas = ocorrencias.fold<int>(0, (soma, o) => soma + o.likes);

    // Impacto oficial: verificadas pela autoridade e resolvidas oficialmente.
    final verificadas = ocorrencias.where((o) => o.verificada).length;
    final resolvidasOficial = ocorrencias
        .where((o) => o.verificada && o.statusOficial == StatusOficial.resolvida)
        .length;

    return _Stats(
      total: base,
      curtidas: curtidas,
      categoriaTop: categoriaTop,
      verificadas: verificadas,
      resolvidasOficial: resolvidasOficial,
    );
  }
}

class _Stats {
  final int total;
  final int curtidas;
  final String? categoriaTop;
  final int verificadas;
  final int resolvidasOficial;

  _Stats({
    required this.total,
    required this.curtidas,
    required this.categoriaTop,
    required this.verificadas,
    required this.resolvidasOficial,
  });
}

/// Badge de uma conquista no perfil. Desbloqueada = ícone colorido + título
/// forte; pendente = esmaecida, mostrando o progresso (ex.: "3/5").
class _ConquistaBadge extends StatelessWidget {
  final Conquista conquista;

  const _ConquistaBadge({required this.conquista});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = conquista;
    final ativa = c.desbloqueada;
    final cor = ativa ? c.cor : pal.hint;

    return Tooltip(
      message: '${c.descricao}${ativa ? '' : '  ·  ${c.progresso}/${c.meta}'}',
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: ativa ? c.cor.withValues(alpha: 0.10) : pal.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ativa ? c.cor.withValues(alpha: 0.35) : pal.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(c.icone, size: 26, color: cor),
                if (!ativa)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Icon(Icons.lock, size: 12, color: pal.hint),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              c.titulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: ativa ? pal.ink : pal.muted,
              ),
            ),
            if (!ativa) ...[
              const SizedBox(height: 3),
              Text(
                '${c.progresso}/${c.meta}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: pal.hint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
