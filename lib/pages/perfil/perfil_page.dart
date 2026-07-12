import 'package:flutter/material.dart';

import '../../models/ocorrencia_model.dart';
import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/ocorrencia_service.dart';
import '../../services/role_service.dart';
import '../../services/usuario_service.dart';
import '../detalhe_ocorrencia_page.dart';
import 'configuracoes_conta_page.dart';
import '../../models/occurrence_types.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ocorrencia_actions.dart';
import 'editar_perfil_page.dart';

class _C {
  static const bg = Colors.white;
  static const cardBg = Color(0xFFEDEDED);
  static const cardBorder = Color(0xFFD8D8D8);
  static const avatarBg = Color(0xFF9E9E9E);
  static const text = AppColors.ink;
  static const hint = AppColors.hint;
  static const laranja = Color(0xFFFF8A1F);
}

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _ocorrenciaService = OcorrenciaService();
  final _roleService = RoleService();

  int _aba = 0; // 0 = Resumo, 1 = Minhas denúncias, 2 = Salvos
  bool _isAutoridade = false;

  @override
  void initState() {
    super.initState();
    _checarPapel();
  }

  Future<void> _checarPapel() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final isAut = await _roleService.isAutoridade(uid);
    if (mounted) setState(() => _isAutoridade = isAut);
  }

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
    final uid = _authService.currentUser?.uid;
    final emailFallback =
        _authService.currentUser?.email?.split('@').first ?? 'Usuário';

    if (uid == null) {
      return const Scaffold(
        backgroundColor: _C.bg,
        body: Center(child: Text('Faça login para ver seu perfil.')),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Row(
          children: [
            Text(
              'EcoJP',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
            SizedBox(width: 12),
            Text('Meu Perfil', style: TextStyle(fontSize: 15, color: _C.hint)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _C.text),
            tooltip: 'Conta e privacidade',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConfiguracoesContaPage()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _C.cardBorder),
        ),
      ),
      body: StreamBuilder<UsuarioModel?>(
        stream: _usuarioService.observarPerfil(uid),
        builder: (context, perfilSnap) {
          final perfil =
              perfilSnap.data ?? UsuarioModel(uid: uid, nome: emailFallback);

          return StreamBuilder<List<OcorrenciaModel>>(
            stream: _ocorrenciaService.listarMinhasDenuncias(uid),
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
                    const SizedBox(height: 24),
                    _abas(),
                    const SizedBox(height: 16),
                    // "Sair da conta" aparece só na aba Estatísticas.
                    if (_aba == 0) ...[
                      ..._secaoEstatisticas(stats),
                    ] else if (_aba == 1)
                      ..._secaoMinhasDenuncias(ocorrencias)
                    else
                      _secaoSalvos(uid),
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
    final incompleto =
        perfil.bairro.trim().isEmpty && perfil.bio.trim().isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder),
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
                    colors: [Color(0xFF16A34A), AppColors.success],
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _C.text,
                      ),
                    ),
                    if (_isAutoridade) ...[
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
                              color: Color(0xFF16A34A),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Autoridade',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Membro desde ${_membroDesde()}',
                      style: const TextStyle(fontSize: 13, color: _C.hint),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, size: 15, color: _C.hint),
                        const SizedBox(width: 4),
                        Text(
                          perfil.bairro.trim().isEmpty
                              ? 'Bairro não informado'
                              : perfil.bairro,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _C.text,
                          ),
                        ),
                      ],
                    ),
                    if (perfil.bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        perfil.bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _C.hint,
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
                decoration: const BoxDecoration(
                  color: _C.cardBg,
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
          color: _C.laranja.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.laranja.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: _C.laranja),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Complete seu perfil — adicione seu bairro e uma bio.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _C.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _C.laranja),
          ],
        ),
      ),
    );
  }

  Widget _avatar(UsuarioModel perfil) {
    if (perfil.fotoUrl != null && perfil.fotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundColor: _C.avatarBg,
        backgroundImage: NetworkImage(perfil.fotoUrl!),
      );
    }
    return CircleAvatar(
      radius: 42,
      backgroundColor: _C.avatarBg,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _C.hint)),
          const SizedBox(height: 6),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _C.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardCategoria(String? categoria) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        children: [
          const Text(
            'Categoria mais reportada',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _C.text,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              color: _C.laranja,
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.cardBorder),
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
          color: ativo ? _C.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ativo ? _C.cardBorder : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
            color: ativo ? _C.text : _C.hint,
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
          colors: [Color(0xFF16A34A), AppColors.success],
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
    ];
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: _C.hint),
          SizedBox(height: 12),
          Text(
            'Você ainda não fez nenhuma denúncia',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _C.hint),
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
          stream: _ocorrenciaService.observarPorIds(favoritos),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.bookmark_border, size: 48, color: _C.hint),
          SizedBox(height: 12),
          Text(
            'Nenhuma denúncia salva ainda',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _C.hint),
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
              color: _C.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.cardBorder),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _C.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 13,
                            color: _C.hint,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              o.localizacao.trim().isEmpty
                                  ? 'Sem local'
                                  : o.localizacao,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _C.hint,
                              ),
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: _C.hint,
                            ),
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
                                  service: _ocorrenciaService,
                                )
                              : onRemoverSalvo,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _C.text.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _C.cardBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  gerenciar
                                      ? Icons.tune
                                      : Icons.bookmark_remove_outlined,
                                  size: 14,
                                  color: _C.text,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  gerenciar
                                      ? 'Gerenciar denúncia'
                                      : 'Remover dos salvos',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _C.text,
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
          ? Image.network(
              url,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              semanticLabel: 'Foto da denúncia: ${o.titulo}',
              errorBuilder: (_, _, _) => _thumbPlaceholder(),
            )
          : _thumbPlaceholder(),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: _C.avatarBg,
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
        .where((o) => o.verificada && o.statusOficial == 'resolvida')
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
