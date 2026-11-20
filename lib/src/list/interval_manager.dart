import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core.dart';
import '../utils/ticker_provider_mixin.dart';
import 'animation.dart';
import 'diagnostics.dart';
import 'interval_list.dart';
import 'interval_model.dart';
import 'intervals.dart';

class IntervalManager with TickerProviderMixin implements IntervalCoordinator {
  var _disposed = false;

  // This allows to communicate with the child manager.
  @override
  final ListIntervalHost interface;

  /// Any updates that the child manager has to take into account in the next rebuild
  /// via the [AnimatedSliverMultiBoxAdaptorElement.performRebuild] method.
  final updates = List<IntervalUpdate>.empty(growable: true);

  /// All animations attached to its intervals.
  final animations = <ControlledAnimation<AnimatedIntervalMixin>>{};

  final List<PopUpList> _listOfPopUps = [];
  List<PopUpList> get listOfPopUps => List.unmodifiable(_listOfPopUps);

  late IntervalList list;

  late int _lastBuildCount;

  IntervalManager(this.interface) {
    final initialCount = _lastBuildCount = interface.delegate.initialChildCount;
    list = IntervalList.normal(this, initialCount);
  }

  /// The [AnimatedListAnimator] instance taken from the [AnimatedSliverChildDelegate].
  AnimatedListAnimator get animator => interface.delegate.animator;

  /// Returns `true` if there are pending updates.
  bool get hasPendingUpdates => updates.isNotEmpty;

  //

  MovingPopUpList _addMovingPopUpList([MovingPopUpList? prevPopUpList]) {
    assert(debugAssertNotDisposed());
    final popUpList = MovingPopUpList();
    if (prevPopUpList == null) {
      _listOfPopUps.add(popUpList);
    } else {
      _listOfPopUps.insert(listOfPopUps.indexOf(prevPopUpList), popUpList);
    }
    return popUpList;
  }

  ReorderPopUpList _addReorderPopUpList(IntervalList list) {
    assert(debugAssertNotDisposed());
    final popUpList = ReorderPopUpList(list);
    assert(listOfPopUps.isEmpty || listOfPopUps.first is! ReorderPopUpList);
    _listOfPopUps.insert(0, popUpList);
    return popUpList;
  }

  @override
  void onResizeTick(AnimatedSpaceInterval interval, double delta) {
    interface.resizingIntervalUpdated(interval, delta);
  }

  @override
  void onMovingTick() {
    interface.markNeedsLayout();
  }

  // This interval list has notified that a range of the underlying list has been replaced.
  void notifyReplacedRange(
    int from,
    int removeCount,
    int insertCount,
    AnimatedWidgetBuilder? removeItemBuilder,
  ) {
    assert(debugAssertNotDisposed());
    assert(removeCount == 0 || removeItemBuilder != null);
    if (!(from >= 0 &&
        removeCount >= 0 &&
        insertCount >= 0 &&
        from + removeCount <= list.itemCount)) {
      throw Exception('Out of range');
    }

    if (removeCount == 0 && insertCount == 0) return;

    listLogBegin(
      'notifyReplacedRange( from=$from, rem=$removeCount, ins=$insertCount )',
    );
    listLogPrint('$this');

    if (list.isEmpty) {
      list.newContent(insertCount);
      return;
    }

    list.distributeNotification(
      from,
      removeCount,
      insertCount,
      removeItemBuilder,
      0,
      onReplaceNotification,
    );

    checkMainListChanged();

    listLogPrint('$this');
    listLogPrint('$updates');
    listLogEnd();
  }

  // This interval list has notified that a range of the underlying list has been changed.
  void notifyChangedRange(
    int from,
    int count,
    AnimatedWidgetBuilder changeItemBuilder,
  ) {
    assert(debugAssertNotDisposed());
    if (!(from >= 0 && count >= 0 && from + count <= list.itemCount)) {
      throw Exception('Out of range');
    }

    listLogBegin('notifyChangedRange( from=$from, count=$count )');
    listLogPrint('$this');

    list.distributeNotification(
      from,
      count,
      count,
      changeItemBuilder,
      0,
      onChangeNotification,
    );

    checkMainListChanged();

    listLogPrint('$this');
    listLogPrint('$updates');
    listLogEnd();
  }

  // This interval list has notified that a range of the underlying list has been moved.
  void notifyMovedRange(int from, int count, int to) {
    assert(debugAssertNotDisposed());
    if (!(from >= 0 &&
        count >= 0 &&
        from + count <= list.itemCount &&
        to <= list.itemCount - count)) {
      throw Exception('Out of range');
    }

    if (count == 0 || from == to) return;

    listLogBegin('notifyMovedRange( from=$from, count=$count, newIndex=$to )');
    listLogPrint('$this');

    final bundle = _MoveBundle(list);
    list.distributeNotification(
      from,
      count,
      count,
      null,
      0,
      onMoveNotificationPick,
      params: bundle,
    );
    list.distributeNotification(
      to,
      0,
      1, // symbolical
      null,
      0,
      _onMoveNotificationDrop,
      params: (bundle..flush()).execute(),
    );

    checkMainListChanged();

    listLogPrint('$this');
    listLogPrint('$updates');
    listLogEnd();
  }

