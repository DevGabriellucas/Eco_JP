import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fonte embutida do relatório gera PDF com "—", "•" e acentos', () async {
    // Mesmos assets que RelatorioService usa (assets/fonts no pubspec).
    final tema = pw.ThemeData.withFont(
      base:
          pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf')),
    );
    final doc = pw.Document(theme: tema)
      ..addPage(
        pw.Page(
          build: (_) => pw.Text('EcoJP — Relatório • João Pessoa, Manaíra'),
        ),
      );

    final bytes = await doc.save();

    expect(bytes.length, greaterThan(1000));
  });
}
