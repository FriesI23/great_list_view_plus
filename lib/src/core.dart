/// Shared item builders, controller and visibility values for list and tree clients.
library;

import 'package:flutter/widgets.dart';

/// Additional information to build a specific item of the list.
class AnimatedWidgetBuilderData {
  /// The main animation used by dismssing of incoming items. The value `0.0` indicates that the
  /// item is totally dismissed, whereas `1.0` indicates the item is totally income.
  final Animation<double> animation;

  /// If `true` it indicates that this item is the one dragged during a reorder.
  final bool dragging;

  /// If `true` it indicates that this item is moving whitin a pop up.
  final bool moving;

  /// If `true` it indicates that this item is going to be built just to measure it. You can check
  /// this attribute in order to build am equivalent lighter widget (which is the same size as
  /// the original).
  final bool measuring;

  /// The slot value you have returned from your `AnimatedListReorderModel`.
  final Object? slot;

  const AnimatedWidgetBuilderData(
    this.animation, {
    this.measuring = false,
    this.dragging = false,
    this.slot,
    this.moving = false,
  });
}

/// The builder used to build the items of the list view.
typedef AnimatedWidgetBuilder = Widget Function(
  BuildContext context,
  int index,
  AnimatedWidgetBuilderData data,
);

/// The part of the size of the item that is currently visible.
class AnimatedListItemVisibility {
  /// Visible length along the list's main axis, in logical pixels.
  final double size;

  /// Full item length along the list's main axis, in logical pixels.
  final double referredSize;

  const AnimatedListItemVisibility(this.size, this.referredSize);

  /// The visible fraction of the item's full length.
  double get percentage => size / referredSize;

  @override
  String toString() => '${percentage * 100.0}%';
}

/// Internal protocol implemented by a mounted list element.
abstract interface class AnimatedListControllerDelegate {
  BuildContext get context;
  AnimatedListController get listController;
  void notifyChangedRange(
    int from,
    int count,
    AnimatedWidgetBuilder changeItemBuilder,
  );

  void notifyInsertedRange(int from, int count);

  void notifyRemovedRange(
    int from,
    int count,
    AnimatedWidgetBuilder removeItemBuilder,
  );

  void notifyReplacedRange(
    int from,
    int removeCount,
    int insertCount,
    AnimatedWidgetBuilder removeItemBuilder,
  );

  void notifyMovedRange(int from, int count, int newIndex);

  void batch(VoidCallback callback);

  bool notifyStartReorder(BuildContext context, double dx, double dy);

  void notifyUpdateReorder(double dx, double dy);

  void notifyStopReorder(bool cancel);

  Rect? computeItemBox(int index, bool absolute);

  AnimatedListItemVisibility? getItemVisibleSize(int index);
}

/// Use this controller to notify to the `AnimatedListView` about changes in your underlying list and more.
class AnimatedListController {
  AnimatedListControllerDelegate? _interface;

  /// Notifies the `AnimatedListView` that a range starting from [from] and [count] long
  /// has been modified. Call this method after actually you have updated your list.
  /// A new builder [changeItemBuilder] has to be provided in order to build the old
  /// items when animating.

  void notifyChangedRange(
    int from,
    int count,
    AnimatedWidgetBuilder changeItemBuilder,
  ) {
    assert(_debugAssertBinded());
    _interface!.notifyChangedRange(from, count, changeItemBuilder);
  }

  /// Notifies the `AnimatedListView` that a new range starting from [from] and [count] long
  /// has been inserted. Call this method after actually you have updated your list.

  void notifyInsertedRange(int from, int count) {
    assert(_debugAssertBinded());
    _interface!.notifyInsertedRange(from, count);
  }

  /// Notifies the `AnimatedListView` that a range starting from [from] and [count] long
  /// has been removed. Call this method after actually you have updated your list.
  /// A new builder [removeItemBuilder] has to be provided in order to build the removed
  /// items when animating.
  void notifyRemovedRange(
    int from,
    int count,
    AnimatedWidgetBuilder removeItemBuilder,
  ) {
    assert(_debugAssertBinded());
    _interface!.notifyRemovedRange(from, count, removeItemBuilder);
  }

  /// Notifies the `AnimatedListView` that a range starting from [from] and [removeCount] long
  /// has been replaced with a new [insertCount] long range. Call this method after
  /// you have updated your list.
  /// A new builder [removeItemBuilder] has to be provided in order to build the replaced
  /// items when animating.
  void notifyReplacedRange(
    int from,
    int removeCount,
    int insertCount,
    AnimatedWidgetBuilder removeItemBuilder,
  ) {
    assert(_debugAssertBinded());
    _interface!.notifyReplacedRange(
      from,
      removeCount,
      insertCount,
      removeItemBuilder,
    );
  }

  /// Notifies the `AnimatedListView` that a range starting from [from] and [count] long
  /// has been moved to a new location, at [newIndex] position (the new index considers the interval just removed).
  /// Call this method after you have updated your list.
  void notifyMovedRange(int from, int count, int newIndex) {
    assert(_debugAssertBinded());
    _interface!.notifyMovedRange(from, count, newIndex);
  }

