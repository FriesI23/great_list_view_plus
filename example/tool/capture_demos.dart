import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus_example/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  _RecordingBinding();
  setUpAll(_loadFonts);
  for (final scenario in ['list', 'tree']) {
    testWidgets('record $scenario', (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final allowBanner = WidgetsApp.debugAllowBannerOverride;
      WidgetsApp.debugAllowBannerOverride = false;
      addTearDown(() => WidgetsApp.debugAllowBannerOverride = allowBanner);
      final recorder = _Recorder(tester, scenario);
      await recorder.prepare();
      await tester.pumpWidget(
        RepaintBoundary(key: recorder.surfaceKey, child: const App()),
      );
      await tester.pumpAndSettle();
      if (scenario == 'list') {
        await _recordList(recorder);
      } else {
        await _recordTree(recorder);
      }
      await recorder.frames(12);
      expect(tester.takeException(), isNull);
    });
  }
}

// Render real elevation shadows instead of the test binding's solid outlines.
class _RecordingBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> _recordList(_Recorder recorder) async {
  final tester = recorder.tester;
  await recorder.frames(12);
  await recorder.tap(find.text('Switch data'), frames: 18);
  expect(find.text('Item 6'), findsOneWidget);
  await recorder.tap(find.byType(Switch).first);
  await recorder.tap(find.text('Switch data'), frames: 18);
  await recorder.tap(find.byType(Switch).first);
  await recorder.choose('Long press', 'Drag handle');
  final row = find.byKey(const ValueKey('automatic-item-1'));
  await recorder.drag(
    find.descendant(of: row, matching: find.byIcon(Icons.drag_handle)),
    const Offset(0, 180),
  );
  expect(
    tester.getTopLeft(find.text('Item 1')).dy,
    greaterThan(tester.getTopLeft(find.text('Item 3')).dy),
  );
  await recorder.choose('Automatic', 'Manual');
  for (final action in [
    'Insert',
    'Change',
    'Remove',
    'Replace',
    'Move range',
    'Batch',
  ]) {
    await recorder.tap(find.text(action));
  }
  await recorder.choose('Manual', 'Sliver');
  await recorder.tap(find.text('Dispatch new list'), frames: 18);
  await recorder.tap(find.byType(Switch).first, frames: 18);
  await recorder.tap(find.text('Dispatch new list'), frames: 18);
}

Future<void> _recordTree(_Recorder recorder) async {
  final tester = recorder.tester;
  await recorder.tap(find.text('Tree'));
  final arrow = find.descendant(
    of: find.byKey(const ValueKey('tree-arrow-2')),
    matching: find.byType(IconButton),
  );
  await recorder.tap(arrow, frames: 16);
  await recorder.tap(arrow, frames: 16);
  await recorder.tap(find.text('Notes'), frames: 6);
  await recorder.tap(find.text('Add child'), frames: 16);
  expect(find.text('New node 10'), findsOneWidget);
  await recorder.tap(find.text('Delete subtree'), frames: 16);
  expect(find.text('New node 10'), findsNothing);
  final leaf = find.text('List animations');
  final originalX = tester.getTopLeft(leaf).dx;
  await recorder.drag(leaf, const Offset(-24, 224), longPress: true);
  expect(tester.getTopLeft(leaf).dx, originalX - 24);
  expect(
    tester.getTopLeft(leaf).dy,
    greaterThan(tester.getTopLeft(find.text('Notes')).dy),
  );
  await recorder.choose('Animated list', 'Plain ListView');
  await recorder.tap(find.text('Flutter'), frames: 6);
  await recorder.tap(find.text('Add child'), frames: 16);
  await recorder.choose('Plain ListView', 'Animated list');
  expect(find.text('New node 11'), findsOneWidget);
  await recorder.tap(find.text('Reset tree'), frames: 16);
  expect(find.text('New node 11'), findsNothing);
}

class _Recorder {
  _Recorder(this.tester, String scenario)
    : directory = Directory('../build/example-demos/$scenario');

  final WidgetTester tester;
  final Directory directory;
  final surfaceKey = GlobalKey();
  int _frame = 0;

  Future<void> prepare() async {
    await tester.runAsync(() async {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
      directory.createSync(recursive: true);
    });
  }

  Future<void> tap(Finder target, {int frames = 12}) async {
    await tester.tap(target);
    await this.frames(frames);
  }

  Future<void> choose(String current, String next) async {
    await tap(find.text(current).first, frames: 4);
    await tap(find.text(next).last, frames: 12);
  }

  Future<void> drag(
    Finder target,
    Offset offset, {
    bool longPress = false,
  }) async {
    final origin = tester.getCenter(target);
    final gesture = await tester.startGesture(origin);
    if (longPress) {
      await frames(8);
    } else {
      await gesture.moveBy(const Offset(0, 20));
      await frames(1);
    }
    for (var step = 1; step <= 16; step++) {
      await gesture.moveTo(origin + offset * (step / 16));
      await frames(1);
    }
    await frames(4);
    await gesture.up();
    await frames(18);
  }

  Future<void> frames(int count) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 83));
      _useRecordingFont(surfaceKey.currentContext!.findRenderObject()!);
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            surfaceKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 0.8);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/${(_frame++).toString().padLeft(4, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }
}

// Test fonts default to Ahem. Load real app fonts for readable recordings.
Future<void> _loadFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font
        in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final sdk = Uri.parse(config['flutterRoot'] as String).toFilePath();
  final loader = FontLoader('Roboto');
  for (final font
      in Directory('$sdk/bin/cache/artifacts/material_fonts')
          .listSync()
          .whereType<File>()
          .where((file) => file.uri.pathSegments.last.startsWith('Roboto-'))) {
    final bytes = font.readAsBytes().then(ByteData.sublistView);
    loader.addFont(bytes);
  }
  await loader.load();
}

// Unthemed labels otherwise fall back to Ahem inside flutter_tester.
// Keep explicit fonts (including icon fonts) and normalize only that fallback.
void _useRecordingFont(RenderObject object) {
  if (object is RenderParagraph && object.text.style?.fontFamily == null) {
    object.text = TextSpan(
      style: const TextStyle(fontFamily: 'Roboto'),
      children: [object.text],
    );
  }
  object.visitChildren(_useRecordingFont);
}
