import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus/great_list_view.dart' as legacy;
import 'package:great_list_view_plus/great_list_view_plus.dart';
import 'package:great_list_view_plus/other_widgets.dart';
import 'package:great_list_view_plus/ticker_mixin.dart';
import 'package:great_list_view_plus/tree_list_adapter.dart';

void main() {
  test(
    'old and new entry points expose identical public types and worker API',
    () {
      expect(legacy.AnimatedListController(), isA<AnimatedListController>());
      expect(identical(legacy.Executor(), Executor()), isTrue);
      expect(_TickerProvider(), isA<TickerProvider>());
      _TickerProvider().dispose();
    },
  );

  testWidgets('auxiliary widget entry point builds', (tester) async {
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

class _TickerProvider with TickerProviderMixin {}
