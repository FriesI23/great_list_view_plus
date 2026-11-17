import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';
import 'package:great_list_view_plus/other_widgets.dart';
import 'package:great_list_view_plus/ticker_mixin.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'standalone Material $brightness theme, ink, and drag surface',
      (tester) async {
        final controller = AnimatedListController();
        final items = [0, 1, 2, 3];
        final canvasColor = brightness == Brightness.light
            ? const Color(0xFFE0F0E0)
            : const Color(0xFF182818);
        var taps = 0;
        final theme = ThemeData(
          brightness: brightness,
          canvasColor: canvasColor,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(body: _list(controller, items, onTap: () => taps++)),
          ),
        );
        final row = find.byKey(const ValueKey('row-1'));
        expect(Theme.of(tester.element(row)).brightness, brightness);
        final surface = find
            .ancestor(of: row, matching: find.byType(Material))
            .first;
        final physical = find.descendant(
          of: surface,
          matching: find.byType(PhysicalModel),
        );
        expect(tester.widget<PhysicalModel>(physical).color, canvasColor);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);

        expect(
          controller.notifyStartReorder(tester.element(row), 10, 10),
          isTrue,
        );
        try {
          await tester.pump();
          controller.notifyUpdateReorder(10, 80);
          for (var frame = 0; frame < 10; frame++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          // The sliver's onstage traversal omits the active drag popup.
          expect(
            tester
                .widgetList<Material>(
                  find.byType(Material, skipOffstage: false),
                )
                .any(
                  (material) => material.elevation == kDefaultAnimatedElevation,
                ),
            isTrue,
          );
        } finally {
          controller.notifyStopReorder(true);
          await tester.pumpAndSettle();
        }
        expect(items, [0, 1, 2, 3]);
        expect(
          tester
              .widgetList<Material>(find.byType(Material, skipOffstage: false))
              .any(
                (material) => material.elevation == kDefaultAnimatedElevation,
              ),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('standalone Cupertino host supports RTL list and dragging', (
    tester,
  ) async {
    final controller = AnimatedListController();
    final items = [0, 1, 2, 3];
    await tester.pumpWidget(
      cupertino.CupertinoApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates:
            cupertino.GlobalCupertinoLocalizations.delegates,
        theme: const cupertino.CupertinoThemeData(brightness: Brightness.dark),
        home: cupertino.CupertinoPageScaffold(child: _list(controller, items)),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('row-1'));
    expect(Directionality.of(tester.element(row)), TextDirection.rtl);
    expect(controller.notifyStartReorder(tester.element(row), 10, 10), isTrue);
    await tester.pump();
    controller.notifyUpdateReorder(10, 110);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    controller.notifyStopReorder(false);
    await tester.pumpAndSettle();
    expect(items.indexOf(1), greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrow button uses the standalone Material ancestor', (
    tester,
  ) async {
    bool? expanded;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(body: ArrowButton(onTap: (value) => expanded = value)),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticker provider respects modern TickerMode values', (
    tester,
  ) async {
    final provider = _TickerProvider();
    final ticker = provider.createTicker((_) {});
    Widget host({required bool enabled, required bool forceFrames}) {
      return TickerMode(
        enabled: enabled,
        forceFrames: forceFrames,
        child: Builder(
          builder: (context) {
            provider.updateTickerMuted(context);
            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(host(enabled: false, forceFrames: true));
    expect(ticker.muted, isTrue);
    expect(ticker.forceFrames, isTrue);
    await tester.pumpWidget(host(enabled: true, forceFrames: false));
    expect(ticker.muted, isFalse);
    expect(ticker.forceFrames, isFalse);
    ticker.dispose();
    provider.dispose();
    expect(tester.takeException(), isNull);
  });
}

Widget _list(
  AnimatedListController controller,
  List<int> items, {
  VoidCallback? onTap,
}) {
  return AnimatedListView(
    listController: controller,
    initialItemCount: items.length,
    itemExtent: 40,
    padding: EdgeInsets.zero,
    reorderModel: AutomaticAnimatedListReorderModel(items),
    itemBuilder: (context, index, data) => InkWell(
      onTap: onTap,
      child: SizedBox(
        key: data.measuring ? null : ValueKey('row-${items[index]}'),
        height: 40,
        child: Text('Item ${items[index]}'),
      ),
    ),
  );
}

class _TickerProvider with TickerProviderMixin {}
