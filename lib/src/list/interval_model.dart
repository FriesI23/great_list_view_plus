/// Shared values, notifications and host protocols for the list interval engine.
///
/// Measurement values and update records describe its state; host/coordinator
/// contracts connect it to rendering. Popup lists and drag geometry describe
/// transient state, followed by helpers for composing outgoing item builders.
library;

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core.dart';
import 'delegates.dart';
import 'interval_list.dart';
import 'intervals.dart';

typedef IntervalBuilder = Widget Function(
  BuildContext context,
  int index,
  AnimatedWidgetBuilderData data,
);

typedef IntervalUpdateCallback = void Function(
  IntervalList list,
  int index,
  int oldBuildCount,
  int newBuildCount,
);

typedef UpdateToOffsetCallback = double Function(
  int index,
  int count,
  double remainingTime,
);

class ItemMeasure {
  final double value;
  final bool estimated;

  static const ItemMeasure zero = ItemMeasure(0, false);

  const ItemMeasure(this.value, [this.estimated = false]);

  ItemMeasure operator +(ItemMeasure m) =>
      ItemMeasure(value + m.value, estimated || m.estimated);

  ItemMeasure operator -(ItemMeasure m) =>
      ItemMeasure(value - m.value, estimated || m.estimated);

  @override
  String toString() => estimated ? '≈$value' : '$value';
}

class ItemSizeRange {
  final int from, to;
  final double size;

  int get count => to - from;

  const ItemSizeRange(this.from, this.to, this.size);

  @override
  String toString() => 'from=$from, to=$to, size=$size';
}

class IntervalUpdateFlags {
  const IntervalUpdateFlags([int flags = 0])
    : _value = flags,
      assert(
        (flags &
                ~(clearLayoutOffset |
                    keepFirstLayoutOffset |
                    popupPick |
                    popupDrop |
                    discardElement)) ==
            0,
      ),
      assert(
        (flags & (clearLayoutOffset | keepFirstLayoutOffset)) !=
            keepFirstLayoutOffset,
      ),
      assert((flags & (popupPick | popupDrop)) != (popupPick | popupDrop));

  final int _value;

  static const int clearLayoutOffset = 1 << 0;
  static const int keepFirstLayoutOffset = 1 << 1;
  static const int discardElement = 1 << 2;
  static const int popupPick = 1 << 3;
  static const int popupDrop = 1 << 4;

  int get value => _value;

  bool get hasClearLayoutOffset =>
      (_value & clearLayoutOffset) == clearLayoutOffset;
  bool get hasKeepFirstLayoutOffset =>
      (_value & keepFirstLayoutOffset) == keepFirstLayoutOffset;
  bool get hasDiscardElement => (_value & discardElement) == discardElement;
  bool get hasPopupPick => (_value & popupPick) == popupPick;
  bool get hasPopupDrop => (_value & popupDrop) == popupDrop;

  @override
  String toString() => [
    if (hasClearLayoutOffset) 'clearLayoutOffset',
    if (hasKeepFirstLayoutOffset) 'keepFirstLayoutOffset',
    if (hasDiscardElement) 'discardElement',
    if (hasPopupPick) 'popupPick',
    if (hasPopupDrop) 'popupDrop',
  ].join(', ');
}

class IntervalUpdate {
  IntervalUpdate(
    this.index,
    this.oldBuildCount,
    this.newBuildCount, [
    this.flags = const IntervalUpdateFlags(),
    this.popUpList,
    this.toPopUpList,
  ]) : assert(index >= 0 && oldBuildCount >= 0 && newBuildCount >= 0),
       assert(!flags.hasPopupPick || toPopUpList != null),
       assert(!flags.hasPopupDrop || popUpList != null);

  final int index;
  final int oldBuildCount, newBuildCount;
  final IntervalUpdateFlags flags;
  final PopUpList? popUpList, toPopUpList;

  int get skipCount => newBuildCount - oldBuildCount;

  @override
  String toString() =>
      'U(i: $index, obc: $oldBuildCount, nbc: $newBuildCount, fl: $flags, pl: ${popUpList?.debugId}, tpl: ${toPopUpList?.debugId})';
}

