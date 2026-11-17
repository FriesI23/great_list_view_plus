import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = Directory('lib/src');
  final directives = RegExp(
    r'''^\s*(import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  List<Uri> dependencies(File file) => [
    for (final match in directives.allMatches(file.readAsStringSync()))
      match[2]!.startsWith('package:great_list_view_plus/')
          ? Directory('lib').absolute.uri.resolve(
              match[2]!.substring('package:great_list_view_plus/'.length),
            )
          : file.absolute.uri.resolve(match[2]!),
  ];

  test('source libraries do not share state through part directives', () {
    final parts = RegExp(r'^\s*part\s+', multiLine: true);
    for (final file in source.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      expect(
        parts.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('shared core has no dependency on feature implementations', () {
    expect(
      dependencies(File('lib/src/core.dart'))
          .where((uri) => uri.scheme == 'file'),
      isEmpty,
    );
  });

  test('tree and diff depend only on shared core and their own helpers', () {
    final core = File('lib/src/core.dart').absolute.uri;
    for (final directory in ['tree', 'diff']) {
      final feature = Directory('lib/src/$directory');
      for (final file in feature.listSync().whereType<File>()) {
        for (final dependency in dependencies(file)) {
          if (dependency.scheme != 'file' || dependency == core) continue;
          expect(
            dependency.path.startsWith(feature.absolute.uri.path),
            isTrue,
            reason: '${file.path} imports $dependency',
          );
        }
      }
    }
  });

  test(
    'rendering and interval engine do not depend on concrete widget factories',
    () {
      final forbidden = {
        File('lib/src/list/widgets.dart').absolute.uri,
        File('lib/src/rendering/child_manager.dart').absolute.uri,
      };
      for (final name in [
        'rendering/sliver_list',
        'rendering/sliver_multi_box_adaptor',
        'list/interval_model',
        'list/interval_manager',
        'list/intervals',
        'list/interval_list',
        'list/animation',
      ]) {
        final file = File('lib/src/$name.dart');
        expect(
          dependencies(file).where(forbidden.contains),
          isEmpty,
          reason: file.path,
        );
      }
    },
  );
}
