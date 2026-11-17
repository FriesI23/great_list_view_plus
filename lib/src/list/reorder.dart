/// Reorder models and the long-press gesture adapter that drives them.
library;

import 'package:flutter/widgets.dart';

import '../core.dart';

/// This model is used to manage the reordering of a list view.
/// The following callbacks has to be provided:
/// - [onReorderStart] is called first when a new request of reordering is coming. The index of the
///   item is passed and two other additional parameters are passed that indicate the offset of the
///   tap/click from the top left corner of the item; if `false` is returned, the reorder
///   won't start at all;
/// - [onReorderFeedback] called whenever the item is moved by dragging. Its item's index is
///   passed again, then the index where it would like to move, the offset from the top of the sliver and
///   finally a delta indicating the distance of the new point from the original one.
///   Any value can be returned. If the last returned value is changed, a rebuild will be notified for
///   the dragged item. The returned value will be passed to the [AnimatedWidgetBuilderData]
///   of the builder.
/// - [onReorderMove] called when the dragged item, corresponding to the first index, would like to
///   move with the item corresponding to the second index. If `false` is returned, the move
///   won't be taken into consideration at all;
/// - [onReorderComplete] called at the end of reorder when the move must actually be done.
///   The last returned value from [onReorderFeedback] is also passed. Implement this callback
///   to update your underlying list. Return `false` if you want to cancel the move.
abstract class AnimatedListBaseReorderModel {
  const AnimatedListBaseReorderModel();
  bool onReorderStart(int index, double dx, double dy) => false;
  Object? onReorderFeedback(
    int index,
    int dropIndex,
    double offset,
    double dx,
    double dy,
  ) => null;
  bool onReorderMove(int index, int dropIndex) => false;
  bool onReorderComplete(int index, int dropIndex, Object? slot) => false;
}

/// A callback function-based version of [AnimatedListBaseReorderModel].
class AnimatedListReorderModel extends AnimatedListBaseReorderModel {
  const AnimatedListReorderModel({
    this._onReorderStart,
    this._onReorderFeedback,
    this._onReorderMove,
    this._onReorderComplete,
  });

  final bool Function(int index, double dx, double dy)? _onReorderStart;
  final Object? Function(
    int index,
    int dropIndex,
    double offset,
    double dx,
    double dy,
  )?
  _onReorderFeedback;
  final bool Function(int index, int dropIndex)? _onReorderMove;
  final bool Function(int index, int dropIndex, Object? slot)?
  _onReorderComplete;

  @override
  bool onReorderStart(int index, double dx, double dy) =>
      _onReorderStart?.call(index, dx, dy) ?? false;

  @override
  Object? onReorderFeedback(
    int index,
    int dropIndex,
    double offset,
    double dx,
    double dy,
  ) => _onReorderFeedback?.call(index, dropIndex, offset, dx, dy);

  @override
  bool onReorderMove(int index, int dropIndex) =>
      _onReorderMove?.call(index, dropIndex) ?? false;

  @override
  bool onReorderComplete(int index, int dropIndex, Object? slot) =>
      _onReorderComplete?.call(index, dropIndex, slot) ?? false;
}

/// Default implementation of a reorder model based on a [List].
class AutomaticAnimatedListReorderModel<T>
    extends AnimatedListBaseReorderModel {
  const AutomaticAnimatedListReorderModel(this.list);

  final List<T> list;

  /// See [AnimatedListBaseReorderModel].
  ///
  /// The default implementation always returns `true`.
  @override
  bool onReorderStart(int index, double dx, double dy) => true;

  /// See [AnimatedListBaseReorderModel].
  ///
  /// The default implementation always returns `null`.
  @override
  Object? onReorderFeedback(
    int index,
    int dropIndex,
    double offset,
    double dx,
    double dy,
  ) => null;

  /// See [AnimatedListBaseReorderModel].
  ///
  /// The default implementation always returns `true`.
  @override
  bool onReorderMove(int index, int dropIndex) => true;

  /// See [AnimatedListBaseReorderModel].
  ///
  /// The default implementation always returns `true`, after removing the dragged item
  /// and reinserted it in the new position.
  @override
  bool onReorderComplete(int index, int dropIndex, Object? slot) {
    list.insert(dropIndex, list.removeAt(index));
    return true;
  }
}

/// This widget is meant to be wrapped around list items to add automatic reordering
/// functionality using the long press gesture.
/// In general it is not necessary to create this widget directly because it is already done
/// by the most used classes, such `AnimatedListView`, `AutomaticAnimatedListView`,
/// `AnimatedSliverChildBuilderDelegate` and so on.
class LongPressReorderable extends StatelessWidget {
  const LongPressReorderable({super.key, required this.child});

  final Widget child;

  AnimatedListController? _findListController(BuildContext context) =>
      ListControllerBinding.controllerOf(context);

  void _onLongPressStart(BuildContext context, LongPressStartDetails d) {
    final controller = _findListController(context);
    controller?.notifyStartReorder(
      context,
      d.localPosition.dx,
      d.localPosition.dy,
    );
  }

  void _onLongPressMoveUpdate(
    BuildContext context,
    LongPressMoveUpdateDetails d,
  ) {
    final controller = _findListController(context);
    controller?.notifyUpdateReorder(d.localPosition.dx, d.localPosition.dy);
  }

  void _onLongPressEnd(BuildContext context, LongPressEndDetails d) {
    final controller = _findListController(context);
    controller?.notifyStopReorder(false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerCancel: (_) =>
          _findListController(context)?.notifyStopReorder(true),
      child: GestureDetector(
        onLongPressStart: (d) => _onLongPressStart(context, d),
        onLongPressEnd: (d) => _onLongPressEnd(context, d),
        onLongPressMoveUpdate: (d) => _onLongPressMoveUpdate(context, d),
        child: child,
      ),
    );
  }
}
