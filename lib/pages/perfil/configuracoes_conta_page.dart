import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../data/repositories/ocorrencia_repository.dart';
import '../../features/denuncias/providers/denuncia_providers.dart';
import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/consent_service.dart';
import '../../services/relatorio_service.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../legal/documentos_legais.dart';

class _C {
  // Vermelho de ação destrutiva — igual nos dois temas.
  static const sair = Color(0xFFC62828);
}

/// Sub-tela de conta: aparência (tema), documentos legais, exportar dados
/// (LGPD), sair e excluir conta. Separada do perfil para tirar a ação
/// destrutiva do caminho acidental.
class ConfiguracoesContaPage extends ConsumerStatefulWidget {
  const ConfiguracoesContaPage({super.key});

  @override
  ConsumerState<ConfiguracoesContaPage> createState() =>
      _ConfiguracoesContaPageState();
}

class _ConfiguracoesContaPageState
    extends ConsumerState<ConfiguracoesContaPage> {
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _consentService = ConsentService();
  final _relatorioService = RelatorioService();

  OcorrenciaRepository get _ocorrenciaRepository =>
      ref.read(ocorrenciaRepositoryProvider);

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
            nome:
                _authService.currentUser?.email?.split('@').first ?? 'Usuário',
          );
      final ocorrencias = await _ocorrenciaRepository
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
    final pal = context.pal;
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sair da conta',
          style: TextStyle(fontWeight: FontWeight.w700, color: pal.ink),
        ),
        content: Text(
          'Tem certeza que deseja sair da sua conta?',
          style: TextStyle(color: pal.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: pal.hint)),
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
      // O redirect do router reage ao logout, mas garantimos a saída da pilha
      // imperativa (esta tela foi aberta via push) indo direto à tela inicial.
      if (mounted) context.go(Routes.inicial);
    }
  }

  // ── Excluir conta (LGPD art. 18) ─────────────────────────────────────────

  Future<void> _confirmarExclusaoConta() async {
    final pal = context.pal;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir conta',
          style: TextStyle(fontWeight: FontWeight.w700, color: pal.ink),
        ),
        content: Text(
          'Esta ação é permanente e não pode ser desfeita.\n\n'
          'Serão apagados:\n'
          '• Seu perfil e dados cadastrais\n'
          '• Todas as suas denúncias\n'
          '• Suas notificações\n\n'
          'Deseja continuar?',
          style: TextStyle(color: pal.ink, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: pal.hint)),
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
          SnackBar(
            content: Text(authResult.message ?? 'Erro ao excluir conta.'),
          ),
        );
      }
      return;
    }

    // A conta Auth já foi removida neste ponto e essa etapa não tem retry: se
    // a exclusão dos dados falhar (rede, permissão), o perfil/denúncias/
    // notificações ficam órfãos no Firestore — obrigação legal (LGPD art. 18)
    // não cumprida. Registra no Crashlytics para localizar a conta depois e
    // avisa o usuário em vez de seguir em frente como se tivesse dado certo.
    var dadosExcluidos = true;
    try {
      await _usuarioService.excluirTodosDados(uid);
    } catch (e, stack) {
      dadosExcluidos = false;
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Falha ao excluir dados do Firestore após excluir conta Auth',
        information: ['uid: $uid'],
      );
    }

    if (mounted) {
      setState(() => _excluindo = false);
      if (!dadosExcluidos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sua conta foi encerrada, mas houve uma falha ao apagar seus '
              'dados. Nossa equipe foi notificada e concluirá a exclusão.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
      context.go(Routes.inicial);
    }
  }

  Future<AuthResult> _pedirReautenticacao() async {
    final pal = context.pal;
    final senhaCtrl = TextEditingController();
    AuthResult? resultado;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirme sua senha',
          style: TextStyle(fontWeight: FontWeight.w700, color: pal.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Por segurança, confirme sua senha para excluir a conta.',
              style: TextStyle(color: pal.hint, fontSize: 13),
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
                  borderSide: BorderSide(color: pal.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: pal.ink, width: 1.5),
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
            child: Text('Cancelar', style: TextStyle(color: pal.hint)),
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
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Conta e privacidade',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: pal.ink,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: pal.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _grupoTitulo('Aparência'),
          _seletorTema(pal),
          const SizedBox(height: 22),
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
            Divider(height: 1, color: pal.border),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'A exclusão da conta apaga seu perfil, denúncias e notificações de '
              'forma permanente.',
              style: TextStyle(fontSize: 12, color: pal.hint, height: 1.4),
            ),
          ),
          const SizedBox(height: 22),
          _grupoTitulo('Sessão'),
          _cartao([
            _linha(
              Icons.logout,
              'Sair da conta',
              _confirmarLogout,
              cor: _C.sair,
            ),
          ]),
        ],
      ),
    );
  }

  // Seletor de tema: Sistema / Claro / Escuro (segmentado).
  Widget _seletorTema(AppPalette pal) {
    final atual = ref.watch(themeModeProvider);
    const opcoes = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, 'Sistema', Icons.brightness_auto_outlined),
      (ThemeMode.light, 'Claro', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Escuro', Icons.dark_mode_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          for (final (modo, rotulo, icone) in opcoes)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(themeModeProvider.notifier).definir(modo),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: atual == modo
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icone,
                        size: 20,
                        color: atual == modo ? Colors.white : pal.muted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rotulo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: atual == modo ? Colors.white : pal.muted,
                        ),
                      ),
                    ],
                  ),
                ),
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
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: context.pal.hint,
      ),
    ),
  );

  Widget _cartao(List<Widget> filhos) {
    final pal = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(children: filhos),
    );
  }

  Widget _linha(
    IconData icone,
    String titulo,
    VoidCallback? onTap, {
    Color? cor,
  }) {
    final pal = context.pal;
    final corFinal = cor ?? pal.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icone, size: 19, color: corFinal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
                  color: corFinal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: pal.hint),
          ],
        ),
      ),
    );
  }
}
