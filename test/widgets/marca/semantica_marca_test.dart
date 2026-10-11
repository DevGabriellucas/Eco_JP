import 'package:eco_jp/widgets/marca/aceite_termos.dart';
import 'package:eco_jp/widgets/marca/campo_marca.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget filho) => MaterialApp(home: Scaffold(body: filho));

  testWidgets('campo é anunciado com o rótulo e o olho continua acionável',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        CampoMarca(
          rotulo: 'REPETIR SENHA',
          child: Builder(
            builder: (context) => TextField(
              decoration: decoracaoCampoMarca(
                context,
                hint: 'Repita a senha',
                sufixo: IconButton(
                  tooltip: 'Mostrar senha',
                  onPressed: () {},
                  icon: const Icon(Icons.visibility),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // O campo de texto é anunciado com o rótulo (não só com o hint).
    expect(
      find.bySemanticsLabel(RegExp('Repetir senha')),
      findsOneWidget,
    );
    final campo = tester
        .getSemantics(find.bySemanticsLabel(RegExp('Repetir senha')))
        .getSemanticsData();
    expect(campo.flagsCollection.isTextField, isTrue);

    // O botão do olho segue sendo um nó próprio, com ação de toque.
    final olho = tester.getSemantics(find.byTooltip('Mostrar senha'));
    expect(olho.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(olho.getSemanticsData().flagsCollection.isTextField, isFalse);
    semantica.dispose();
  });

  testWidgets('aceite: checkbox com rótulo próprio', (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        AceiteTermos(
          valor: false,
          onChanged: (_) {},
          onAbrirPolitica: () {},
          onAbrirTermos: () {},
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Aceito a Política de Privacidade e os Termos de Uso',
      ),
      findsOneWidget,
    );
    semantica.dispose();
  });
}
