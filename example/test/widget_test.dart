import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';
import 'package:great_list_view_plus_example/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> load(
    WidgetTester tester, {
    Size size = const Size(1100, 1100),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await _settle(tester);
  }

  testWidgets('automatic diff, Morph and tabs preserve local state', (
    tester,
  ) async {
    await load(tester);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.byType(MorphTransition), findsWidgets);
    await tester.tap(find.text('Switch data'));
    await _settle(tester);
    expect(find.text('Item 1'), findsNothing);
    expect(find.text('Item 6'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('automatic-item-5'))).height,
      104,
    );
    await tester.tap(find.text('Tree'));
    await _settle(tester);
    expect(find.text('Workspace'), findsOneWidget);
    await tester.tap(find.text('List'));
    await _settle(tester);
    expect(find.text('Item 6'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await _settle(tester);
    expect(find.byType(MorphTransition), findsNothing);
    await tester.tap(find.text('Switch data'));
    await _settle(tester);
    expect(find.text('Item 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual notifications and fixed extents remain usable after switching modes',
    (tester) async {
      await load(tester);
      await _mode(tester, 'Automatic', 'Manual');
      for (final action in [
        'Insert',
        'Change',
        'Remove',
        'Replace',
        'Move range',
        'Batch',
      ]) {
        await tester.tap(find.text(action));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: action);
      }
      expect(find.text('Item 103'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await _settle(tester);
      expect(find.byType(AnimatedSliverFixedExtentList), findsOneWidget);
      await _mode(tester, 'Manual', 'Automatic');
      expect(find.text('Item 1'), findsOneWidget);
      await _mode(tester, 'Automatic', 'Manual');
      expect(find.text('Item 103'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('explicit dispatcher animates both sliver variants', (
    tester,
  ) async {
    await load(tester);
    await _mode(tester, 'Automatic', 'Sliver');
    expect(find.text('Regular sliver header'), findsOneWidget);
    await tester.tap(find.text('Dispatch new list'));
    await _settle(tester);
    expect(find.text('Item 6'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await _settle(tester);
    expect(find.byType(AnimatedSliverFixedExtentList), findsOneWidget);
    await tester.tap(find.text('Dispatch new list'));
    await _settle(tester);
    expect(find.text('Item 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scroll-to-index validates input and keeps scroll position across tabs',
    (tester) async {
      await load(tester, size: const Size(800, 700));
      await tester.enterText(find.byType(TextField), '17');
      await tester.tap(find.text('Scroll to index'));
      await _settle(tester);
      expect(find.text('Item 20'), findsOneWidget);
      final list = tester.widget<AutomaticAnimatedListView>(
        find.byWidgetPredicate((widget) => widget is AutomaticAnimatedListView),
      );
      final offset = list.controller!.offset;
      expect(offset, greaterThan(0));
      await tester.tap(find.text('Tree'));
      await _settle(tester);
      await tester.tap(find.text('List'));
      await _settle(tester);
      expect(list.controller!.offset, closeTo(offset, 0.1));
      await tester.enterText(find.byType(TextField), '999');
      await tester.tap(find.text('Scroll to index'));
      await tester.pump();
      expect(find.text('Enter an index from 0 to 17.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long-press sorting survives list switches and a new app resets it',
    (tester) async {
      await load(tester);
      final row = find.byKey(const ValueKey('automatic-item-1'));
      final gesture = await tester.startGesture(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 180));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await _settle(tester);
      expect(
        tester.getTopLeft(find.text('Item 1')).dy,
        greaterThan(tester.getTopLeft(find.text('Item 3')).dy),
      );
      await tester.tap(find.text('Switch data'));
      await _settle(tester);
      await tester.tap(find.text('Switch data'));
      await _settle(tester);
      expect(
        tester.getTopLeft(find.text('Item 1')).dy,
        greaterThan(tester.getTopLeft(find.text('Item 3')).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const App());
      await _settle(tester);
      expect(
        tester.getTopLeft(find.text('Item 1')).dy,
        lessThan(tester.getTopLeft(find.text('Item 2')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('drag handles complete, cancel and cancel on navigation', (
    tester,
  ) async {
    await load(tester);
    await _mode(tester, 'Long press', 'Drag handle');
    final row = find.byKey(const ValueKey('automatic-item-1'));
    Finder handle() =>
        find.descendant(of: row, matching: find.byIcon(Icons.drag_handle));
    var gesture = await tester.startGesture(tester.getCenter(handle()));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 170));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.cancel();
    await _settle(tester);
    expect(
      tester.getTopLeft(find.text('Item 1')).dy,
      lessThan(tester.getTopLeft(find.text('Item 2')).dy),
    );
    gesture = await tester.startGesture(tester.getCenter(handle()));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 170));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await _settle(tester);
    expect(
      tester.getTopLeft(find.text('Item 1')).dy,
      greaterThan(tester.getTopLeft(find.text('Item 3')).dy),
    );
    gesture = await tester.startGesture(tester.getCenter(handle()));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await tester.tap(find.text('Tree'));
    await gesture.up();
    await _settle(tester);
    await tester.tap(find.text('List'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  for (final plain in [false, true]) {
    testWidgets(
      '${plain ? 'plain' : 'animated'} tree expands, edits and resets',
      (tester) async {
        await load(tester);
        await tester.tap(find.text('Tree'));
        await _settle(tester);
        if (plain) await _mode(tester, 'Animated list', 'Plain ListView');
        final arrow = find.descendant(
          of: find.byKey(const ValueKey('tree-arrow-2')),
          matching: find.byType(IconButton),
        );
        await tester.tap(arrow);
        await _settle(tester);
        expect(find.text('List animations'), findsNothing);
        await tester.tap(arrow);
        await _settle(tester);
        expect(find.text('List animations'), findsOneWidget);
        await tester.tap(find.text('Flutter'));
        await tester.pump();
        await tester.tap(find.text('Add child'));
        await _settle(tester);
        expect(find.text('New node 10'), findsOneWidget);
        await tester.tap(find.text('Delete subtree'));
        await _settle(tester);
        expect(find.text('New node 10'), findsNothing);
        await tester.tap(find.text('Flutter'));
        await tester.pump();
        await tester.tap(find.text('Delete subtree'));
        await _settle(tester);
        expect(find.text('Flutter'), findsNothing);
        expect(find.text('List animations'), findsNothing);
        await tester.tap(find.text('Reset tree'));
        await _settle(tester);
        expect(find.text('Flutter'), findsOneWidget);
        expect(find.text('List animations'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('tree host switches preserve edits and expansion', (
    tester,
  ) async {
    await load(tester);
    await tester.tap(find.text('Tree'));
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('tree-arrow-2')),
        matching: find.byType(IconButton),
      ),
    );
    await _settle(tester);
    await _mode(tester, 'Animated list', 'Plain ListView');
    expect(find.text('List animations'), findsNothing);
    await tester.tap(find.text('Notes'));
    await tester.pump();
    await tester.tap(find.text('Add child'));
    await _settle(tester);
    await _mode(tester, 'Plain ListView', 'Animated list');
    expect(find.text('New node 10'), findsOneWidget);
    expect(find.text('List animations'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tree drag changes parent and cancellation preserves the tree', (
    tester,
  ) async {
    await load(tester);
    await tester.tap(find.text('Tree'));
    await _settle(tester);
    final leaf = find.text('List animations');
    final originalX = tester.getTopLeft(leaf).dx;
    var gesture = await tester.startGesture(tester.getCenter(leaf));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-24, 224));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.cancel();
    await _settle(tester);
    expect(tester.getTopLeft(leaf).dx, originalX);
    gesture = await tester.startGesture(tester.getCenter(leaf));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-24, 224));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await _settle(tester);
    expect(tester.getTopLeft(leaf).dx, originalX - 24);
    expect(
      tester.getTopLeft(leaf).dy,
      greaterThan(tester.getTopLeft(find.text('Notes')).dy),
    );
    expect(find.byKey(const ValueKey('tree-node-3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone layout and switching during an animation stay usable', (
    tester,
  ) async {
    await load(tester, size: const Size(360, 800));
    await tester.tap(find.text('Switch data'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Tree'));
    await tester.pump();
    await tester.tap(find.text('Add child'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('List'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tree'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mode(WidgetTester tester, String current, String next) async {
  await tester.tap(find.text(current).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(next).last);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 25; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}
