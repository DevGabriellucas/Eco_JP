import 'package:flutter/material.dart';

import '../../models/ocorrencia_model.dart';
import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/ocorrencia_service.dart';
import '../../services/usuario_service.dart';
import '../detalhe_ocorrencia_page.dart';
import '../../models/occurrence_types.dart';
import '../../widgets/ocorrencia_actions.dart';
import 'editar_perfil_page.dart';

class _C {
  static const bg = Colors.white;
  static const cardBg = Color(0xFFEDEDED);
  static const cardBorder = Color(0xFFD8D8D8);
  static const avatarBg = Color(0xFF9E9E9E);
  static const text = Color(0xFF1A1A1A);
  static const hint = Color(0xFF8A8A8A);
  static const laranja = Color(0xFFFF8A1F);
  static const sair = Color(0xFFC62828);
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

  int _aba = 0; // 0 = Estatísticas, 1 = Minhas denúncias

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

  Future<void> _confirmarLogout() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sair da conta',
          style: TextStyle(fontWeight: FontWeight.w700, color: _C.text),
        ),
        content: const Text(
          'Tem certeza que deseja sair da sua conta?',
          style: TextStyle(color: _C.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _C.hint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.sair,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (sair == true) {
      await _authService.sair();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
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
            stream: _ocorrenciaService.listarPorUsuario(uid),
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
                      const SizedBox(height: 20),
                      _botaoSair(),
                    ] else
                      ..._secaoMinhasDenuncias(ocorrencias),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _avatar(perfil),
              const SizedBox(height: 14),
              Text(
                perfil.nome.trim().isEmpty ? 'Sem nome' : perfil.nome,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _C.text,
                ),
              ),
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
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _abrirEdicao(perfil),
              child: const Icon(Icons.edit_outlined, size: 22, color: _C.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(UsuarioModel perfil) {
    if (perfil.fotoUrl != null && perfil.fotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 46,
        backgroundColor: _C.avatarBg,
        backgroundImage: NetworkImage(perfil.fotoUrl!),
      );
    }
    return CircleAvatar(
      radius: 46,
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

  Widget _cardTaxa(int taxa) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        children: [
          const Text(
            'Taxa de resolução',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _C.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$taxa%',
            style: const TextStyle(
              fontSize: 32,
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

  Widget _botaoSair() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _confirmarLogout,
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.sair,
          side: const BorderSide(color: _C.sair),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.logout, size: 18),
        label: const Text(
          'Sair da conta',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Abas (Estatísticas / Minhas denúncias) ────────────────────────────────

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
          Expanded(child: _abaBtn('Estatísticas', 0)),
          Expanded(child: _abaBtn('Minhas denúncias', 1)),
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

  List<Widget> _secaoEstatisticas(_Stats stats) {
    return [
      Row(
        children: [
          Expanded(child: _cardStat('Denúncias', '${stats.total}')),
          const SizedBox(width: 14),
          Expanded(child: _cardStat('Curtidas recebidas', '${stats.curtidas}')),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(child: _cardStat('Resolvidas', '${stats.resolvidas}')),
          const SizedBox(width: 14),
          Expanded(child: _cardStat('Andamento', '${stats.andamento}')),
        ],
      ),
      const SizedBox(height: 14),
      _cardTaxa(stats.taxa),
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

  Widget _denunciaCard(OcorrenciaModel o) {
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
                      GestureDetector(
                        onTap: () => showOcorrenciaActions(
                          context: context,
                          ocorrencia: o,
                          service: _ocorrenciaService,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _C.text.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _C.cardBorder),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tune, size: 14, color: _C.text),
                              SizedBox(width: 6),
                              Text(
                                'Gerenciar denúncia',
                                style: TextStyle(
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
    final resolvidas = ocorrencias
        .where(
          (o) =>
              OccurrenceStatusParser.fromString(o.status) ==
              OccurrenceStatus.resolved,
        )
        .length;
    final andamento = ocorrencias
        .where(
          (o) =>
              OccurrenceStatusParser.fromString(o.status) ==
              OccurrenceStatus.inProgress,
        )
        .length;
    // Taxa de resolução = Resolvidas / total de denúncias
    final base = ocorrencias.length;
    final taxa = base == 0 ? 0 : ((resolvidas / base) * 100).round();

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

    return _Stats(
      total: base,
      curtidas: curtidas,
      resolvidas: resolvidas,
      andamento: andamento,
      taxa: taxa,
      categoriaTop: categoriaTop,
    );
  }
}

class _Stats {
  final int total;
  final int curtidas;
  final int resolvidas;
  final int andamento;
  final int taxa;
  final String? categoriaTop;

  _Stats({
    required this.total,
    required this.curtidas,
    required this.resolvidas,
    required this.andamento,
    required this.taxa,
    required this.categoriaTop,
  });
}