abstract interface class ListIntervalHost implements BuildContext {
  AnimatedSliverChildDelegate get delegate;
  bool get isHorizontal;
  Widget wrapWidget(
    AnimatedWidgetBuilder builder,
    int index,
    AnimatedWidgetBuilderData data, [
    bool map = true,
  ]);
  void resizingIntervalUpdated(AnimatedSpaceInterval interval, double delta);
  Future<ItemMeasure> measureItems(
    Cancelled? cancelled,
    int count,
    IndexedWidgetBuilder builder, [
    double startingSize = 0,
    int startingCount = 0,
  ]);
  double measureItem(Widget widget);
  void markNeedsBuild();
  void markNeedsLayout();
  ItemSizeRange? getItemSizesFromSliverList(int buildFrom, int buildTo);
  ItemMeasure estimateLayoutOffset(
    int buildIndex,
    int childCount, {
    double? time,
    MovingPopUpList? popUpList,
  });
  void reorderCancel();
}

/// Coordinator operations used by interval collections and states.
abstract interface class IntervalCoordinator {
  ListIntervalHost get interface;
  ReorderLayoutData? get reorderLayoutData;
  void onResizeTick(AnimatedSpaceInterval interval, double delta);
  void onMovingTick();
  void performSplit(ListInterval interval, SplitResult result);
  void addUpdate(
    int index,
    int oldBuildCount,
    int newBuildCount, {
    IntervalUpdateFlags flags = const IntervalUpdateFlags(),
    PopUpList? popUpList,
    PopUpList? toPopUpList,
  });
}

abstract class PopUpList {
  double? currentScrollOffset;

  int get popUpBuildCount;

  static var counter = 0;
  final int debugId;

  PopUpList() : debugId = counter + 1 {
    counter++;
  }

  Widget buildPopUp(BuildContext context, int index, bool measureOnly);

  void Function(double Function(int, int, double) callback)? updateScrollOffset;

  Iterable<ListInterval> get intervals;

  int get lastBuildCount;
  set lastBuildCount(int v);

  bool debugUpdateConsistency(List<IntervalUpdate> updates) {
    assert(() {
      final delta = updates
          .where((upd) => upd.popUpList == this && !upd.flags.hasPopupDrop)
          .fold<int>(
            0,
            (pv, upd) => pv + upd.newBuildCount - upd.oldBuildCount,
          );
      return lastBuildCount + delta == popUpBuildCount;
    }());
    return true;
  }
}

class ReorderPopUpList extends PopUpList {
  final IntervalList intervalList;

  ReorderPopUpList(this.intervalList) {
    intervalList.popUpList = this;
  }

  @override
  Widget buildPopUp(BuildContext context, int index, bool measureOnly) {
    return intervalList.build(context, index, measureOnly);
  }

  @override
  int get popUpBuildCount => intervalList.buildCount;

  @override
  Iterable<ListInterval> get intervals => intervalList;

  @override
  var lastBuildCount = 1;

  @override
  String toString() => 'PopUp[$debugId] reorder';
}

class MovingPopUpList extends PopUpList {
  List<IntervalList> subLists = [];

  @override
  int get popUpBuildCount =>
      subLists.fold<int>(0, (pv, e) => pv + e.buildCount);

  @override
  Widget buildPopUp(BuildContext context, int index, bool measureOnly) {
    for (final sl in subLists) {
      if (index < sl.buildCount) {
        return sl.build(context, index, measureOnly);
      }
      index -= sl.buildCount;
    }
    throw Exception('this point should never have been reached');
  }

  @override
  Iterable<ListInterval> get intervals => subLists.expand((e) => e);

  @override
  var lastBuildCount = 0;

  @override
  String toString() => 'PopUp[$debugId] subLists=$subLists';

  int buildIndexOf(IntervalList subList) {
    assert(subLists.contains(subList));
    var o = 0;
    for (final sl in subLists) {
      if (sl == subList) break;
      o += sl.buildCount;
    }
    return o;
  }
}

const _kReorderingScrollSpeed = 10.0;

class ReorderLayoutData {
  var mainAxisLocalOffset = 0.0;
  var crossAxisLocalOffset = 0.0;

