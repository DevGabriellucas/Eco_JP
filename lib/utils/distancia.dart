/// Formata uma distância em metros para exibição amigável em pt-BR.
///
/// Menos de 1 km → "350 m"; a partir daí → "2,3 km" (uma casa até 10 km,
/// inteiro acima disso). Usa vírgula como separador decimal.
String formatarDistancia(double metros) {
  if (metros < 1000) return '${metros.round()} m';
  final km = metros / 1000;
  final texto = km.toStringAsFixed(km >= 10 ? 0 : 1).replaceAll('.', ',');
  return '$texto km';
}
