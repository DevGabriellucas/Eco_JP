import 'package:eco_jp/pages/legal/consentimento_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int aceites;
  late int recusas;

  setUp(() {
    aceites = 0;
    recusas = 0;
  });

  Future<void> montar(
    WidgetTester tester, {
    Size tamanho = const Size(360, 800),
    double escalaTexto = 1.0,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: tamanho,
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            textScaler: TextScaler.linear(escalaTexto),
          ),
          child: ConsentimentoPage(
            onAceitar: () async => aceites++,
            // Logout leva um tempo: um segundo toque nesse intervalo não
            // pode chamar de novo.
            onRecusar: () async {
              recusas++;
              await Future<void>.delayed(const Duration(milliseconds: 500));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ElevatedButton botaoConcordar(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Concordar e continuar'),
      );

  testWidgets('mostra os 4 tópicos e as ações', (tester) async {
    await montar(tester);
    expect(find.text('Privacidade e Termos'), findsOneWidget);
    expect(find.textContaining('Coletamos nome'), findsOneWidget);
    expect(find.textContaining('excluir suas denúncias'), findsOneWidget);
    expect(find.text('Não concordo / sair'), findsOneWidget);
  });

  testWidgets('sem aceite o botão fica desabilitado', (tester) async {
    await montar(tester);
    expect(botaoConcordar(tester).enabled, isFalse);
  });

  testWidgets('aceitar e concordar chama onAceitar', (tester) async {
    await montar(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(botaoConcordar(tester).enabled, isTrue);

    await tester.tap(find.text('Concordar e continuar'));
    await tester.pump();
    expect(aceites, 1);
  });

  testWidgets('"Não concordo" chama onRecusar uma vez só', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Não concordo / sair'));
    await tester.pump();
    await tester.tap(find.text('Não concordo / sair'));
    await tester.pump(const Duration(seconds: 1));
    expect(recusas, 1);
  });

  const tamanhos = {
    'estreito 320x568': Size(320, 568),
    'frame 360x800': Size(360, 800),
    'tablet 800x1280': Size(800, 1280),
    'paisagem 800x360': Size(800, 360),
    'paisagem baixa 640x320': Size(640, 320),
  };

  for (final MapEntry(key: nome, value: tamanho) in tamanhos.entries) {
    for (final escala in [1.0, 2.0]) {
      testWidgets('sem overflow: $nome, texto ${escala}x', (tester) async {
        await montar(tester, tamanho: tamanho, escalaTexto: escala);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
