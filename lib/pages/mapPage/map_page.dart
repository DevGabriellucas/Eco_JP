import 'package:eco_jp/features/denuncias/providers/denuncia_providers.dart';
import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/pages/detalhe_ocorrencia_page.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/pages/mapPage/widgets/appbar.dart';
import 'package:eco_jp/pages/mapPage/widgets/category_drawer.dart';
import 'package:eco_jp/pages/mapPage/widgets/mapdisplay.dart';
import 'package:eco_jp/pages/mapPage/widgets/ocorrencia_map_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapPageConteudo();
  }
}

class MapPageConteudo extends ConsumerStatefulWidget {
  const MapPageConteudo({super.key});

  @override
  ConsumerState<MapPageConteudo> createState() => _MapPageConteudoState();
}

class _MapPageConteudoState extends ConsumerState<MapPageConteudo> {
  late final MapController controller;

  @override
  void initState() {
    super.initState();

    controller = MapController(
      aoTocarMarcador: _aoTocarMarcador,
      service: ref.read(ocorrenciaRepositoryProvider),
    );

    controller.loadOcorrencias();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Mostra o resumo da ocorrência e, se solicitado, abre os detalhes.
  Future<void> _aoTocarMarcador(OcorrenciaModel ocorrencia) async {
    final verDetalhes = await mostrarOcorrenciaSheet(context, ocorrencia);
    if (verDetalhes != true || !mounted) return;

    // Aguarda o bottom sheet terminar de fechar antes de empurrar a rota.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalheOcorrenciaPage(occurrence: ocorrencia),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final state = controller.state;

        Widget body;
        if (state is MapControllerStateLoading ||
            state is MapControllerStateInit) {
          body = const Center(child: CircularProgressIndicator());
        } else if (state is MapControllerStateError) {
          body = MapEmError(controller, state);
        } else {
          // Mapa full-bleed: os filtros de categoria ficam no menu lateral
          // (endDrawer, ícone de hambúrguer), então o mapa ocupa toda a área.
          body = MapDisplay(controller: controller);
        }

        return Scaffold(
          appBar: barraOcorrencias(context),
          endDrawer: CategoryDrawer(controller: controller),
          body: body,
        );
      },
    );
  }
}

class MapEmError extends StatelessWidget {
  final MapController controller;
  final MapControllerStateError state;
  const MapEmError(this.controller, this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(height: 12),
          Text(state.errorMsg),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: controller.loadOcorrencias,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
