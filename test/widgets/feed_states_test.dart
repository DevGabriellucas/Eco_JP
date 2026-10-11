import 'package:eco_jp/widgets/feed_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FeedEmptyState', () {
    testWidgets('sem filtros mostra mensagem de "ainda não há denúncias"', (
      tester,
    ) async {
      await tester.pumpWidget(_envolver(const FeedEmptyState()));
      expect(find.text('Nenhuma denúncia por aqui ainda'), findsOneWidget);
      // Sem filtros, não deve existir o botão de limpar.
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('com filtros ativos mostra estado de "nenhum resultado"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          FeedEmptyState(hasActiveFilters: true, onClearFilters: () {}),
        ),
      );
      expect(find.text('Nenhum resultado encontrado'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsOneWidget);
    });

    testWidgets('tocar em "Limpar filtros" dispara o callback', (tester) async {
      var chamado = false;
      await tester.pumpWidget(
        _envolver(
          FeedEmptyState(
            hasActiveFilters: true,
            onClearFilters: () => chamado = true,
          ),
        ),
      );
      await tester.tap(find.text('Limpar filtros'));
      expect(chamado, isTrue);
    });

    testWidgets('com filtros mas sem callback, o botão não aparece', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(const FeedEmptyState(hasActiveFilters: true)),
      );
      expect(find.text('Limpar filtros'), findsNothing);
    });
  });

  group('FeedErrorState', () {
    testWidgets('mostra mensagem de erro e botão de tentar novamente', (
      tester,
    ) async {
      await tester.pumpWidget(_envolver(FeedErrorState(onRetry: () {})));
      expect(find.text('Não foi possível carregar o feed'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('tocar em "Tentar novamente" dispara onRetry', (tester) async {
      var tentou = false;
      await tester.pumpWidget(
        _envolver(FeedErrorState(onRetry: () => tentou = true)),
      );
      await tester.tap(find.text('Tentar novamente'));
      expect(tentou, isTrue);
    });
  });

  group('FeedSkeleton', () {
    testWidgets('renderiza a quantidade pedida de cards fantasma', (
      tester,
    ) async {
      // Viewport alto para o ListView (lazy) montar todos os cards pedidos.
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_envolver(const FeedSkeleton(itemCount: 3)));
      // Pulso é animado; um único pump basta para montar a árvore.
      await tester.pump();
      expect(find.byType(CircleAvatar), findsNWidgets(3));
    });
  });
}