  /// If more changes to the underlying list need be applied in a row, it is more efficient
  /// to call this method and notify all the changes within the callback.
  void batch(VoidCallback callback) {
    assert(_debugAssertBinded());
    _interface!.batch(callback);
  }

  /// Notifies the `AnimatedListView` that a new reoder has begun.
  /// The [context] has to be provided to help `AnimatedListView` to locate the item
  /// to be picked up for reordering.
  /// The attributs [dx] and [dy] are the coordinates relative to the position of the item.
  ///
  /// Use this method only if you have decided not to use the
  /// `AnimatedSliverChildBuilderDelegate.addLongPressReorderable` attribute or the
  /// `LongPressReorderable` widget (for example if you want to reorder using your
  /// custom drag handles).
  ///
  /// This method could return `false` indicating that the reordering cannot be started.
  bool notifyStartReorder(BuildContext context, double dx, double dy) {
    assert(_debugAssertBinded());
    return _interface!.notifyStartReorder(context, dx, dy);
  }

  /// Notifies the `AnimatedListView` that the dragged item has moved.
  /// The attributs [dx] and [dy] are the coordinates relative to the original position
  /// of the item.
  ///
  /// Use this method only if you have decided not to use the
  /// `AnimatedSliverChildBuilderDelegate.addLongPressReorderable` attribute or the
  /// `LongPressReorderable` widget (for example if you want to reorder using your
  /// custom drag handles).
  void notifyUpdateReorder(double dx, double dy) {
    assert(_debugAssertBinded());
    _interface!.notifyUpdateReorder(dx, dy);
  }

  /// Notifies the `AnimatedListView` that the reorder has finished or cancelled
  /// ([cancel] set to `true`).
  ///
  /// Use this method only if you have decided not to use the
  /// `AnimatedSliverChildBuilderDelegate.addLongPressReorderable` attribute or the
  /// `LongPressReorderable` widget (for example if you want to reorder using your
  /// custom drag handles).
  void notifyStopReorder(bool cancel) {
    assert(_debugAssertBinded());
    _interface!.notifyStopReorder(cancel);
  }

  /// Calculates the box (in pixels) of the item indicated by the [index] provided.
  ///
  /// The index of the item refers to the index of the underlying list.
  ///
  /// If [absolute] is `false` the offset is relative to the upper edge of the sliver,
  /// otherwise the offset is relative to the upper edge of the topmost sliver.
  ///
  /// For one, you might pass the result to the [ScrollController.jumpTo] or [ScrollController.animateTo] methods
  /// of a [ScrollController] to scroll to the desired item.
  ///
  /// The method returns `null` if the box cannot be calculated. This happens when the item isn't yet diplayed
  /// (because animations are still in progress) or when the state of the list view has been changed via notifications
  /// but these changes are not yet taken into account.
  ///
  /// Be careful! This method calculates the item box starting from items currently built in the viewport, therefore,
  /// if the desired item is very far from them, the method could take a long time to return the result
  /// since it must measure all the intermediate items that are among those of the viewport and the desired one.
  Rect? computeItemBox(int index, [bool absolute = false]) {
    assert(_debugAssertBinded());
    return _interface!.computeItemBox(index, absolute);
  }

  /// Returns the size of the visible part (in pixels) of a certain item in the list view.
  ///
  /// The index of the item refers to the index of the underlying list.
  ///
  /// The method returns `null` if the box of the item cannot be calculated. This happens when the item
  /// isn't yet diplayed or when the state of the list view has been changed via notifications
  /// but these changes are not yet taken into account.
  AnimatedListItemVisibility? getItemVisibleSize(int index) {
    assert(_debugAssertBinded());
    return _interface!.getItemVisibleSize(index);
  }

  void _setInterface(AnimatedListControllerDelegate interface) {
    if (_interface != null) {
      throw FlutterError(
        'You are trying to bind this controller to multiple animated list views.\n'
        'A $runtimeType can only be binded to one list view at a time.',
      );
    }
    _interface = interface;
  }

  void _unsetInterface(AnimatedListControllerDelegate interface) {
    if (_interface == interface) _interface = null;
  }

  BuildContext get context => _interface!.context;

  bool _debugAssertBinded() {
    assert(() {
      if (_interface == null) {
        throw FlutterError(
          'This controller was used before it was connected to an animated list view.\n'
          'Make sure you passed this instance to the listController attribute of an AutomaticAnimatedListView, AnimatedListView, AnimatedSliverList or AnimatedSliverFixedExtentList.',
        );
      }
      return true;
    }());
    return true;
  }
}

/// Internal bridge; controller binding is deliberately absent from its public API.
abstract final class ListControllerBinding {
  static void attach(
    AnimatedListController controller,
    AnimatedListControllerDelegate delegate,
  ) => controller._setInterface(delegate);
  static void detach(
    AnimatedListController controller,
    AnimatedListControllerDelegate delegate,
  ) => controller._unsetInterface(delegate);

  static AnimatedListController? controllerOf(BuildContext context) {
    AnimatedListController? controller;
    context.visitAncestorElements((element) {
      if (element is AnimatedListControllerDelegate) {
        controller = (element as AnimatedListControllerDelegate).listController;
        return false;
      }
      return true;
    });
    return controller;
  }
}
