import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notificacao_model.dart';
import '../services/auth_service.dart';
import '../services/notificacao_service.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  final _authService = AuthService();
  final _service = NotificacaoService();

  @override
  void initState() {
    super.initState();
    // Ao abrir a tela, marca tudo como lido (zera o contador do sino).
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _service.marcarTodasComoLidas(uid);
    }
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
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notificacoes.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFEAEAEA)),
                  itemBuilder: (_, i) => _NotificacaoTile(notificacoes[i]),
                );
              },
            ),
    );
  }
}

class _NotificacaoTile extends StatelessWidget {
  final NotificacaoModel n;
  const _NotificacaoTile(this.n);

  @override
  Widget build(BuildContext context) {
    final isComentario = n.tipo == 'comentario';
    final icone = isComentario ? Icons.chat_bubble : Icons.thumb_up_alt;
    final cor =
        isComentario ? const Color(0xFF3B82F6) : const Color(0xFF4CAF50);
    final acao = isComentario ? 'comentou na' : 'curtiu a';

    return Container(
      color: n.lida ? Colors.white : const Color(0xFFEFF6FF),
      child: ListTile(
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
                  DateFormat('dd/MM/yyyy HH:mm').format(n.dataCriacao!),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
                ),
              )
            : null,
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
