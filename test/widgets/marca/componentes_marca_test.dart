import 'package:eco_jp/widgets/marca/aceite_termos.dart';
import 'package:eco_jp/widgets/marca/botao_primario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget filho) => MaterialApp(home: Scaffold(body: filho));

  group('AceiteTermos', () {
    testWidgets('tocar na linha alterna o aceite', (tester) async {
      var valor = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => app(
            AceiteTermos(
              valor: valor,
              onChanged: (v) => setState(() => valor = v),
              onAbrirPolitica: () {},
              onAbrirTermos: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(valor, isTrue);
    });

    testWidgets('links abrem os documentos sem marcar a caixa', (tester) async {
      var politica = 0;
      var termos = 0;
      var mudou = false;
      await tester.pumpWidget(
        app(
          AceiteTermos(
            valor: false,
            onChanged: (_) => mudou = true,
            onAbrirPolitica: () => politica++,
            onAbrirTermos: () => termos++,
          ),
        ),
      );

      final texto = find.byType(RichText).last;
      await tester
          .tapOnText(find.textRange.ofSubstring('Política de Privacidade'));
      await tester.tapOnText(find.textRange.ofSubstring('Termos de Uso'));
      expect(texto, findsOneWidget);
      expect(politica, 1);
      expect(termos, 1);
      expect(mudou, isFalse);
    });

    testWidgets('desabilitado não alterna', (tester) async {
      await tester.pumpWidget(
        app(
          AceiteTermos(
            valor: false,
            onChanged: null,
            onAbrirPolitica: () {},
            onAbrirTermos: () {},
          ),
        ),
      );
      final caixa = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(caixa.onChanged, isNull);
    });
  });

  group('BotaoPrimario', () {
    testWidgets('carregando troca o texto pelo indicador', (tester) async {
      await tester.pumpWidget(
        app(BotaoPrimario(texto: 'Enviar', onPressed: () {}, carregando: true)),
      );
      expect(find.text('Enviar'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('sem onPressed fica desabilitado', (tester) async {
      await tester.pumpWidget(
        app(const BotaoPrimario(texto: 'Enviar', onPressed: null)),
      );
      final botao = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(botao.enabled, isFalse);
    });
  });
}
