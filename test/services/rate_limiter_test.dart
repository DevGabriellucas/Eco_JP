import 'package:eco_jp/services/rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rl = RateLimiter.instance;
  const intervalo = Duration(seconds: 30);

  test('ação inédita é permitida', () {
    expect(rl.permitido('acao-nova-a', intervalo), isTrue);
    expect(rl.tempoRestante('acao-nova-a', intervalo), Duration.zero);
  });

  test('após registrar, a mesma ação fica bloqueada dentro do intervalo', () {
    rl.registrar('acao-b');
    expect(rl.permitido('acao-b', intervalo), isFalse);
    final restante = rl.tempoRestante('acao-b', intervalo);
    expect(restante, greaterThan(Duration.zero));
    expect(restante, lessThanOrEqualTo(intervalo));
  });

  test('intervalo zero nunca bloqueia', () {
    rl.registrar('acao-c');
    expect(rl.permitido('acao-c', Duration.zero), isTrue);
  });

  test('chaves diferentes não interferem entre si', () {
    rl.registrar('acao-d');
    expect(rl.permitido('acao-d', intervalo), isFalse);
    expect(rl.permitido('acao-e', intervalo), isTrue);
  });

  group('checarERegistrar', () {
    test('primeira chamada passa e registra; segunda lança exceção', () {
      expect(() => rl.checarERegistrar('acao-f', intervalo), returnsNormally);
      expect(
        () => rl.checarERegistrar('acao-f', intervalo),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('a exceção carrega o tempo restante arredondado para cima', () {
      rl.registrar('acao-g');
      try {
        rl.checarERegistrar('acao-g', intervalo);
        fail('deveria ter lançado RateLimitException');
      } on RateLimitException catch (e) {
        expect(e.segundosRestantes, greaterThan(0));
        // segundosRestantes = inSeconds + 1 (arredonda para cima): logo após
        // registrar, o restante é ~30s, então pode chegar a 31.
        expect(e.segundosRestantes, lessThanOrEqualTo(31));
        expect(e.toString(), contains('Aguarde'));
      }
    });
  });
}
