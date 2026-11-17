import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() {
  testWidgets(
    'replacing sliver types and reparenting safely rebinds a controller',
    (tester) async {
      final controller = AnimatedListController();
      final key = GlobalKey();
      Widget list({required bool fixed}) => AnimatedListView(
        key: key,
        listController: controller,
        initialItemCount: 3,
        itemExtent: fixed ? 40 : null,
        itemBuilder: (context, index, data) =>
            SizedBox(height: 40, child: Text('Row $index')),
      );
      for (final fixed in [false, true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: fixed
                ? Align(child: list(fixed: fixed))
                : Center(child: list(fixed: fixed)),
          ),
        );
        await _settle(tester);
        expect(find.text('Row 0'), findsOneWidget);
        expect(controller.computeItemBox(1), isNotNull);
        expect(
          controller.getItemVisibleSize(1),
          isA<AnimatedListItemVisibility>(),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('delegate changes rebuild cached rows and wrappers', (
    tester,
  ) async {
    final controller = AnimatedListController();
    final config = ValueNotifier<bool>(false);
    addTearDown(config.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: config,
          builder: (context, changed, _) => AnimatedListView(
            listController: controller,
            initialItemCount: 3,
            itemExtent: 40,
            morphComparator: changed ? (a, b) => a == b : null,
            itemBuilder: (context, index, data) => SizedBox(
              height: 40,
              child: Text('${changed ? 'new' : 'old'} $index'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('old 0'), findsOneWidget);
    expect(find.byType(MorphTransition), findsNothing);
    config.value = true;
    await _settle(tester);
    expect(find.text('new 0'), findsOneWidget);
    expect(find.text('old 0'), findsNothing);
    expect(find.byType(MorphTransition), findsWidgets);
    config.value = false;
    await _settle(tester);
    expect(find.byType(MorphTransition), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final fixedExtent in [false, true]) {
    group(fixedExtent ? 'fixed extent' : 'variable extent', () {
      testWidgets('manual insert, change, remove, replace, and move', (
        tester,
      ) async {
        final key = GlobalKey<_ListHarnessState>();
        await tester.pumpWidget(
          _ListHarness(key: key, fixedExtent: fixedExtent),
        );
        final state = key.currentState!;
        _expectOrder(tester, state.items);

        state.insert(2, const _Row(20));
        await tester.pump();
        var sawFadeProgress = false;
        // Insertion first resizes the space, then fades the new row in.
        for (var frame = 0; frame < 18; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          sawFadeProgress |= tester
              .widgetList<FadeTransition>(find.byType(FadeTransition))
              .any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1);
          expect(tester.takeException(), isNull);
        }
        expect(sawFadeProgress, isTrue);
        await _settle(tester);
        _expectOrder(tester, state.items);

        state.change(2, const _Row(20, 'updated'));
        await _settle(tester);
        expect(find.text('updated'), findsOneWidget);
        state.remove(2, 1);
        await _settle(tester);
        expect(find.text('updated'), findsNothing);
        _expectOrder(tester, state.items);

        state.replace(1, 2, const [_Row(30), _Row(31), _Row(32)]);
        await _settle(tester);
        _expectOrder(tester, state.items);
        state.move(1, 3, 6);
        await _settle(tester);
        _expectOrder(tester, state.items);
        expect(tester.takeException(), isNull);
      });

      testWidgets('moving range can be split by another move', (tester) async {
        final key = GlobalKey<_ListHarnessState>();
        await tester.pumpWidget(
          _ListHarness(key: key, fixedExtent: fixedExtent),
        );
        final state = key.currentState!;
        state.move(1, 5, 4);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        // Split the moving range into leading, middle, and trailing pieces.
        state.move(5, 2, 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await _settle(tester);
        _expectOrder(tester, state.items);
      });

      testWidgets('items can be removed from a moving range', (tester) async {
        final key = GlobalKey<_ListHarnessState>();
        await tester.pumpWidget(
          _ListHarness(key: key, fixedExtent: fixedExtent),
        );
        final state = key.currentState!;
        state.move(1, 5, 4);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        state.remove(5, 2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await _settle(tester);
        _expectOrder(tester, state.items);
        expect(find.text('Item 2'), findsNothing);
        expect(find.text('Item 3'), findsNothing);
      });

      testWidgets('automatic diff handles updates and moves', (tester) async {
        final key = GlobalKey<_ListHarnessState>();
        await tester.pumpWidget(
          _ListHarness(key: key, fixedExtent: fixedExtent, automatic: true),
        );
        final state = key.currentState!;
        state.update(const [_Row(8), _Row(2, 'changed'), _Row(20), _Row(0)]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        // Update again while the first diff's animations are still running.
        state.update(const [
          _Row(20),
          _Row(8),
          _Row(21),
          _Row(2, 'changed again'),
        ]);
        await _settle(tester);
        _expectOrder(tester, state.items);
        expect(find.text('changed again'), findsOneWidget);
        state.update([]);
        await _settle(tester);
        expect(find.byType(Text), findsNothing);
        state.update(const [_Row(40), _Row(41)]);
        await _settle(tester);
        _expectOrder(tester, state.items);
        expect(tester.takeException(), isNull);
      });

      for (final cancel in [false, true]) {
        testWidgets('controller reorder ${cancel ? 'cancels' : 'completes'}', (
          tester,
        ) async {
          final key = GlobalKey<_ListHarnessState>();
          await tester.pumpWidget(
            _ListHarness(key: key, fixedExtent: fixedExtent),
          );
          final state = key.currentState!;
          final original = List<_Row>.of(state.items);
          final context = tester.element(find.byKey(const ValueKey('row-1')));
          expect(state.controller.notifyStartReorder(context, 10, 10), isTrue);
          await tester.pump();
          state.controller.notifyUpdateReorder(10, 150);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          state.controller.notifyStopReorder(cancel);
          await _settle(tester);
          if (cancel) {
            expect(state.items, orderedEquals(original));
          } else {
            expect(state.items, isNot(orderedEquals(original)));
            expect(
              state.items.map((item) => item.id),
              unorderedEquals(original.map((item) => item.id)),
            );
          }
          _expectOrder(tester, state.items);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('long press gesture reorders an item', (tester) async {
        final key = GlobalKey<_ListHarnessState>();
        await tester.pumpWidget(
          _ListHarness(key: key, fixedExtent: fixedExtent),
        );
        final state = key.currentState!;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('row-1'))),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(0, 140));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await _settle(tester);
        expect(state.items.indexWhere((item) => item.id == 1), greaterThan(1));
        _expectOrder(tester, state.items);
        expect(tester.takeException(), isNull);
      });
    });
  }
}

// Variable extents are measured between animation phases. Advance the complete
// dismiss/resize/incoming sequence even when a measurement frame has no ticker.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 25; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void _expectOrder(WidgetTester tester, List<_Row> items) {
  double previousBottom = -1;
  for (final item in items) {
    final finder = find.byKey(ValueKey('row-${item.id}'));
    expect(finder, findsOneWidget);
    final rect = tester.getRect(finder);
    expect(rect.top, greaterThanOrEqualTo(previousBottom - 0.01));
    expect(rect.height, greaterThan(0));
    previousBottom = rect.bottom;
  }
  expect(tester.takeException(), isNull);
}

class _Row {
  const _Row(this.id, [this.label]);
  final int id;
  final String? label;
}

Widget _buildRow(
  BuildContext context,
  _Row item,
  AnimatedWidgetBuilderData data,
) {
  return SizedBox(
    key: data.measuring ? null : ValueKey('row-${item.id}'),
    height: 32 + (item.id % 3) * 8,
    child: Text(item.label ?? 'Item ${item.id}'),
  );
}

final _comparator = AnimatedListDiffListComparator<_Row>(
  sameItem: (a, b) => a.id == b.id,
  sameContent: (a, b) => a.label == b.label,
);

class _ListHarness extends StatefulWidget {
  const _ListHarness({
    super.key,
    required this.fixedExtent,
    this.automatic = false,
  });
  final bool fixedExtent;
  final bool automatic;

  @override
  State<_ListHarness> createState() => _ListHarnessState();
}

class _ListHarnessState extends State<_ListHarness> {
  final controller = AnimatedListController();
  List<_Row> items = List.generate(10, (index) => _Row(index));

  void update(List<_Row> next) => setState(() => items = List.of(next));

  void insert(int index, _Row item) {
    setState(() => items.insert(index, item));
    controller.notifyInsertedRange(index, 1);
  }

  void change(int index, _Row item) {
    final old = items[index];
    setState(() => items[index] = item);
    controller.notifyChangedRange(
      index,
      1,
      (context, index, data) => _buildRow(context, old, data),
    );
  }

  void remove(int from, int count) {
    final old = items.sublist(from, from + count);
    setState(() => items.removeRange(from, from + count));
    controller.notifyRemovedRange(
      from,
      count,
      (context, index, data) => _buildRow(context, old[index], data),
    );
  }

  void replace(int from, int count, List<_Row> replacement) {
    final old = items.sublist(from, from + count);
    setState(() => items.replaceRange(from, from + count, replacement));
    controller.notifyReplacedRange(
      from,
      count,
      replacement.length,
      (context, index, data) => _buildRow(context, old[index], data),
    );
  }

  void move(int from, int count, int to) {
    setState(() {
      final moved = items.sublist(from, from + count);
      items.removeRange(from, from + count);
      items.insertAll(to, moved);
    });
    controller.notifyMovedRange(from, count, to);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: widget.automatic
            ? AutomaticAnimatedListView<_Row>(
                list: items,
                listController: controller,
                comparator: _comparator,
                itemBuilder: _buildRow,
                itemExtent: widget.fixedExtent ? 40 : null,
                detectMoves: true,
                padding: EdgeInsets.zero,
              )
            : AnimatedListView(
                listController: controller,
                initialItemCount: items.length,
                itemBuilder: (context, index, data) =>
                    _buildRow(context, items[index], data),
                itemExtent: widget.fixedExtent ? 40 : null,
                reorderModel: AutomaticAnimatedListReorderModel(items),
                padding: EdgeInsets.zero,
              ),
      ),
    );
  }
}
