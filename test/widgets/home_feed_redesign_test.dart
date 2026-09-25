import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/widgets/home/home_overview.dart';
import 'package:eco_jp/widgets/occurrence_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OcorrenciaModel occurrence() => OcorrenciaModel(
        id: 'occurrence-1',
        titulo: 'Descarte irregular próximo ao parque',
        descricao:
            'Resíduos acumulados na calçada dificultando a passagem de moradores.',
        localizacao:
            'Rua Vereador Pedro Alves de Souza, Geisel, João Pessoa - PB',
        latitude: -7.12,
        longitude: -34.88,
        tipoLixo: 'Lixo',
        status: 'Pendente',
        comments: 5,
        likes: 12,
      );

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets('HomeOverview funciona em ${width.toInt()} px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HomeOverview(
                occurrences: [occurrence()],
                selectedType: null,
                onSelectType: (_) {},
                onCreateOccurrence: () {},
                onOpenMap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Cidades mais verdes'), findsOneWidget);
      expect(find.textContaining('Problemas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('OccurrenceCard usa composição compacta sem overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: OccurrenceCard(
              occurrence: occurrence(),
              nomeAutor: 'Joana Silva',
              onLike: () async => true,
              onDislike: () {},
              onComment: () {},
              onOpenDetail: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Joana Silva'), findsOneWidget);
    expect(find.text('Descarte irregular próximo ao parque'), findsOneWidget);
    expect(find.text('Pendente'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
