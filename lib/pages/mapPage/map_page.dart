import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/pages/detalhe_ocorrencia_page.dart';
import 'package:eco_jp/pages/mapPage/controller/map_controller.dart';
import 'package:eco_jp/pages/mapPage/widgets/affectedzones.dart';
import 'package:eco_jp/pages/mapPage/widgets/appbar.dart';
import 'package:eco_jp/pages/mapPage/widgets/category_drawer.dart';
import 'package:eco_jp/pages/mapPage/widgets/categoryitems.dart';
import 'package:eco_jp/pages/mapPage/widgets/busca_bairro_sheet.dart';
import 'package:eco_jp/pages/mapPage/widgets/mapdisplay.dart';
import 'package:eco_jp/pages/mapPage/widgets/ocorrencia_map_sheet.dart';
import 'package:eco_jp/pages/mapPage/widgets/rota_coleta_sheet.dart';
import 'package:flutter/material.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapPageConteudo();
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

  /// Abre a busca por bairro; ao escolher, localiza no mapa e mostra a agenda.
  Future<void> _aoBuscarBairro() async {
    await controller.carregarRotasSeNecessario();
    if (!mounted) return;

    final bairro = await mostrarBuscaBairroSheet(context, controller);
    if (bairro == null || !mounted) return;

    await controller.selecionarBairro(bairro);
    if (!mounted) return;

    await mostrarAgendaBairroSheet(
      context,
      bairro,
      controller.agendasDoBairro(bairro),
    );
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
          // Em paisagem a altura é curta; as faixas fixas (chips + zonas) não
          // cabem junto com o mapa e causavam overflow. Mantemos só os chips e
          // escondemos o painel de zonas, que é informação secundária.
          final isLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;

          // top/left/right ficam por conta do AppBar e do mapa (full-bleed);
          // só protegemos a base para os painéis não ficarem sob a barra de
          // navegação do sistema (gestos/home indicator).
          body = SafeArea(
            top: false,
            left: false,
            right: false,
            child: Column(
              children: [
                Expanded(child: MapDisplay(controller: controller)),
                // Limita a escala de fonte nas faixas de altura fixa para que
                // o ajuste de "fonte grande" do sistema não cause overflow.
                SizedBox(
                  height: 48,
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.2,
                    child: CategoryItems(controller: controller),
                  ),
                ),
                if (!isLandscape)
                  SizedBox(
                    height: 128,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.2,
                      child: MostAffectedZones(controller),
                    ),
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: barraOcorrencias(context, onBuscarBairro: _aoBuscarBairro),
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
