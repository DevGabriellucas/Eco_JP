import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/pages/detalhe_ocorrencia_page.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/pages/mapPage/widgets/affectedzones.dart';
import 'package:eco_jp/pages/mapPage/widgets/appbar.dart';
import 'package:eco_jp/pages/mapPage/widgets/categoryitems.dart';
import 'package:eco_jp/pages/mapPage/widgets/mapdisplay.dart';
import 'package:eco_jp/pages/mapPage/widgets/ocorrencia_map_sheet.dart';
import 'package:flutter/material.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraOcorrencias(context),
      body: const MapPageConteudo(),
    );
  }
}

class MapPageConteudo extends StatefulWidget {
  const MapPageConteudo({super.key});

  @override
  State<MapPageConteudo> createState() => _MapPageConteudoState();
}

class _MapPageConteudoState extends State<MapPageConteudo> {
  late final MapController controller;

  @override
  void initState() {
    super.initState();

    controller = MapController(aoTocarMarcador: _aoTocarMarcador);

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

        if (state is MapControllerStateLoading ||
            state is MapControllerStateInit) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MapControllerStateError) {
          return MapEmError(controller, state);
        }

        return Column(
          children: [
            Expanded(child: MapDisplay(controller: controller)),
            SizedBox(height: 48, child: CategoryItems(controller: controller)),
            SizedBox(height: 128, child: MostAffectedZones(controller)),
          ],
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