  /// It transforms the interval affected by a replacement notification.
  void onReplaceNotification(
    ListInterval interval,
    IntervalList list,
    int removeCount,
    int insertCount,
    int leading,
    int trailing,
    AnimatedWidgetBuilder? offListItemBuilder,
    int offListItemBuilderOffset,
    Object? _,
  ) {
    if (removeCount == 0 && insertCount == 0) return;

    if (interval is AdjustableInterval) {
      final newItemCount = interval.itemCount - removeCount + insertCount;
      if (newItemCount == 0 && interval.buildCount == 0) {
        list.remove(interval.iterable());
      } else {
        final newInterval = interval.clone(newItemCount);
        list.replace(interval.iterable(), newInterval.iterable());
      }
    } else if (interval is ResizableInterval) {
      list.replace(
        interval.iterable(),
        ReadyToNewResizingInterval(
          interval.itemCount - removeCount + insertCount,
          interval.currentSize.toExactMeasure(),
          interval.averageCount,
        ).iterable(),
      );
    } else {
      if (leading == 0 && trailing == interval.itemCount) {
        assert(removeCount == 0 && insertCount > 0);
        list.insertBefore(
          interval,
          ReadyToResizingSpawnedInterval(insertCount).iterable(),
        );
      } else if (trailing == 0 && leading == interval.itemCount) {
        assert(removeCount == 0 && insertCount > 0);
        list.insertAfter(
          interval,
          ReadyToResizingSpawnedInterval(insertCount).iterable(),
        );
      } else if (interval is SubListInterval) {
        interval.subList.distributeNotification(
          leading,
          removeCount,
          insertCount,
          offListItemBuilder,
          offListItemBuilderOffset,
          onReplaceNotification,
        );
        if (interval is ReorderHolderInterval) {
          assert(removeCount == 1);
          interface.reorderCancel();
        }
      } else if (interval is NormalInterval) {
        late ListInterval middle;
        if (removeCount > 0) {
          middle = ReadyToRemovalInterval(
            interval.animation,
            _offListBuilder(offListItemBuilder, offListItemBuilderOffset)!,
            removeCount,
            insertCount,
          );
        } else {
          middle = ReadyToResizingSpawnedInterval(insertCount);
        }
        final result = interval.splitWith(
          leading,
          trailing,
          middle.iterable(),
          _alwaysUpdateCallback,
        );
        performSplit(interval, result);
      } else if (interval is ReadyToChangingInterval) {
        ListInterval middle;
        if (removeCount > 0) {
          middle = ReadyToRemovalInterval(
            interval.animation,
            offsetIntervalBuilder(interval.builder, leading)!,
            removeCount,
            insertCount,
          );
        } else {
          middle = ReadyToResizingSpawnedInterval(insertCount);
        }
        final result = interval.splitWith(
          leading,
          trailing,
          middle.iterable(),
          _alwaysUpdateCallback,
        );
        performSplit(interval, result);
      } else {
        throw Exception(
          'The interval $interval was not handled in distribution of replacements',
        );
      }
    }
  }

  /// It transforms the interval affected by a change notification.
  void onChangeNotification(
    ListInterval interval,
    IntervalList list,
    int changeCount,
    int _,
    int leading,
    int trailing,
    AnimatedWidgetBuilder? offListItemBuilder,
    int offListItemBuilderOffset,
    Object? _,
  ) {
    if (changeCount == 0) return;

    assert(interval.itemCount > 0);

    if (interval is NormalInterval) {
      late ListInterval middle;
      middle = ReadyToChangingInterval(
        interval.animation,
        _offListBuilder(offListItemBuilder, offListItemBuilderOffset)!,
        changeCount,
      );
      final result = interval.splitWith(
        leading,
        trailing,
        middle.iterable(),
        _alwaysUpdateCallback,
      );
      performSplit(interval, result);
    } else if (interval is ReadyToChangingInterval) {
      // already marked to be changed
    } else if (interval is AdjustableInterval) {
      list.replace(
        interval.iterable(),
        interval.clone(interval.itemCount).iterable(),
      );
    } else if (interval is ResizableInterval) {
      list.replace(
        interval.iterable(),
        ReadyToNewResizingInterval(
          interval.itemCount,
          interval.currentSize.toExactMeasure(),
          interval.averageCount,
        ).iterable(),
      );
    } else if (interval is SubListInterval) {
      assert(interval is! WithDropInterval);
      interval.subList.distributeNotification(
        leading,
        changeCount,
        changeCount,
        offListItemBuilder,
        offListItemBuilderOffset,
        onChangeNotification,
      );
    } else if (interval is ReorderHolderInterval) {
      var subList = reorderLayoutData!.openingInterval.subList;
      subList.distributeNotification(
        leading,
        changeCount,
        changeCount,
        offListItemBuilder,
        offListItemBuilderOffset,
        onChangeNotification,
      );
    } else {
      throw Exception(
        'The interval $interval was not handled in distribution of changes',
      );
    }
  }

  void onMoveNotificationPick(
    ListInterval interval,
    IntervalList list,
    int count,
    int moveCount,
    int leading,
    int trailing,
    AnimatedWidgetBuilder? offListItemBuilder,
    int offListItemBuilderOffset,
    Object? bundle,
  ) {
    assert(moveCount == count);

    final moveBundle = bundle as _MoveBundle;
    if (count == 0) {
      moveBundle.flush();
      return;
    }

    if (interval is DropInterval) {
      moveBundle.addDropInterval(interval, leading, trailing);
    } else if (interval is MovingInterval) {
      moveBundle.addMovingInterval(interval, leading, trailing);
    } else if (interval is ReorderHolderInterval) {
      moveBundle.addReoderHolderInterval(interval);
    } else {
      final result = interval.split(leading, trailing);
      performSplit(interval, result);
      moveBundle.add(result.middle!);
    }
  }

