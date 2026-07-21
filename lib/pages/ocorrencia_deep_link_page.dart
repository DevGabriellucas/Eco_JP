import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/routes.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../models/ocorrencia_model.dart';
import '../theme/app_theme.dart';
import 'detalhe_ocorrencia_page.dart';

/// Carrega uma ocorrência pelo id (vinda de um deeplink) e mostra o detalhe.
/// A tela de detalhe recebe o modelo pronto, então aqui buscamos primeiro no
/// repositório e tratamos os estados de carregando / não encontrada.
class OcorrenciaDeepLinkPage extends ConsumerStatefulWidget {
  final String id;

  const OcorrenciaDeepLinkPage({super.key, required this.id});

  @override
  ConsumerState<OcorrenciaDeepLinkPage> createState() =>
      _OcorrenciaDeepLinkPageState();
}

class _OcorrenciaDeepLinkPageState
    extends ConsumerState<OcorrenciaDeepLinkPage> {
  late final Future<OcorrenciaModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(ocorrenciaRepositoryProvider).buscarPorId(widget.id);
  }

  void _voltarAoFeed() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OcorrenciaModel?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final ocorrencia = snap.data;
        if (ocorrencia == null) {
          return _NaoEncontrada(onVoltar: _voltarAoFeed);
        }
        return DetalheOcorrenciaPage(occurrence: ocorrencia);
      },
    );
  }
}

class _NaoEncontrada extends StatelessWidget {
  final VoidCallback onVoltar;

  const _NaoEncontrada({required this.onVoltar});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: Icon(Icons.arrow_back, color: pal.ink),
          onPressed: onVoltar,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.hint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.link_off, size: 40, color: pal.hint),
              ),
              const SizedBox(height: 16),
              Text(
                'Denúncia não encontrada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pal.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'O link pode estar quebrado ou a denúncia foi removida.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: pal.hint),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onVoltar,
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Ir para o feed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