  var originMainAxisOffset = 0.0;
  var originCrossAxisOffset = 0.0;

  var originScrollOffset = 0.0;

  var lastMainAxisOffset = 0.0;

  var itemSize = 0.0;

  Object? slot;

  late ReorderOpeningInterval openingInterval;

  ReorderLayoutData(
    SliverConstraints constraints,
    double layoutOffset,
    double dx,
    double dy,
    this.itemSize,
    this.slot,
  ) {
    update(constraints, dx, dy);

    originCrossAxisOffset = crossAxisLocalOffset;

    originScrollOffset = constraints.scrollOffset;

    lastMainAxisOffset = layoutOffset;
    originMainAxisOffset = layoutOffset - mainAxisLocalOffset;
  }

  double get currentMainAxisOffset => popUpList!.currentScrollOffset!;

  set currentMainAxisOffset(double v) => popUpList!.currentScrollOffset = v;

  ReorderPopUpList? get popUpList => openingInterval.popUpList;

  int get pickedListIndex => openingInterval.holder.itemOffset;

  int get dropListIndex {
    var offset = openingInterval.itemOffset;
    if (pickedListIndex < offset) offset--;
    return offset;
  }

  double get crossAxisDelta => crossAxisLocalOffset - originCrossAxisOffset;

  void update(SliverConstraints constraints, double dx, double dy) {
    switch (applyGrowthDirectionToAxisDirection(
      constraints.axisDirection,
      constraints.growthDirection,
    )) {
      case AxisDirection.up:
        crossAxisLocalOffset = dx;
        mainAxisLocalOffset = -dy;
        break;
      case AxisDirection.right:
        mainAxisLocalOffset = dx;
        crossAxisLocalOffset = dy;
        break;
      case AxisDirection.down:
        crossAxisLocalOffset = dx;
        mainAxisLocalOffset = dy;
        break;
      case AxisDirection.left:
        mainAxisLocalOffset = -dx;
        crossAxisLocalOffset = dy;
        break;
    }
  }

  int updateMainAxisOffset() {
    final current = currentMainAxisOffset;
    if ((current - lastMainAxisOffset).abs() > 1E-3) {
      if (current > lastMainAxisOffset) {
        lastMainAxisOffset = current;
        return 1;
      } else {
        lastMainAxisOffset = current;
        return -1;
      }
    }
    return 0;
  }

  void updateCurrentOffset(
    SliverConstraints constraints,
    double maxPaintExtent,
  ) {
    currentMainAxisOffset =
        (originMainAxisOffset +
                mainAxisLocalOffset +
                (constraints.scrollOffset - originScrollOffset))
            .clamp(0.0, maxPaintExtent - itemSize);
  }

  double computeScrollDelta(
    SliverConstraints constraints,
    ScrollPosition position,
    double itemSize,
  ) {
    var fromOffset = constraints.scrollOffset;
    var toOffset = fromOffset + constraints.remainingPaintExtent;
    if (currentMainAxisOffset < fromOffset && position.extentBefore > 0.0) {
      return -_kReorderingScrollSpeed;
    } else if (currentMainAxisOffset + itemSize > toOffset &&
        position.extentAfter > 0.0) {
      return _kReorderingScrollSpeed;
    }
    return 0.0;
  }
}

extension ItemMeasureConversion on double {
  ItemMeasure toExactMeasure() =>
      this == 0.0 ? ItemMeasure.zero : ItemMeasure(this);
}

// Creates a copy of an interval builder possibly adding more offset.
// If the offset is zero, the same interval builder is returned.
IntervalBuilder? offsetIntervalBuilder(IntervalBuilder? iBuilder, int offset) {
  if (offset == 0 || iBuilder == null) return iBuilder;
  assert(offset > 0);
  return (context, index, data) => iBuilder.call(context, index + offset, data);
}

// Joins two interval builder and returns a new merged one.
IntervalBuilder joinBuilders(
  IntervalBuilder leftBuilder,
  IntervalBuilder rightBuilder,
  int leftCount,
) {
  assert(leftCount > 0);
  return (context, index, data) => (index < leftCount)
      ? leftBuilder.call(context, index, data)
      : rightBuilder.call(context, index - leftCount, data);
}