  void _onMoveNotificationDrop(
    ListInterval interval,
    IntervalList list,
    int removeCount,
    int insertCount,
    int leading,
    int trailing,
    AnimatedWidgetBuilder? offListItemBuilder,
    int offListItemBuilderOffset,
    Object? bundle,
  ) {
    assert(removeCount == 0 && insertCount == 1);

    var dropIntervals = bundle as List<ListInterval>;

    assert(dropIntervals.buildCount == 0);

    if (leading == 0 && trailing == interval.itemCount) {
      list.insertBefore(
        interval,
        dropIntervals,
        updateCallback: _alwaysUpdateCallback,
      );
    } else if (trailing == 0 && leading == interval.itemCount) {
      list.insertAfter(
        interval,
        dropIntervals,
        updateCallback: _alwaysUpdateCallback,
      );
    } else if (interval is DropInterval) {
      final result = interval.withDropInterval.dropSplit(leading, trailing);
      performSplit(interval.withDropInterval, result);
      list.replace(interval.iterable(), (
        SplitResult? r,
        Iterable<ListInterval> d,
      ) sync* {
        if (r?.left != null) {
          yield (result.left!.first as WithDropInterval).dropInterval;
        }
        yield* d;
        if (r?.right != null) {
          yield (result.right!.first as WithDropInterval).dropInterval;
        }
      }(result, dropIntervals));
    } else {
      final result = interval.splitWith(
        leading,
        trailing,
        dropIntervals,
        _alwaysUpdateCallback,
      );
      performSplit(interval, result);
    }
  }

  //

  /// It converts the builder passed in [notifyReplacedRange] or [notifyChangedRange] in an
  /// interval builder with the specified [offset].
  IntervalBuilder? _offListBuilder(
    AnimatedWidgetBuilder? builder, [
    int offset = 0,
  ]) {
    assert(offset >= 0);
    if (builder == null) return null;
    return (context, index, data) =>
        interface.wrapWidget(builder, index + offset, data, false);
  }

  void _alwaysUpdateCallback(
    IntervalList list,
    int index,
    int oldBuildCount,
    int newBuildCount,
  ) {
    list.addUpdate(index, oldBuildCount, newBuildCount);
  }

  @override
  void performSplit(ListInterval i, SplitResult r) {
    i.list!.replace(
      i.iterable(),
      (SplitResult r) sync* {
        if (r.left != null) yield* r.left!;
        if (r.middle != null) yield* r.middle!;
        if (r.right != null) yield* r.right!;
      }(r),
      updateCallback: (list, index, oldBuildCount, newBuildCount) {
        r.updateCallback?.call(list, index, oldBuildCount, newBuildCount);
      },
      intermediateCallback: r.subListSplitCallback,
    );
  }

  Iterable<ListInterval> get allIntervals =>
      list.followedBy(subIntervalLists.expand((e) => e));

  bool _postponed = false;

  Iterable<IntervalList> get subIntervalLists =>
      list.whereType<SubListHolderInterval>().map((e) => e.subList);

  void checkMainListChanged() {
    subIntervalLists.where((l) => l.changed).forEach((l) => onListChanged(l));
    if (list.changed) onListChanged(list);
    assert(debugConsistency());
  }

  void onListChanged(IntervalList list) {
    optimize(list);

    if (list.holder != null) {
      if (list.isEmpty) {
        final holder = list.holder!;
        final holderList = holder.list!;
        if (holder is ReadyToMoveInterval) {
          assert(holder.itemCount == 0 && holder.buildCount == 0);
          holderList.changed = true;
          holder.dropInterval.unlink();
          holderList.remove(
            holder.iterable(),
            updateCallback: _alwaysUpdateCallback,
          );
        } else if (holder is MovingInterval) {
          assert(holder.itemCount == 0);
          holderList.changed = true;
          _listOfPopUps.remove(holder.popUpList);
          holderList.remove(
            holder.iterable(),
            updateCallback: _alwaysUpdateCallback,
          );
        }
      }
    }

    list.changed = false;
  }

  /// It transforms some or all ready-to intervals into a new type of intervals.
  void coordinate() {
    listLogBegin('coordinate()');
    listLogPrint('$this');

    _coordinate();

    checkMainListChanged();

    listLogPrint('$this');
    listLogEnd();
  }

  void _coordinate() {
    allIntervals
        .whereType<ReadyToResizing>()
        .where((e) => !e.isMeasured && !e.isMeasuring) // && e.isReadyToMeasure)
        .forEach((interval) {
          final f = interval.startMeasuring(interface);
          if (f is Future<bool>) {
            f.then((v) {
              if (v) coordinate();
            });
          }
        });

    if (!list.whereType<MovingInterval>().any(
      (i) => !i.areAnimationsCompleted,
    )) {
      _unpackCompletedDrop();
    }

    _readyToRemoveToRemoval();

    if (list.whereType<RemovalInterval>().any(
      (i) => !i.areAnimationsCompleted,
    )) {
      return;
    }

    if (list.whereType<ReadyToResizing>().any((i) => i.isMeasuring)) {
      return;
    }

    _readyToChangeToNormal();

    _readyToResizeToResizing();

    _readyToMoveToMove();

    if (list.whereType<ResizingInterval>().any(
          (i) => !i.areAnimationsCompleted,
        ) ||
        list.whereType<MovingInterval>().any(
          (i) => !i.areAnimationsCompleted,
        )) {
      return;
    }

    _readyToInsertToInsert();
  }

