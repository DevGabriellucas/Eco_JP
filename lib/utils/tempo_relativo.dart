import 'package:intl/intl.dart';

/// Formata uma data como tempo relativo curto em português:
/// "agora", "5 min", "2 hrs", "ontem", "3 dias", "1 sem" e, para datas mais
/// antigas que uma semana, a data absoluta (dd/MM/yyyy).
///
/// Usado no feed, nos comentários e nas notificações para deixar o tempo
/// mais legível do que uma data/hora completa.
String tempoRelativo(DateTime? data, {DateTime? agora}) {
  if (data == null) return '';
  final referencia = agora ?? DateTime.now();
  final diff = referencia.difference(data);

  // Datas no futuro (relógios fora de sincronia) caem em "agora".
  if (diff.isNegative) return 'agora';

  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} hrs';
  if (diff.inDays == 1) return 'ontem';
  if (diff.inDays < 7) return '${diff.inDays} dias';
  if (diff.inDays < 14) return '1 sem';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} sem';

  return DateFormat('dd/MM/yyyy').format(data);
}

/// Rótulo do "grupo" de uma data, usado para separar listas (ex.: notificações)
/// em seções: "Hoje", "Ontem", "Esta semana" e "Mais antigas".
String grupoPorData(DateTime? data, {DateTime? agora}) {
  if (data == null) return 'Mais antigas';
  final referencia = agora ?? DateTime.now();
  final hoje = DateTime(referencia.year, referencia.month, referencia.day);
  final dia = DateTime(data.year, data.month, data.day);
  final diffDias = hoje.difference(dia).inDays;

  if (diffDias <= 0) return 'Hoje';
  if (diffDias == 1) return 'Ontem';
  if (diffDias < 7) return 'Esta semana';
  return 'Mais antigas';
}
