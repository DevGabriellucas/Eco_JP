import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de conexão do aparelho: `true` quando há alguma interface de rede
/// ativa (wi-fi ou dados móveis), `false` quando está sem nenhuma.
///
/// Não garante que a internet realmente funciona (só que existe uma rede),
/// mas é suficiente para avisar o usuário de que ele pode estar vendo dados
/// salvos localmente (cache offline do Firestore).
///
/// Enquanto o primeiro valor não chega, assume online (`true`) para não
/// piscar o aviso de offline à toa na abertura do app.
final conexaoOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  final initialResult = await connectivity.checkConnectivity();
  yield _isOnline(initialResult);

  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
