import 'package:flutter/material.dart';

import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/consent_service.dart';
import '../../services/ocorrencia_service.dart';
import '../../services/relatorio_service.dart';
import '../../services/usuario_service.dart';
import '../legal/documentos_legais.dart';

class _C {
  static const bg = Colors.white;
  static const cardBg = Color(0xFFEDEDED);
  static const cardBorder = Color(0xFFD8D8D8);
  static const text = Color(0xFF1A1A1A);
  static const hint = Color(0xFF8A8A8A);
  static const sair = Color(0xFFC62828);
}

/// Sub-tela de conta: documentos legais, exportar dados (LGPD), sair e excluir
/// conta. Separada do perfil para tirar a ação destrutiva do caminho acidental.
class ConfiguracoesContaPage extends StatefulWidget {
  const ConfiguracoesContaPage({super.key});

  @override
  State<ConfiguracoesContaPage> createState() => _ConfiguracoesContaPageState();
}

class _ConfiguracoesContaPageState extends State<ConfiguracoesContaPage> {
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _ocorrenciaService = OcorrenciaService();
  final _consentService = ConsentService();
  final _relatorioService = RelatorioService();

  bool _excluindo = false;
  bool _exportandoDados = false;

  void _abrirDocumento(String titulo, String conteudo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentoLegalPage(titulo: titulo, conteudo: conteudo),
      ),
    );
  }

  // ── Exportar meus dados (LGPD art. 18) ───────────────────────────────────

  Future<void> _exportarMeusDados() async {
    if (_exportandoDados) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    setState(() => _exportandoDados = true);
    try {
      final perfil =
          await _usuarioService.carregarPerfil(uid) ??
          UsuarioModel(
            uid: uid,
            nome: _authService.currentUser?.email?.split('@').first ?? 'Usuário',
          );
      final ocorrencias = await _ocorrenciaService
          .listarPorUsuario(uid)
          .first;
      final consentimentoEm = await _consentService.dataConsentimento(uid);
      await _relatorioService.exportarMeusDados(
        perfil: perfil,
        ocorrencias: ocorrencias,
        email: _authService.currentUser?.email,
        consentimentoEm: consentimentoEm,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível exportar os dados.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportandoDados = false);
    }
  }

  // ── Sair ─────────────────────────────────────────────────────────────────

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

  // ── Excluir conta (LGPD art. 18) ─────────────────────────────────────────

  Future<void> _confirmarExclusaoConta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir conta',
          style: TextStyle(fontWeight: FontWeight.w700, color: _C.text),
        ),
        content: const Text(
          'Esta ação é permanente e não pode ser desfeita.\n\n'
          'Serão apagados:\n'
          '• Seu perfil e dados cadastrais\n'
          '• Todas as suas denúncias\n'
          '• Suas notificações\n\n'
          'Deseja continuar?',
          style: TextStyle(color: _C.text, height: 1.5),
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
            child: const Text('Excluir minha conta'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _excluindo = true);
    var authResult = await _authService.excluirContaAuth();

    if (authResult.message == 'requires-recent-login' && mounted) {
      setState(() => _excluindo = false);
      authResult = await _pedirReautenticacao();
      if (!mounted) return;
      if (!authResult.success) return;
      setState(() => _excluindo = true);
      authResult = await _authService.excluirContaAuth();
    }

    if (!authResult.success) {
      if (mounted) {
        setState(() => _excluindo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authResult.message ?? 'Erro ao excluir conta.')),
        );
      }
      return;
    }

    try {
      await _usuarioService.excluirTodosDados(uid);
    } catch (_) {
      // Conta Auth já removida; dados podem ficar órfãos sem bloquear o fluxo.
    }

    if (mounted) {
      setState(() => _excluindo = false);
      Navigator.of(context).pushNamedAndRemoveUntil('/inicial', (_) => false);
    }
  }

  Future<AuthResult> _pedirReautenticacao() async {
    final senhaCtrl = TextEditingController();
    AuthResult? resultado;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirme sua senha',
          style: TextStyle(fontWeight: FontWeight.w700, color: _C.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por segurança, confirme sua senha para excluir a conta.',
              style: TextStyle(color: _C.hint, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: senhaCtrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Senha',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.text, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              resultado = AuthResult(success: false, message: 'Cancelado.');
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar', style: TextStyle(color: _C.hint)),
          ),
          ElevatedButton(
            onPressed: () async {
              final r = await _authService.reautenticarSenha(senhaCtrl.text);
              resultado = r;
              if (!ctx.mounted) return;
              if (r.success) {
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(r.message ?? 'Senha incorreta.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.sair,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => senhaCtrl.dispose());
    return resultado ?? AuthResult(success: false, message: 'Cancelado.');
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        foregroundColor: _C.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Conta e privacidade',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _C.text,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _C.cardBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _grupoTitulo('Documentos'),
          _cartao([
            _linha(
              Icons.privacy_tip_outlined,
              'Política de Privacidade',
              () => _abrirDocumento(
                'Política de Privacidade',
                kPoliticaPrivacidade,
              ),
            ),
            const Divider(height: 1, color: _C.cardBorder),
            _linha(
              Icons.description_outlined,
              'Termos de Uso',
              () => _abrirDocumento('Termos de Uso', kTermosDeUso),
            ),
          ]),
          const SizedBox(height: 22),
          _grupoTitulo('Meus dados'),
          _cartao([
            _linha(
              _exportandoDados
                  ? Icons.hourglass_empty
                  : Icons.download_outlined,
              _exportandoDados ? 'Exportando...' : 'Exportar meus dados',
              _exportandoDados ? null : _exportarMeusDados,
            ),
          ]),
          const SizedBox(height: 22),
          _grupoTitulo('Sessão'),
          _cartao([
            _linha(Icons.logout, 'Sair da conta', _confirmarLogout, cor: _C.sair),
          ]),
          const SizedBox(height: 22),
          _grupoTitulo('Zona de perigo'),
          _cartao([
            _linha(
              Icons.delete_forever_outlined,
              _excluindo ? 'Excluindo...' : 'Excluir minha conta',
              _excluindo ? null : _confirmarExclusaoConta,
              cor: _C.sair,
            ),
          ]),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'A exclusão da conta apaga seu perfil, denúncias e notificações de '
              'forma permanente.',
              style: TextStyle(fontSize: 12, color: _C.hint, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grupoTitulo(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: _C.hint,
      ),
    ),
  );

  Widget _cartao(List<Widget> filhos) => Container(
    decoration: BoxDecoration(
      color: _C.cardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.cardBorder),
    ),
    child: Column(children: filhos),
  );

  Widget _linha(
    IconData icone,
    String titulo,
    VoidCallback? onTap, {
    Color cor = _C.text,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icone, size: 19, color: cor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
                  color: cor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18, color: _C.hint),
          ],
        ),
      ),
    );
  }
}
