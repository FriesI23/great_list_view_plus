/// Interval collection updates, followed by their intrusive linked-list storage.
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../core.dart';
import 'interval_model.dart';
import 'intervals.dart';

typedef DistributeNotificationCallback = void Function(
  ListInterval interval,
  IntervalList list,
  int removeCount,
  int insertCount,
  int leading,
  int trailing,
  AnimatedWidgetBuilder? offListItemBuilder,
  int offListItemBuilderOffset,
  Object? params,
);

/// This class handles all changes to the list view by breaking up the entire list as a
/// list of contigous intervals, each with its own meaning.
///
/// This class is a linked list and all the intervals are its nodes.
class IntervalList extends NodeLinkedList<ListInterval>
    implements Iterable<ListInterval> {
  bool _disposed = false;

  bool changed = false;

  final IntervalCoordinator manager;

  PopUpList? popUpList;

  SubListHolderInterval? holder;

  ListInterval? _leftMostDirtyInterval;

  //

  IntervalList(this.manager);

  IntervalList.normal(this.manager, int initialCount) {
    if (initialCount > 0) {
      newContent(initialCount, true);
    }
  }

  /// It returns `true` if there is at least one a dirty interval linked to this list.
  bool get isDirty => _leftMostDirtyInterval != null;

  /// Total count of the items to be built in the list view.
  int get buildCount => isEmpty ? 0 : last.nextBuildOffset;

  /// Total count of the underlying list items.
  int get itemCount => isEmpty ? 0 : last.nextItemOffset;

  /// SUm of the average count of all intervals.
  double get averageCount => fold<double>(0.0, (pv, e) => pv + e.averageCount);

  /// Owns invalidation of offsets across the linked interval collection.
  void invalidateFrom(ListInterval first) {
    if (first.isDirty) return;
    _leftMostDirtyInterval = first;
    ListInterval? interval = first;
    do {
      interval!.invalidateOffsets();
      interval = interval.next;
    } while (interval != null && !interval.isDirty);
  }

  /// Validates offsets in order, so nodes never write collection bookkeeping.
  void validateThrough(ListInterval target) {
    if (!target.isDirty) return;
    assert(_leftMostDirtyInterval != null);
    var interval = _leftMostDirtyInterval;
    final previous = interval!.previous;
    var buildOffset = previous == null ? 0 : previous.nextBuildOffset;
    var itemOffset = previous == null ? 0 : previous.nextItemOffset;
    do {
      final next = interval!.next;
      interval.cacheOffsets(buildOffset, itemOffset);
      _leftMostDirtyInterval = next;
      if (interval == target) break;
      buildOffset += interval.buildCount;
      itemOffset += interval.itemCount;
      interval = next;
    } while (interval != null);
    assert(!target.isDirty);
  }

  //
  // List manipulation
  //

  void remove(
    Iterable<ListInterval> intervals, {
    IntervalUpdateCallback? updateCallback,
    bool dispose = true,
  }) {
    assert(_debugAssertNotDisposed());
    assert(debugAssertIntervalsConsistency(intervals));

    final next = intervals.last.next;
    final prev = intervals.first.previous;

    final index = intervals.first.buildOffset;
    final oldBuildCount = intervals.buildCount;

    if (prev == null || !prev.isDirty) {
      next?.invalidate();
      _leftMostDirtyInterval = next;
    }

    for (var i in intervals) {
      i.unlink();
      if (dispose) i.dispose();
    }

    holder?.onChanged();

    updateCallback?.call(
      this,
      index + (holder?.parentBuildOffset ?? 0),
      oldBuildCount,
      0,
    );

    changed = true;

    assert(debugDirtyConsistency());
  }

  void replace(
    Iterable<ListInterval> oldIntervals,
    Iterable<ListInterval> newIntervals, {
    IntervalUpdateCallback? updateCallback,
    IntervalList? outSubList,
    VoidCallback? intermediateCallback,
  }) {
    assert(_debugAssertNotDisposed());
    assert(debugAssertIntervalsConsistency(oldIntervals));

    if (newIntervals.isEmpty) {
      remove(oldIntervals, updateCallback: updateCallback);
      return;
    }

    var oldBuildCount = oldIntervals.buildCount;

    intermediateCallback?.call();

    var newBuildCount = newIntervals.buildCount;

    final firstNewInterval = newIntervals.first;
    final secondNewInterval = newIntervals.skip(1).firstOrNull;

    if (newIntervals is IntervalList) {
      newIntervals = newIntervals.toList();
    }

    for (var i in newIntervals) {
      assert(!oldIntervals.contains(i));
      i.list?.remove(i.iterable(), dispose: false);
      i.invalidateOffsets();
    }

    final next = oldIntervals.last.next;
    final prev = oldIntervals.first.previous;
    if (prev != null) {
      if (!prev.isDirty) {
        next?.invalidate();
        _leftMostDirtyInterval = firstNewInterval;
      }
    } else {
      firstNewInterval.cacheOffsets(0, 0);
      next?.invalidate();
      if (newIntervals.singleOrNull != null) {
        _leftMostDirtyInterval = next;
      } else {
        _leftMostDirtyInterval = secondNewInterval;
      }
    }

    for (final i in newIntervals) {
      oldIntervals.first.insertBefore(i);
    }
    for (var i in oldIntervals) {
      i.unlink();
      outSubList == null ? i.dispose() : outSubList.appendNode(i);
    }

    if (outSubList != null) {
      assert(outSubList.isNotEmpty);
      outSubList._invalidateAllOffsets();
    }

    holder?.onChanged();

    assert(debugDirtyConsistency());

    updateCallback?.call(
      this,
      firstNewInterval.actualBuildOffset,
      oldBuildCount,
      newBuildCount,
    );

    changed = true;
  }

  void insertAfter(
    ListInterval interval,
    Iterable<ListInterval> newIntervals, {
    IntervalUpdateCallback? updateCallback,
  }) {
    assert(_debugAssertNotDisposed());
    assert(interval.list == this);

    if (newIntervals.isEmpty) return;

    var newBuildCount = newIntervals.buildCount;

    final firstNewInterval = newIntervals.first;
    if (!interval.isDirty) {
      interval.next?.invalidate();
      _leftMostDirtyInterval = firstNewInterval;
    }

    var next = interval;
    for (final i in newIntervals) {
      i.list?.remove(i.iterable(), dispose: false);
      i.invalidateOffsets();
      next.insertAfter(i);
      next = i;
    }

    holder?.onChanged();

    assert(debugDirtyConsistency());

    updateCallback?.call(
      this,
      firstNewInterval.actualBuildOffset,
      0,
      newBuildCount,
    );

    changed = true;
  }

  void insertBefore(
    ListInterval interval,
    Iterable<ListInterval> newIntervals, {
    IntervalUpdateCallback? updateCallback,
  }) {
    assert(_debugAssertNotDisposed());
    assert(interval.list == this);

    if (newIntervals.isEmpty) return;

    var newBuildCount = newIntervals.buildCount;

    final firstNewInterval = newIntervals.first;

    for (final i in newIntervals) {
      i.list?.remove(i.iterable(), dispose: false);
      i.invalidateOffsets();
    }

    interval.invalidate();
    if (!(interval.previous?.isDirty ?? false)) {
      _leftMostDirtyInterval = firstNewInterval;
    }

    for (final i in newIntervals) {
      interval.insertBefore(i);
    }

    holder?.onChanged();

    assert(debugDirtyConsistency());

    updateCallback?.call(
      this,
      firstNewInterval.actualBuildOffset,
      0,
      newBuildCount,
    );

    changed = true;
  }

  void split(
    int leading,
    int trailing,
    IntervalList? leftSubList,
    IntervalList? middleSubList,
    IntervalList? rightSubList,
  ) {
    assert(_debugAssertNotDisposed());
    final middleItemCount = itemCount - leading - trailing;
    distributeNotification(leading, middleItemCount, middleItemCount, null, 0, (
      interval,
      list,
      count,
      _,
      leading,
      trailing,
      _,
      _,
      _,
    ) {
      assert(interval is! SubListInterval);
      final result = interval.split(leading, trailing);
      manager.performSplit(interval, result);
    });

    final middle = leading + middleItemCount;
    var ic = 0;
    ListInterval? i = first;
    while (i != null) {
      var next = i.next;
      i.unlink();
      if (ic < leading) {
        leftSubList!.appendNode(i);
      } else if (ic < middle) {
        middleSubList!.appendNode(i);
      } else {
        rightSubList!.appendNode(i);
      }
      ic += i.itemCount;
      i = next;
    }

    middleSubList?._invalidateAllOffsets();
    rightSubList?._invalidateAllOffsets();

    assert(isEmpty);

    changed = true;
  }

  void newContent(int count, [bool spawned = false]) {
    assert(_debugAssertNotDisposed());
    assert(isEmpty && count > 0);
    final interval = spawned
        ? NormalInterval.completed(count)
        : ReadyToResizingSpawnedInterval(count);
    interval.cacheOffsets(0, 0);
    appendNode(interval);
  }

  //

  void distributeNotification(
    int from,
    int removeCount,
    int insertCount,
    AnimatedWidgetBuilder? offListItemBuilder,
    int offListBuilderOffset,
    DistributeNotificationCallback callback, {
    Object? params,
  }) {
    assert(_debugAssertNotDisposed());
    ListInterval? interval = first;
    ListInterval? nextInterval;
    var ifrom = 0, ito = 0, mapperDelta = 0;

    final checkBorder = removeCount == 0;

    for (; interval != null; interval = nextInterval) {
      nextInterval = interval.next;

      final to = from + removeCount;
      assert(ifrom == interval.itemOffset + mapperDelta);
      final ic = interval.itemCount;
      ito = ifrom + ic;

      assert(from >= ifrom);
      if (from <= ito) {
        final leading = from - ifrom;
        if (to <= ito) {
          final trailing = ito - to;
          callback(
            interval,
            this,
            removeCount,
            insertCount,
            leading,
            trailing,
            offListItemBuilder,
            offListBuilderOffset,
            params,
          );
          return;
        } else {
          assert(!checkBorder);
          final rem = ito - from;
          final ins = math.min(rem, insertCount);
          callback(
            interval,
            this,
            rem,
            ins,
            leading,
            0,
            offListItemBuilder,
            offListBuilderOffset,
            params,
          );
          ifrom = from + ins;
          from = ito + ins - rem;
          offListBuilderOffset += rem;
          insertCount -= ins;
          removeCount -= rem;
        }
      } else {
        ifrom += ic;
      }
    }
    throw Exception('this point should never have been reached');
  }

  ListInterval intervalAtBuildIndex(int buildIndex) {
    assert(_debugAssertNotDisposed());
    var buildOffset = 0;
    ListInterval? interval, nextInterval;
    for (interval = first; interval != null; interval = nextInterval) {
      nextInterval = interval.next;
      if (buildIndex < interval.buildCount + buildOffset) {
        return interval;
      }
      buildOffset += interval.buildCount;
    }
    throw Exception('this point should never have been reached');
  }

  ListInterval intervalAtItemIndex(int listIndex) {
    assert(_debugAssertNotDisposed());
    var itemOffset = 0;
    ListInterval? interval, nextInterval;
    for (interval = first; interval != null; interval = nextInterval) {
      nextInterval = interval.next;
      if (listIndex < interval.itemCount + itemOffset) {
        return interval;
      }
      itemOffset += interval.itemCount;
    }
    throw Exception('this point should never have been reached');
  }

  /// The child manager invokes this method in order to retrieve the [Widget]
  /// to be built at the [buildIndex].
  Widget build(BuildContext context, int buildIndex, bool measureOnly) {
    assert(_debugAssertNotDisposed());
    final interval = intervalAtBuildIndex(buildIndex);
    return interval.buildWidget(
      manager.interface,
      context,
      buildIndex - interval.buildOffset,
      measureOnly,
    );
  }

  void validate() {
    assert(_debugAssertNotDisposed());
    _leftMostDirtyInterval?.validate();
  }

  void _invalidateAllOffsets() {
    forEach((i) => i.invalidateOffsets());
    _leftMostDirtyInterval = firstOrNull;
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    final l = toList();
    for (var i in l) {
      i
        ..unlink()
        ..dispose();
    }
    popUpList = null;
    holder = null;
    _leftMostDirtyInterval = null;
    _disposed = true;
    assert(isEmpty);
  }

  @override
  String toString() => '[${join(', ')}]';

  String toShortString() =>
      '[${map<String>((i) => i.toShortString()).join(', ')}]';

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_disposed) {
        throw FlutterError(
          'A $runtimeType was used after being disposed.\n'
          'Once you have called dispose() on a $runtimeType, it can no longer be used.',
        );
      }
      return true;
    }());
    return true;
  }

  bool debugAssertIntervalsConsistency(Iterable<ListInterval> intervals) {
    assert(() {
      if (intervals.isEmpty) return false;
      ListInterval? prev;
      for (final i in intervals) {
        if (!i.debugAssertAttachedToList()) return false;
        if (i.list != this) return false;
        if (prev != null) {
          if (i.previous != prev) return false;
        }
        prev = i;
      }
      return true;
    }());
    return true;
  }

  bool debugDirtyConsistency() {
    assert(() {
      var buildOffset = 0;
      var itemOffset = 0;
      ListInterval? interval;
      for (
        interval = firstOrNull;
        interval != null && interval != _leftMostDirtyInterval;
        interval = interval.next
      ) {
        if (interval.isDirty) return false;
        if (interval.buildOffset != buildOffset ||
            interval.itemOffset != itemOffset) {
          return false;
        }
        buildOffset += interval.buildCount;
        itemOffset += interval.itemCount;
      }
      if (_leftMostDirtyInterval != null) {
        if (interval == null) return false;
        do {
          if (!interval!.isDirty) return false;
          interval = interval.next;
        } while (interval != null);
      }
      return true;
    }());
    return true;
  }

  void addUpdate(
    int index,
    int oldBuildCount,
    int newBuildCount, {
    IntervalUpdateFlags flags = const IntervalUpdateFlags(),
  }) {
    manager.addUpdate(
      index,
      oldBuildCount,
      newBuildCount,
      popUpList: popUpList,
      flags: flags,
    );
  }
}

