import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() {
  test('item visibility is a public value type', () {
    const visibility = AnimatedListItemVisibility(25, 100);
    expect(visibility.size, 25);
    expect(visibility.referredSize, 100);
    expect(visibility.percentage, 0.25);
  });

  testWidgets('single entry point exposes a standalone MorphTransition', (
    tester,
  ) async {
    final value = ValueNotifier<String>('before');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<String>(
          valueListenable: value,
          builder: (context, text, _) => Center(
            child: MorphTransition(
              duration: const Duration(milliseconds: 200),
              comparator: (a, b) => (a as Text).data == (b as Text).data,
              child: Text(text),
            ),
          ),
        ),
      ),
    );
    value.value = 'after';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('after'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('before'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single entry point builds auxiliary widgets', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ArrowButton()));
    expect(find.byType(ArrowButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'tree adapter maps nodes in both directions across its cache window',
    () {
      // A shallow tree still forces forward/backward cache traversal.
      final adapter = TreeListAdapter<int>(
        root: 0,
        parentOf: (_) => 0,
        childrenCount: (node) => node == 0 ? 12 : 0,
        childAt: (_, index) => index + 1,
        isNodeExpanded: (_) => true,
        indexOfChild: (_, node) => node - 1,
        windowSize: 3,
      );
      expect(adapter.count, 13);
      for (final index in [0, 1, 5, 11, 3, 12, 2]) {
        expect(adapter.indexToNode(index), index);
        expect(adapter.nodeToIndex(index), index);
      }
      final subtree = adapter.subTreeOf(0, true, true, true, null);
      expect(subtree.windowSize, 3);
      expect(subtree.count, 13);
      expect(subtree.indexToNode(12), 12);
    },
  );
}