  void _readyToRemoveToRemoval() {
    var rem = allIntervals.whereType<ReadyToRemovalInterval>();
    if (rem.isNotEmpty) {
      rem.toList().forEach((interval) {
        final animation = interval.isWaitingAtEnd
            ? _createAnimation(animator.dismiss())
            : _createAnimation(
                animator.dismissDuringIncoming(interval.animation.time),
              );
        final newInterval = RemovalInterval(
          animation,
          interval.builder,
          interval.buildCount,
          interval.itemCount,
        );
        listLogPrint('->Rm => Rm {$interval}, {$newInterval}');
        interval.list!.replace(
          interval.iterable(),
          newInterval.iterable(),
          updateCallback: _alwaysUpdateCallback,
        );
        newInterval.startAnimation();
      });
    }
  }

  void _readyToChangeToNormal() {
    var chg = allIntervals.whereType<ReadyToChangingInterval>().where(
      (e) => e.list!.popUpList == null,
    );
    if (chg.isNotEmpty) {
      chg.toList().forEach((interval) {
        _freezeDropPopUp(interval);
        final newInterval = NormalInterval(
          interval.animation,
          interval.itemCount,
        );
        listLogPrint('->Ch => Nm {$interval}, {$newInterval}');
        interval.list!.replace(
          interval.iterable(),
          newInterval.iterable(),
          updateCallback: _alwaysUpdateCallback,
        );
      });
    }
  }

  // TODO: Revisit popup resizing and final animated item sizes.
  void _freezeDropPopUp(ListInterval interval) {
    // Freeze a moving popup while its contents change size, then recalculate
    // its dimensions and destination before resuming the move.
    if (interval.list?.holder is MovingInterval) {
      final di = interval.list?.holder as MovingInterval;
      final i = ReadyToPopupMoveInterval(
        di.popUpList.subLists.single,
        di.popUpList,
        di.averageCount,
        di.currentSize,
      );
      list.replace(di.iterable(), () sync* {
        yield i;
        yield i.dropInterval;
      }());
    }
  }

  void _readyToResizeToResizing() {
    var res = allIntervals.whereType<ReadyToResizing>();
    if (res.isNotEmpty) {
      res.where((e) => e.isMeasured).toList().forEach((interval) {
        // TODO: does not work, because it does not take into condideration the final height of the item changed for
        // because of the animation that deals with the changing
        _freezeDropPopUp(interval);
        final newInterval = ResizingInterval(
          _createAnimation(
            animator.resizing(interval.fromSize!.value, interval.toSize!.value),
          ),
          interval.fromSize!,
          interval.toSize!,
          interval.fromLength,
          interval.itemCount,
        );
        listLogPrint('->Rz => Rz {$interval}, {$newInterval}');
        interval.list!.replace(
          interval.iterable(),
          newInterval.iterable(),
          updateCallback:
              (
                IntervalList list,
                int index,
                int oldBuildCount,
                int newBuildCount,
              ) {
                list.addUpdate(
                  index,
                  oldBuildCount,
                  newBuildCount,
                  flags: interval.fromSize!.estimated
                      ? const IntervalUpdateFlags(
                          IntervalUpdateFlags.discardElement |
                              IntervalUpdateFlags.clearLayoutOffset,
                        )
                      : const IntervalUpdateFlags(
                          IntervalUpdateFlags.discardElement |
                              IntervalUpdateFlags.clearLayoutOffset |
                              IntervalUpdateFlags.keepFirstLayoutOffset,
                        ),
                );
              },
        );
        newInterval.startAnimation();
      });
    }
  }

  void _readyToInsertToInsert() {
    var ins = allIntervals.whereType<ReadyToInsertionInterval>();
    if (ins.isNotEmpty) {
      ins.toList().forEach((interval) {
        final newInterval = NormalInterval(
          _createAnimation(animator.incoming()),
          interval.itemCount,
        );
        listLogPrint('->In => Nm {$interval}, {$newInterval}');
        interval.list!.replace(
          interval.iterable(),
          newInterval.iterable(),
          updateCallback:
              (
                IntervalList list,
                int index,
                int oldBuildCount,
                int newBuildCount,
              ) {
                list.addUpdate(
                  index,
                  oldBuildCount,
                  newBuildCount,
                  flags: interval.size.estimated
                      ? const IntervalUpdateFlags(
                          IntervalUpdateFlags.discardElement |
                              IntervalUpdateFlags.clearLayoutOffset,
                        )
                      : const IntervalUpdateFlags(
                          IntervalUpdateFlags.discardElement |
                              IntervalUpdateFlags.clearLayoutOffset |
                              IntervalUpdateFlags.keepFirstLayoutOffset,
                        ),
                );
              },
        );
        newInterval.startAnimation();
      });
    }
  }

