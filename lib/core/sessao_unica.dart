import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_providers.dart';
import '../services/sessao_service.dart';

/// Messenger do app inteiro: o aviso de sessão encerrada aparece depois do
/// logout, quando a tela que estava aberta já saiu da árvore.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerGlobal =
    GlobalKey<ScaffoldMessengerState>();

final sessaoServiceProvider =
    Provider<SessaoService>((ref) => SessaoService.instance);

/// Desconecta este aparelho quando a mesma conta entra em outro (ver
/// [SessaoService]). Antes duas pessoas usavam a mesma conta ao mesmo tempo.
class SessaoUnicaListener extends ConsumerStatefulWidget {
  const SessaoUnicaListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessaoUnicaListener> createState() =>
      _SessaoUnicaListenerState();
}

class _SessaoUnicaListenerState extends ConsumerState<SessaoUnicaListener> {
  StreamSubscription<void>? _sub;
  String? _uid;

  SessaoService get _sessao => ref.read(sessaoServiceProvider);

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<User?>>(
      authStateChangesProvider,
      (_, estado) {
        if (estado.hasValue) _aoMudarUsuario(estado.value?.uid);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _aoMudarUsuario(String? uid) async {
    if (uid == _uid) return;
    final anterior = _uid;
    _uid = uid;
    await _sub?.cancel();
    _sub = null;
    if (anterior != null) await _sessao.esquecerSessaoLocal(anterior);
    if (uid == null) return;

    final idLocal = await _sessao.garantirSessaoLocal(uid);
    // Trocou de usuário (ou saiu) enquanto registrava: o registro já não vale.
    if (idLocal == null || !mounted || _uid != uid) return;
    _sub = _sessao.observarSessaoSubstituida(uid, idLocal).listen(
          (_) => _encerrar(),
          onError: (Object e) => debugPrint('Erro ao observar a sessão: $e'),
        );
  }

  Future<void> _encerrar() async {
    await _sub?.cancel();
    _sub = null;
    // O logout dispara _aoMudarUsuario(null), que esquece o id local.
    await ref.read(authServiceProvider).sair();
    scaffoldMessengerGlobal.currentState?.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 8),
        content: Text(
          'Sua conta foi acessada em outro aparelho e esta sessão foi '
          'encerrada. Se não foi você, entre de novo e troque a senha.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
