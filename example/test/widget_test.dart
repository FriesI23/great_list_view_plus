import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus_example/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('example loads and switches between lists', (tester) async {
    await tester.pumpWidget(const App());
    await _settle(tester);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 6'), findsNothing);
    await tester.tap(find.text('Item 1'));
    await _settle(tester);
    expect(find.text('Item 1'), findsNothing);
    expect(find.text('Item 6'), findsOneWidget);
    expect(find.text('Item 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Item 6'));
    await _settle(tester);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 6'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reordering survives list switches and stays local to the app', (
    tester,
  ) async {
    await tester.pumpWidget(const App());
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Item 1')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await _settle(tester);
    expect(
      tester.getTopLeft(find.text('Item 1')).dy,
      greaterThan(tester.getTopLeft(find.text('Item 3')).dy),
    );
    await tester.tap(find.text('Item 1'));
    await _settle(tester);
    await tester.tap(find.text('Item 6'));
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
  });
}

// Variable extents can insert ticker-free measurement frames between phases.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 25; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}
