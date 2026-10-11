import 'package:eco_jp/theme/app_theme.dart';
import 'package:eco_jp/theme/marca_cores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // O tema cria estilos da Poppins; sem rede no teste, não tenta baixar.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('os temas do app registram a paleta de marca certa',
      (tester) async {
    expect(AppTheme.light().extension<MarcaCores>(), MarcaCores.light);
    expect(AppTheme.dark().extension<MarcaCores>(), MarcaCores.dark);
    // Carregamentos de fonte que falham (sem rede) não interessam aqui.
    await tester.pump();
    tester.takeException();
  });
}
