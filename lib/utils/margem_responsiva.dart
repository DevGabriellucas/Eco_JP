/// Margem lateral que limita o conteúdo a [larguraMaxima] e o centraliza.
///
/// Em celular devolve a [margemMinima] de sempre; em tablet ou paisagem a
/// margem cresce para o conteúdo não esticar na tela toda (campos e botões
/// de 750 dp, linhas de texto longas demais).
double margemResponsiva(
  double largura, {
  required double margemMinima,
  required double larguraMaxima,
}) {
  final sobra = (largura - larguraMaxima) / 2;
  return sobra > margemMinima ? sobra : margemMinima;
}