  void _readyToMoveToMove() {
    final toMoveIntervals = allIntervals.whereType<WithDropInterval>();
    if (toMoveIntervals.isNotEmpty) {
      void fn() {
        var popUpListToRemove = <PopUpList>{};

        void transformIntervals(
          WithDropInterval r2mi,
          ItemMeasure fromStart,
          ItemMeasure fromSize,
          ItemMeasure fromBoxSize,
          ControlledAnimation<AnimatedIntervalMixin> resizeAnim,
          ControlledAnimation<AnimatedIntervalMixin> moveAnim,
          ItemMeasure toSize,
          ItemMeasure toOffset,
          MovingPopUpList? oldPopUp,
        ) {
          var toIndex = r2mi.dropInterval.itemOffset;
          if (r2mi.itemOffset < toIndex) {
            toIndex -= r2mi.itemCount;
          }

          final movingInterval = MovingInterval(
            resizeAnim,
            moveAnim,
            r2mi.subList,
            _addMovingPopUpList(oldPopUp),
            toSize,
            fromStart.value,
          );

          final resizeInterval = ResizingInterval(
            _createAnimation(animator.resizing(fromSize.value, 0.0)),
            fromBoxSize,
            ItemMeasure.zero,
            r2mi.averageCount,
            0,
          );
          final list = r2mi.list!;
          listLogPrint('->Mv => Mv {${r2mi.dropInterval}}, {$movingInterval}');
          list.replace(
            r2mi.dropInterval.iterable(),
            movingInterval.iterable(),
            updateCallback: _alwaysUpdateCallback,
          );
          list.replace(
            r2mi.iterable(),
            resizeInterval.iterable(),
            updateCallback:
                (
                  IntervalList list,
                  int index,
                  int oldBuildCount,
                  int newBuildCount,
                ) {
                  if (r2mi is ReadyToPopupMoveInterval) {
                    addUpdate(
                      index,
                      oldBuildCount,
                      newBuildCount,
                    ); // resize box
                    final count = r2mi.subList.buildCount;
                    addUpdate(
                      r2mi.popUpList.buildIndexOf(r2mi.subList),
                      count,
                      count,
                      popUpList: r2mi.popUpList,
                      toPopUpList: movingInterval.popUpList,
                      flags: const IntervalUpdateFlags(
                        IntervalUpdateFlags.popupPick,
                      ),
                    );
                  } else {
                    addUpdate(
                      index,
                      oldBuildCount,
                      newBuildCount,
                      toPopUpList: movingInterval.popUpList,
                      flags: const IntervalUpdateFlags(
                        IntervalUpdateFlags.popupPick,
                      ),
                    );
                  }
                },
          );
          resizeInterval.startAnimation();
          movingInterval.startAnimation();

          if (oldPopUp != null) {
            popUpListToRemove.add(oldPopUp);
          }
        } // fn()

        final callbacks = toMoveIntervals.toList().map<void Function()>((r2mi) {
          MovingPopUpList? oldPopUp;
          ItemMeasure fromStart, fromEnd, fromSize, fromBoxSize;
          if (r2mi is ReadyToPopupMoveInterval) {
            oldPopUp = r2mi.popUpList;
            final i = r2mi.popUpList.buildIndexOf(r2mi.subList);
            fromStart = interface.estimateLayoutOffset(
              i,
              r2mi.popUpList.popUpBuildCount,
              popUpList: r2mi.popUpList,
            );
            fromEnd = interface.estimateLayoutOffset(
              i + r2mi.subList.buildCount,
              r2mi.popUpList.popUpBuildCount,
              popUpList: r2mi.popUpList,
            );

            fromSize = fromEnd - fromStart;

            if (fromSize.value > 50 && fromSize.value < 70 && i == 1) {
              fromStart = interface.estimateLayoutOffset(
                i,
                r2mi.popUpList.popUpBuildCount,
                popUpList: r2mi.popUpList,
              );
              fromEnd = interface.estimateLayoutOffset(
                i + r2mi.subList.buildCount,
                r2mi.popUpList.popUpBuildCount,
                popUpList: r2mi.popUpList,
              );
            }

            fromBoxSize = ItemMeasure(r2mi.currentSize);
          } else {
            fromStart = interface.estimateLayoutOffset(
              r2mi.buildOffset,
              list.buildCount,
            );
            fromEnd = interface.estimateLayoutOffset(
              r2mi.buildOffset + r2mi.buildCount,
              list.buildCount,
            );
            fromSize = fromEnd - fromStart;
            fromBoxSize = fromSize;
          }

          // ottimizzazione: se sono tutti ReadyToResizingSpawnedInterval, è inuile creare la popup
          // con soli box ridimenzionabili invisibili, tanto vale metterli direttamente a destinazione
          if (!r2mi.subList.any((e) => e is! ReadyToResizingSpawnedInterval)) {
            return () {
              final list = r2mi.list!;
              var toIndex = r2mi.dropInterval.itemOffset;
              if (r2mi.itemOffset < toIndex) {
                toIndex -= r2mi.itemCount;
              }

              Iterable<ListInterval> newList;
              ResizingInterval? resizeInterval;
              if (r2mi is ReadyToPopupMoveInterval) {
                resizeInterval = ResizingInterval(
                  _createAnimation(animator.resizing(r2mi.currentSize, 0.0)),
                  r2mi.currentSize.toExactMeasure(),
                  ItemMeasure.zero,
                  r2mi.averageCount,
                  0,
                );
                newList = resizeInterval.iterable();
              } else {
                newList = const [];
              }
              list.replace(
                r2mi.iterable(),
                newList,
                updateCallback: _alwaysUpdateCallback,
              );
              // note: no callback, because buildCounts are always zero
              list.replace(r2mi.dropInterval.iterable(), r2mi.subList);
              resizeInterval?.startAnimation();
            };
          }

          final moveAnim = _createAnimation(animator.moving());
          final toSize = math
              .max(
                0.0,
                (fromSize.value + r2mi.futureDeltaSize(moveAnim.durationInSec)),
              )
              .toExactMeasure();

          final resizeAnim = _createAnimation(
            animator.resizing(0.0, toSize.value),
          );

          final maxDuration = math.max<double>(
            resizeAnim.durationInSec,
            moveAnim.durationInSec,
          );

          var toOffset = interface.estimateLayoutOffset(
            r2mi.dropInterval.buildOffset,
            list.buildCount,
            time: maxDuration,
          );

          return () => transformIntervals(
            r2mi,
            fromStart,
            fromSize,
            fromBoxSize,
            resizeAnim,
            moveAnim,
            // futureDeltaSize,
            toSize,
            toOffset,
            oldPopUp,
          );
        }).toList();

        for (var e in callbacks) {
          e.call();
        }

        for (var pl in popUpListToRemove) {
          _listOfPopUps.remove(pl);
        }
      } // fn()

      if (updates.isNotEmpty) {
        if (!_postponed) {
          _postponed = true;

          listLogPrint('scheduling _readyToMoveToDrop at next frame');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _postponed = false;

            listLogBegin('_readyToMoveToDrop postponed');

            listLogPrint('$this');

            assert(updates.isEmpty);

            fn();

            listLogPrint('$this');
            listLogEnd();
          });
        }
      } else {
        fn();
      }
    }
  }

  void _unpackCompletedDrop() {
    list
        .whereType<MovingInterval>()
        .where((i) => i.areAnimationsCompleted)
        .toList()
        .forEach((i) {
          listLogPrint('Mv finished {$i}');
          list.replace(
            i.iterable(),
            i.subList,
            updateCallback:
                (
                  IntervalList list,
                  int index,
                  int oldBuildCount,
                  int newBuildCount,
                ) {
                  addUpdate(
                    index,
                    oldBuildCount,
                    newBuildCount,
                    popUpList: i.popUpList,
                    flags: const IntervalUpdateFlags(
                      IntervalUpdateFlags.popupDrop,
                    ),
                  );
                },
          );
          _listOfPopUps.remove(i.popUpList);
        });
  }

  /// This is Called when an [interval] has completed its animation.
  /// It could transform that interval into a new type of interval.
  void onIntervalCompleted(AnimatedIntervalMixin interval) {
    listLogBegin('_onIntervalCompleted( $interval )');
    listLogPrint('$this');

    final list = interval.list!;

    if (interval is RemovalInterval) {
      list.replace(
        interval.iterable(),
        ReadyToResizingFromRemovalInterval(
          interval.builder,
          interval.buildCount,
          interval.itemCount,
        ).iterable(),
      );
    } else if (interval is ReorderClosingInterval) {
      list.remove(interval.iterable(), updateCallback: _alwaysUpdateCallback);
    } else if (interval is ResizingInterval) {
      if (interval.toLength > 0) {
        list.replace(
          interval.iterable(),
          ReadyToInsertionInterval(
            interval.toSize,
            interval.itemCount,
          ).iterable(),
          updateCallback: _alwaysUpdateCallback,
        );
      } else {
        assert(interval.toSize.value == 0.0);
        list.remove(interval.iterable(), updateCallback: _alwaysUpdateCallback);
      }
    }

    checkMainListChanged();

    listLogPrint('$this');
    listLogEnd();
  }

  /// It analyzes if there are intervals that can be merged together in order to optimize this list.
  void optimize(IntervalList list) {
    if (list.isEmpty) return;

    ListInterval? interval = list.first;
    ListInterval? oldLeftInterval, leftInterval, nextInterval = interval.next;
    while (interval != null) {
      var mergeResult = leftInterval != null
          ? interval.mergeWith(leftInterval)
          : null;
      if (mergeResult != null) {
        final mergedIntervals = mergeResult.mergedIntervals;
        assert(mergedIntervals.isNotEmpty);
        final newFirstInterval = mergedIntervals.first;
        list.replace(
          [leftInterval!, interval],
          mergedIntervals,
          updateCallback: mergeResult.callback,
        );
        leftInterval = oldLeftInterval;
        interval = newFirstInterval;
        // oldLeftInterval = oldLeftInterval?.previous;
        oldLeftInterval = leftInterval?.previous;
      } else {
        oldLeftInterval = leftInterval;
        leftInterval = interval;
        interval = nextInterval;
      }
      nextInterval = interval?.next;
    }
  }

  /// Adds a new [IntervalUpdate] element in the update list of this list interval or pop-up list.
  /// This methods also instructs the child manager to be rebuilt.
  @override
  void addUpdate(
    int index,
    int oldBuildCount,
    int newBuildCount, {
    IntervalUpdateFlags flags = const IntervalUpdateFlags(),
    PopUpList? popUpList,
    PopUpList? toPopUpList,
  }) {
    assert(debugAssertNotDisposed());
    if (oldBuildCount == 0 && newBuildCount == 0) return;
    final update = IntervalUpdate(
      index,
      oldBuildCount,
      newBuildCount,
      flags,
      popUpList,
      toPopUpList,
    );
    updates.add(update);
    interface.markNeedsBuild();
  }

  void clearUpdates() {
    updates.clear();
    _lastBuildCount = list.buildCount;
    for (var p in listOfPopUps) {
      p.lastBuildCount = p.popUpBuildCount;
    }
  }

  ControlledAnimation<AnimatedIntervalMixin> _createAnimation(
    AnimatedListAnimationData data,
  ) {
    assert(debugAssertNotDisposed());
    final animation = ControlledAnimation<AnimatedIntervalMixin>(
      this,
      data.animation,
      data.duration,
      startTime: data.startTime,
      onDispose: (a) => animations.remove(a),
      onCompleted: (a) {
        // when the animation is complete it notifies all its linked intervals
        if (a.intervals.isNotEmpty) {
          a.intervals.toList().forEach((i) {
            if (i.areAnimationsCompleted && !i.isDisposed && i.list != null) {
              onIntervalCompleted(i);
            }
          });
          coordinate();
        }
      },
    );
    animations.add(animation);
    return animation;
  }

  @override
  @mustCallSuper
  void dispose() {
    assert(debugAssertNotDisposed());
    list.whereType<SubListInterval>().forEach((i) => i.subList.dispose());
    _listOfPopUps.clear();
    animations.clear();
    updates.clear();
    list.dispose();
    _disposed = true;
    super.dispose();
  }

  bool debugConsistency() {
    assert(() {
      if (list.whereType<SubListInterval>().any(
        (e) => e.subList.whereType<SubListInterval>().isNotEmpty,
      )) {
        return false;
      }

      final popUpLists = list
          .whereType<PopUpInterval>()
          .map<PopUpList>((e) => e.popUpList)
          .toSet();

      return setEquals(popUpLists, listOfPopUps.toSet()) &&
          list.whereType<WithDropInterval>().every(
            (e) => e.list == e.dropInterval.list,
          ) &&
          debugUpdateConsistency();
    }());
    return true;
  }

  bool debugAssertNotDisposed() {
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

  bool debugUpdateConsistency() {
    assert(() {
      final delta = updates
          .where((upd) => upd.popUpList == null || upd.flags.hasPopupDrop)
          .fold<int>(
            0,
            (pv, upd) => pv + upd.newBuildCount - upd.oldBuildCount,
          );
      return (_lastBuildCount + delta == list.buildCount) &&
          listOfPopUps.every((pl) => pl.debugUpdateConsistency(updates));
    }());
    return true;
  }

  //
  // Reordering
  //

  @override
  ReorderLayoutData? reorderLayoutData;

  void reorderStart(
    ReorderLayoutData rld,
    NormalInterval interval,
    int indexOffset,
    int itemIndex,
  ) {
    assert(debugAssertNotDisposed());
    assert(reorderLayoutData == null);
    reorderLayoutData = rld;

    final popUpList = _addReorderPopUpList(IntervalList.normal(this, 1));

    final itemSize = rld.itemSize;
    final animation = _createAnimation(
      animator.resizingDuringReordering(itemSize, itemSize),
    )..complete();
    final holder = ReorderHolderInterval();
    final open = ReorderOpeningInterval(
      holder,
      animation,
      itemSize,
      itemSize,
      popUpList,
      interface,
    );

    final updateIndex = interval.buildOffset + indexOffset;
    final result = interval.splitWith(
      indexOffset,
      interval.buildCount - indexOffset - 1,
      () sync* {
        yield holder;
        yield open;
      }(),
      _alwaysUpdateCallback,
    );
    performSplit(interval, result);
    addUpdate(
      updateIndex,
      1,
      1,
      toPopUpList: popUpList,
      flags: const IntervalUpdateFlags(IntervalUpdateFlags.popupPick),
    );

    reorderLayoutData!.openingInterval = open;
    reorderLayoutData!.currentMainAxisOffset = rld.lastMainAxisOffset;

    assert(debugConsistency());
  }

  void reorderUpdateSlot(Object? newSlot) {
    assert(debugAssertNotDisposed());
    if (reorderLayoutData!.slot == newSlot) return;
    reorderLayoutData!.slot = newSlot;
    final popUpList = reorderLayoutData!.openingInterval.popUpList;
    addUpdate(0, 1, 1, popUpList: popUpList);
  }

  void reorderUpdateDropListIndex(
    NormalInterval interval,
    int offset,
    int newDropIndex,
  ) {
    assert(debugAssertNotDisposed());
    if (reorderLayoutData!.dropListIndex == newDropIndex) return;
    final oldOpeningInterval = reorderLayoutData!.openingInterval;

    _reorderUpdateAllClosingIntervals();

    final popUpList = oldOpeningInterval.popUpList;
    final fromSize = oldOpeningInterval.currentSize;
    final closingInterval = ReorderClosingInterval(
      _createAnimation(animator.resizingDuringReordering(fromSize, 0.0)),
      fromSize,
    );
    final holder = oldOpeningInterval.holder;
    list.replace(
      oldOpeningInterval.iterable(),
      closingInterval.iterable(),
      updateCallback: _alwaysUpdateCallback,
    );

    final itemSize = reorderLayoutData!.itemSize;
    final newOpeningInterval = ReorderOpeningInterval(
      holder,
      _createAnimation(animator.resizingDuringReordering(0.0, itemSize)),
      0,
      itemSize,
      popUpList,
      interface,
    );

    final result = interval.splitWith(
      offset,
      interval.buildCount - offset,
      newOpeningInterval.iterable(),
      _alwaysUpdateCallback,
    );
    performSplit(interval, result);

    reorderLayoutData!.openingInterval = newOpeningInterval;
    assert(reorderLayoutData!.dropListIndex == newDropIndex);

    closingInterval.startAnimation();
    newOpeningInterval.startAnimation();

    assert(debugConsistency());
  }

  void reorderStop(bool cancel) {
    assert(debugAssertNotDisposed());
    final openingInterval = reorderLayoutData!.openingInterval;
    final holder = openingInterval.holder;
    final oldPopUpList = openingInterval.popUpList;
    final newPopUpList = _addMovingPopUpList();

    final animation = cancel
        ? (_createAnimation(
            animator.resizingDuringReordering(0, reorderLayoutData!.itemSize),
          )..start()) // we must animate even the smallest movements!
        : openingInterval.animation;
    final movingInterval = MovingInterval(
      animation,
      _createAnimation(animator.moving())
        ..start(), // we must animate even the smallest movements!
      oldPopUpList.intervalList,
      newPopUpList,
      reorderLayoutData!.itemSize.toExactMeasure(),
      oldPopUpList.currentScrollOffset!,
    );

    if (cancel) {
      final fromSize = openingInterval.currentSize;
      final closingInterval = ReorderClosingInterval(
        _createAnimation(animator.resizingDuringReordering(fromSize, 0.0))
          ..start(), // we must animate even the smallest movements!
        fromSize,
      );
      list.replace(
        openingInterval.iterable(),
        closingInterval.iterable(),
        updateCallback: _alwaysUpdateCallback,
      );
      list.replace(
        holder.iterable(),
        movingInterval.iterable(),
        updateCallback:
            (
              IntervalList list,
              int index,
              int oldBuildCount,
              int newBuildCount,
            ) {
              addUpdate(index, oldBuildCount, newBuildCount);
              addUpdate(
                0,
                1,
                1,
                popUpList: oldPopUpList,
                toPopUpList: newPopUpList,
                flags: const IntervalUpdateFlags(IntervalUpdateFlags.popupPick),
              );
            },
      );
      // closingInterval.startAnimation();
      _reorderUpdateAllClosingIntervals();
    } else {
      list.replace(
        openingInterval.iterable(),
        movingInterval.iterable(),
        updateCallback:
            (
              IntervalList list,
              int index,
              int oldBuildCount,
              int newBuildCount,
            ) {
              addUpdate(
                0,
                1,
                1,
                popUpList: oldPopUpList,
                toPopUpList: newPopUpList,
                flags: const IntervalUpdateFlags(IntervalUpdateFlags.popupPick),
              );
              addUpdate(index, oldBuildCount, newBuildCount);
            },
      );
      list.remove(holder.iterable());
    }

    // movingInterval.startAnimation();

    _listOfPopUps.remove(oldPopUpList);

    reorderLayoutData = null;

    assert(debugConsistency());
  }

  void _reorderUpdateAllClosingIntervals() {
    list.whereType<ReorderClosingInterval>().forEach((oldClosingInterval) {
      final fromSize = oldClosingInterval.currentSize;
      final newClosingInterval = ReorderClosingInterval(
        _createAnimation(animator.resizingDuringReordering(fromSize, 0.0))
          ..start(), // we must animate even the smallest movements!
        fromSize,
      );
      list.replace(
        oldClosingInterval.iterable(),
        newClosingInterval.iterable(),
        updateCallback: _alwaysUpdateCallback,
      );
    });
  }

  @override
  String toString() => list.toString();
}

