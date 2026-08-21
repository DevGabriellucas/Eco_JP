import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'router/routes.dart';

/// Esquema custom do app para deeplinks (ex.: `ecojp://ocorrencia/<id>`).
const String kDeepLinkScheme = 'ecojp';
const String kDeepLinkHostOcorrencia = 'ocorrencia';

/// Monta o deeplink de uma ocorrência para compartilhamento.
String deepLinkOcorrencia(String id) =>
    '$kDeepLinkScheme://$kDeepLinkHostOcorrencia/$id';

/// Extrai o id de ocorrência de um deeplink, ou `null` se não for do tipo
/// esperado. Aceita `ecojp://ocorrencia/<id>` (host = ocorrencia) e também o
/// formato com path `ecojp:///ocorrencia/<id>`.
String? ocorrenciaIdFromUri(Uri uri) {
  if (uri.scheme != kDeepLinkScheme) return null;
  if (uri.host == kDeepLinkHostOcorrencia && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first;
  }
  final segs = uri.pathSegments;
  final i = segs.indexOf(kDeepLinkHostOcorrencia);
  if (i != -1 && i + 1 < segs.length) return segs[i + 1];
  return null;
}

/// Escuta deeplinks (app aberto por um link) e navega para a ocorrência
/// correspondente. Cobre tanto o app já em execução (stream) quanto o
/// lançamento "frio" (link inicial). O gate de auth do router decide se o
/// usuário chega direto no detalhe ou passa antes pelo login.
class DeepLinkListener extends ConsumerStatefulWidget {
  final Widget child;

  const DeepLinkListener({super.key, required this.child});

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _sub = _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
    // Link que abriu o app "frio": navega após o primeiro frame para o router
    // já estar montado.
    _handleInitialLink();
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _handle(uri));
    } catch (e) {
      // Sem link inicial válido não há para onde navegar; app abre normal.
      debugPrint('Deep link inicial ignorado: $e');
    }
  }

  void _handle(Uri uri) {
    final id = ocorrenciaIdFromUri(uri);
    if (id == null || !mounted) return;
    // push (não go) preserva a tela atual embaixo — o "voltar" do detalhe
    // retorna ao feed em vez de deixar o usuário sem para onde voltar.
    ref.read(goRouterProvider).push('${Routes.ocorrencia}/$id');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
