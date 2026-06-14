import 'package:flutter/material.dart';

import '../models/notificacao_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';
import '../services/ocorrencia_service.dart';
import '../utils/tempo_relativo.dart';
import 'detalhe_ocorrencia_page.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  final _authService = AuthService();
  final _service = NotificacaoService();
  final _ocorrenciaService = OcorrenciaService();
  bool _abrindo = false;

  @override
  void initState() {
    super.initState();
    // Ao abrir a tela, marca tudo como lido (zera o contador do sino).
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _service.marcarTodasComoLidas(uid);
    }
  }

  // Busca a denúncia da notificação e abre a tela de detalhes.
  Future<void> _abrirDenuncia(NotificacaoModel n) async {
    if (_abrindo) return;
    setState(() => _abrindo = true);
    try {
      final ocorrencia = await _ocorrenciaService.buscarPorId(n.ocorrenciaId);
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
      final grupo = grupoPorData(n.dataCriacao);
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
    final uid = _authService.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Notificações',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFD8D8D8)),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Faça login para ver suas notificações.'))
          : StreamBuilder<List<NotificacaoModel>>(
              stream: _service.listar(uid),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        titulo.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Color(0xFF8A8A8A),
        ),
      ),
    );
  }
}

class _NotificacaoTile extends StatelessWidget {
  final NotificacaoModel n;
  final VoidCallback onTap;
  const _NotificacaoTile(this.n, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isComentario = n.tipo == 'comentario';
    final icone = isComentario ? Icons.chat_bubble : Icons.thumb_up_alt;
    final cor = isComentario
        ? const Color(0xFF3B82F6)
        : const Color(0xFF4CAF50);
    final acao = isComentario ? 'comentou na' : 'curtiu a';

    return Container(
      color: n.lida ? Colors.white : const Color(0xFFEFF6FF),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.15),
          child: Icon(icone, size: 18, color: cor),
        ),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
            children: [
              TextSpan(
                text: n.deUsuarioNome,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ' $acao sua denúncia '),
              TextSpan(
                text: '"${n.ocorrenciaTitulo}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        subtitle: n.dataCriacao != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tempoRelativo(n.dataCriacao),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              )
            : null,
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: Color(0xFFBDBDBD),
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Color(0xFFBDBDBD)),
          SizedBox(height: 12),
          Text(
            'Você ainda não tem notificações',
            style: TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
          ),
          SizedBox(height: 4),
          Text(
            'Avisaremos quando alguém interagir\ncom as suas denúncias.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
          ),
        ],
      ),
    );
  }
}