class _MoveBundle {
  _MoveBundle(this.list);

  final IntervalList list;

  List<ListInterval> moveList = [];

  final callbacks = <ListInterval Function()>[];

  void add(Iterable<ListInterval> intervals) {
    moveList.addAll(intervals);
  }

  void addReoderHolderInterval(ReorderHolderInterval interval) {
    flush();
    callbacks.add(() {
      return interval;
    });
  }

  void addMovingInterval(MovingInterval interval, int leading, int trailing) {
    flush();
    callbacks.add(() {
      final result = interval.split(leading, trailing);
      list.manager.performSplit(interval, result);
      assert(result.middle!.single is ReadyToPopupMoveInterval);
      return (result.middle!.single as WithDropInterval).dropInterval;
    });
  }

  void addDropInterval(DropInterval interval, int leading, int trailing) {
    flush();
    callbacks.add(() {
      final result = interval.withDropInterval.dropSplit(leading, trailing);
      list.manager.performSplit(interval.withDropInterval, result);
      final withDropInterval = result.middle!.single as WithDropInterval;
      list.replace(interval.iterable(), (SplitResult r) sync* {
        if (r.left != null) {
          yield (r.left!.first as WithDropInterval).dropInterval;
        }
        if (r.right != null) {
          yield (r.right!.first as WithDropInterval).dropInterval;
        }
      }(result));
      return withDropInterval.dropInterval;
    });
  }

  void flush() {
    if (moveList.isEmpty) return;

    final finalMoveList = moveList;
    callbacks.add(() {
      final interval = ReadyToMoveInterval(IntervalList(list.manager));
      list.replace(
        finalMoveList,
        interval.iterable(),
        outSubList: interval.subList,
      );
      return interval.dropInterval;
    });

    moveList = [];
  }

  List<ListInterval> execute() {
    final dropIntervals = <ListInterval>[];
    for (final cb in callbacks) {
      dropIntervals.add(cb());
    }
    callbacks.clear();
    return dropIntervals;
  }
}
