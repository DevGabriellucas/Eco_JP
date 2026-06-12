import 'package:flutter/material.dart';
import 'controller/map_controller.dart';
import 'widgets/mapdisplay.dart';
import 'widgets/appbar.dart';
import 'widgets/affectedzones.dart';
import 'widgets/categoryitems.dart';

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

    controller = MapController();

    controller.loadOcorrencias();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
            Expanded(flex: 9, child: MapDisplay(controller: controller)),
            const Expanded(flex: 3, child: CategoryItems()),
            Expanded(flex: 2, child: MostAffectedZones(controller)),
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