extension IterableIntervalCounts on Iterable<ListInterval> {
  int get buildCount => fold<int>(0, (pv, i) => pv + i.buildCount);

  Iterable<ListInterval> get expandedIntervals sync* {
    for (final i in this) {
      if (i is ReadyToMoveInterval) {
        yield* i.subList.expandedIntervals;
      } else {
        yield i;
      }
    }
  }
}

class LinkedNode<T extends LinkedNode<T>> with _NodePointers<T> {
  NodeLinkedList<T>? _list;

  NodeLinkedList<T>? get list => _list;

  T? get next => (_list == null || _next!._next == null) ? null : (_next! as T);

  T? get previous =>
      (_list == null || _prev!._prev == null) ? null : (_prev! as T);

  void unlink() {
    assert(_list != null);
    _prev!._next = _next;
    _next!._prev = _prev;
    _next = null;
    _prev = null;
    _list = null;
  }

  void insertAfter(LinkedNode<T> newNode) {
    assert(newNode._list == null);
    final n = _next!;
    newNode._next = n;
    newNode._prev = this;
    _next = newNode;
    n._prev = newNode;
    newNode._list = _list;
  }

  void insertBefore(LinkedNode<T> newNode) {
    assert(newNode._list == null);
    final p = _prev!;
    newNode._next = this;
    newNode._prev = p;
    _prev = newNode;
    p._next = newNode;
    newNode._list = _list;
  }
}

