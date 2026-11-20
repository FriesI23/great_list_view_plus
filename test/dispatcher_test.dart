import 'package:flutter/widgets.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

bool _sameItem(int a, int b) => a == b;

bool _throwOnInvalidItem(int a, int b) {
  if (a < 0 || b < 0) {
    throw StateError('Invalid item');
  }
  return a == b;
}

void main() {
  test('large list diff uses internal workers', () async {
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
    await GreatListView.init();
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
      await workerManager.dispose();
    }
  });

  test(
    'large list diff starts workers without explicit initialization',
    () async {
      final controller = _RecordingController();
      final initial = List.generate(250, (index) => index);
      final next = [...initial, 999];
      final dispatcher = AnimatedListDiffListDispatcher<int>(
        controller: controller,
        itemBuilder: (context, value, data) => Text('Item $value'),
        currentList: initial,
        comparator: const AnimatedListDiffListComparator<int>(
          sameItem: _sameItem,
          sameContent: _sameItem,
        ),
      );
      try {
        await dispatcher
            .dispatchNewList(next)
            .timeout(const Duration(seconds: 15));
        expect(dispatcher.hasPendingTask, isFalse);
        expect(dispatcher.currentList, orderedEquals(next));
        expect(controller.notifications, ['insert:250:1']);
      } finally {
        await workerManager.dispose();
      }
    },
  );

  test(
    'a superseded background diff completes without applying updates',
    () async {
      final controller = _RecordingController();
      final initial = List.generate(250, (index) => index);
      final next = [...initial, 999];
      final dispatcher = AnimatedListDiffListDispatcher<int>(
        controller: controller,
        itemBuilder: (context, value, data) => Text('Item $value'),
        currentList: initial,
        comparator: const AnimatedListDiffListComparator<int>(
          sameItem: _sameItem,
          sameContent: _sameItem,
        ),
      );
      await GreatListView.init();
      try {
        final superseded = dispatcher.dispatchNewList([...initial, 998]);
        final latest = dispatcher.dispatchNewList(next);
        await Future.wait([superseded, latest])
            .timeout(const Duration(seconds: 15));
        expect(dispatcher.hasPendingTask, isFalse);
        expect(dispatcher.currentList, orderedEquals(next));
        expect(controller.notifications, ['insert:250:1']);
      } finally {
        await workerManager.dispose();
      }
    },
  );

  test(
    'a failed background diff reports the error and permits retry',
    () async {
      final controller = _RecordingController();
      final initial = List.generate(250, (index) => index);
      final dispatcher = AnimatedListDiffListDispatcher<int>(
        controller: controller,
        itemBuilder: (context, value, data) => Text('Item $value'),
        currentList: initial,
        comparator: const AnimatedListDiffListComparator<int>(
          sameItem: _throwOnInvalidItem,
          sameContent: _sameItem,
        ),
      );
      try {
        await expectLater(
          dispatcher
              .dispatchNewList([...initial, -1])
              .timeout(const Duration(seconds: 15)),
          throwsStateError,
        );
        expect(dispatcher.hasPendingTask, isFalse);
        expect(dispatcher.currentList, orderedEquals(initial));
        expect(controller.notifications, isEmpty);
        final next = [...initial, 999];
        await dispatcher
            .dispatchNewList(next)
            .timeout(const Duration(seconds: 15));
        expect(dispatcher.currentList, orderedEquals(next));
        expect(controller.notifications, ['insert:250:1']);
      } finally {
        await workerManager.dispose();
      }
    },
  );
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
