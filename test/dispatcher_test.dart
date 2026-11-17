import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

bool _sameItem(int a, int b) => a == b;

void main() {
  test('large list diff completes through the exported worker API', () async {
    final controller = _RecordingController();
    final initial = List.generate(300, (index) => index);
    final next = List.of(initial)
      ..removeLast()
      ..insert(2, 999);
    final dispatcher = AnimatedListDiffListDispatcher<int>(
      controller: controller,
      itemBuilder: (context, value, data) => Text('Item $value'),
      currentList: initial,
      comparator: const AnimatedListDiffListComparator<int>(
        sameItem: _sameItem,
        sameContent: _sameItem,
      ),
    );
    await Executor().warmUp(isolatesCount: 2);
    try {
      final result = dispatcher.dispatchNewList(next);
      expect(dispatcher.hasPendingTask, isTrue);
      await result.timeout(const Duration(seconds: 15));
      expect(dispatcher.hasPendingTask, isFalse);
      expect(dispatcher.currentList, orderedEquals(next));
      // Verify actual diff notifications as well as the stored result. Widget
      // animation behavior is covered separately without real isolate timing.
      expect(controller.notifications, hasLength(2));
      expect(
        controller.notifications,
        containsAll(['remove:299:1', 'insert:2:1']),
      );
    } finally {
      await Executor().dispose();
    }
  });
}

class _RecordingController extends AnimatedListController {
  final notifications = <String>[];

  @override
  void batch(VoidCallback callback) => callback();

  @override
  void notifyInsertedRange(int from, int count) {
    notifications.add('insert:$from:$count');
  }

  @override
  void notifyRemovedRange(
    int from,
    int count,
    AnimatedWidgetBuilder removeItemBuilder,
  ) {
    notifications.add('remove:$from:$count');
  }
}