class NodeLinkedList<T extends LinkedNode<T>> extends Iterable<T> {
  final _Head<T> _head = _Head<T>();
  final _Tail<T> _tail = _Tail<T>();

  NodeLinkedList() {
    _head._next = _tail;
    _tail._prev = _head;
  }

  @override
  String toString() {
    return "(${join(", ")})";
  }

  void appendNode(LinkedNode<T> newNode) {
    assert(newNode._list == null);
    final p = _tail._prev;
    p!._next = newNode;
    newNode._next = _tail;
    newNode._prev = p;
    _tail._prev = newNode;
    newNode._list = this;
  }

  @override
  Iterator<T> get iterator => _LinkedListIterator<T>(this);
}

class _LinkedListIterator<T extends LinkedNode<T>> implements Iterator<T> {
  T? _current;
  _NodePointers<T>? _next;

  _LinkedListIterator(NodeLinkedList<T> list) : _next = list._head._next;

  @override
  T get current => _current as T;

  @override
  bool moveNext() {
    if (_next!._next == null) return false;
    final nn = _next!._next;
    _current = _next as T;
    _next = nn;
    return true;
  }
}

mixin class _NodePointers<T> {
  _NodePointers<T>? _next, _prev;
}

class _Head<T> extends _NodePointers<T> {
  @override
  String toString() => 'HEAD';
}

class _Tail<T> extends _NodePointers<T> {
  @override
  String toString() => 'TAIL';
}
