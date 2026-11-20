/// List construction: layout callbacks, child delegates and the sliver widget contract.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Material;

import '../core.dart';
import '../transitions/morph_transition.dart';
import 'animation.dart';
import 'diagnostics.dart';
import 'reorder.dart';

/// Chooses the initial scroll offset after the list receives sliver constraints.
typedef InitialScrollOffsetCallback = double? Function(
  SliverConstraints constraints,
);

/// A delegate that supplies children for animated slivers.
///
/// This class has been inspired by [SliverChildDelegate].
abstract class AnimatedSliverChildDelegate {
  const AnimatedSliverChildDelegate();

  /// Provides the initial child count of the underlying list.
  int get initialChildCount;

  /// Provides the builder of the items currently present in the undelying list.
  AnimatedWidgetBuilder get builder;

  /// Wrap a built child widget adding extra visual effects, animations and others.
  Widget wrapWidget(
    BuildContext context,
    Widget widget,
    AnimatedWidgetBuilderData data,
  );

  /// Provides an animator to customize all the animations.
  AnimatedListAnimator get animator;

  /// Provides a model (a bunch of callbacks) to handle reordering.
  AnimatedListBaseReorderModel? get reorderModel;

  /// A function that is called at the very early stage to give you the option to return the initial scroll offset.
  InitialScrollOffsetCallback? get initialScrollOffsetCallback;

  /// Whether to prevent scrolling up when the above items not visibile are modified.
  bool get holdScrollOffset;

  /// See [SliverChildDelegate.didFinishLayout].
  /// The indices refer to the actual items built in the list view.
  void didFinishLayout(int firstIndex, int lastIndex) {}

  @override
  String toString() {
    final description = <String>[];
    return '${describeIdentity(this)}(${description.join(", ")})';
  }
}

/// A base class for animated sliver that have multiple box children, inspired by [SliverMultiBoxAdaptorWidget].
abstract class AnimatedSliverMultiBoxAdaptorWidget
    extends SliverWithKeepAliveWidget {
  const AnimatedSliverMultiBoxAdaptorWidget({
    super.key,
    required this.listController,
    required this.delegate,
  });

  final AnimatedListController listController;

  final AnimatedSliverChildDelegate delegate;
}

/// Inspired by [SliverChildBuilderDelegate].
class AnimatedSliverChildBuilderDelegate extends AnimatedSliverChildDelegate {
  /// See [SliverChildBuilderDelegate.addAutomaticKeepAlives] for details.
  ///
  /// Defaults to `true`.
  final bool addAutomaticKeepAlives;

  /// See [SliverChildBuilderDelegate.addRepaintBoundaries] for details.
  ///
  /// Defaults to `true`.
  final bool addRepaintBoundaries;

  /// Whether to wrap each child in a [LongPressReorderable], if a reorder model has been provided.
  ///
  /// This allows the items to be dragged for reordering purpose with a long press gesture.
  ///
  /// Defaults to `true`.
  final bool addLongPressReorderable;

  /// Whether to wrap each child in a [Material], if a reorder model has been provided.
  ///
  /// An elevation effect is automatically applied to the item picked up for reordering.
  /// If the value is `0.0` the child is not wrapped at all.
  /// See [Material.elevation] for details.
  ///
  /// Defaults to [kDefaultAnimatedElevation].
  final double addAnimatedElevation;

  /// Whether to wrap each child in a [FadeTransition].
  ///
  /// A fade effect is automatically applied to dismissing and incoming items.
  ///
  /// Defaults to `true`.
  final bool addFadeTransition;

  /// If provided, it wraps each child in a [MorphTransition].
  ///
  /// It adds a cross-fade effect to the items that change their content, fading out the old content
  /// and fading in the new one.
  /// This callback has to return `false` if the morph effect is to be applied, ie the new widget
  /// content is different from the old one. Avoid returning `false` when not needed, in order
  /// not to apply the effect unnecessarily when the two compared widgets are identical.
  ///
  /// Defaults to `null`.
  final MorphComparator? morphComparator;

  /// Whether to resize the widget that is changing when applying the [MorphTransition] effect.
  /// If `false`, the widget with the largst content will be cropped during the animation.
  /// See also [MorphTransition.resizeWidgets].
  ///
  /// Defaults to `true`.
  final bool morphResizeWidgets;

  /// The duration of the [MorphTransition] effect.
  ///
  /// Defaults to [kDefaultMorphTransitionDuration].
  final Duration morphDuration;

  /// Whether to prevent scrolling up when the above items not visibile are modified.
  /// See [AnimatedSliverChildDelegate.holdScrollOffset].
  ///
  /// Defaults to `false`.
  @override
  final bool holdScrollOffset;

  /// A function that is called at the very early stage to give you the option to return the initial scroll offset.
  /// If `null` not callback will be invoked.
  /// See [AnimatedSliverChildDelegate.initialScrollOffsetCallback].
  ///
  /// Defaults to `null`.
  @override
  final InitialScrollOffsetCallback? initialScrollOffsetCallback;

  /// Provides a model (a bunch of callbacks) that handles reordering.
  /// If `null` the list view cannot be reordered.
  /// See [AnimatedSliverChildDelegate.reorderModel].
  ///
  /// Defaults to `null`.
  @override
  final AnimatedListBaseReorderModel? reorderModel;

  /// Provides the builder of the items currently present in the underlying list.
  /// See [AnimatedSliverChildDelegate.builder].
  @override
  final AnimatedWidgetBuilder builder;

  /// Provides an animator to customize all the animations.
  /// See [AnimatedSliverChildDelegate.animator].
  ///
  /// Defaults to an instance of [DefaultAnimatedListAnimator].
  @override
  final AnimatedListAnimator animator;

  /// The initial count of the children present in the underlying list.
  /// This attribute is only read during the first build.
  /// See [AnimatedSliverChildDelegate.initialChildCount].
  @override
  final int initialChildCount;

  /// The callback [didFinishLayoutCallback] will be invoked, if any.
  ///
  /// See [AnimatedSliverChildDelegate.didFinishLayout] for more information.
  @override
  void didFinishLayout(int firstIndex, int lastIndex) =>
      didFinishLayoutCallback?.call(firstIndex, lastIndex);

  /// The callback to be invoked on [AnimatedSliverChildDelegate.didFinishLayout].
  ///
  /// Defaults to `null`.
  final void Function(int, int)? didFinishLayoutCallback;

  AnimatedSliverChildBuilderDelegate(
    this.builder,
    this.initialChildCount, {
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.animator = const DefaultAnimatedListAnimator(),
    this.addLongPressReorderable = true,
    this.addAnimatedElevation = kDefaultAnimatedElevation,
    this.addFadeTransition = true,
    this.morphResizeWidgets = true,
    this.morphDuration = kDefaultMorphTransitionDuration,
    this.morphComparator,
    this.reorderModel,
    this.initialScrollOffsetCallback,
    this.didFinishLayoutCallback,
    this.holdScrollOffset = false,
  }) : assert(initialChildCount >= 0);

  /// See [AnimatedSliverChildDelegate.wrapWidget].
  @override
  Widget wrapWidget(
    BuildContext context,
    Widget child,
    AnimatedWidgetBuilderData data,
  ) {
    if (data.measuring) return child;
    final originalChild = child;
    final Key? key = child.key != null ? _SaltedValueKey(child.key!) : null;
    if (morphComparator != null) {
      child = MorphTransition(
        duration: morphDuration,
        resizeWidgets: morphResizeWidgets,
        comparator: morphComparator!,
        child: child,
      );
    }
    if (addAnimatedElevation != 0.0 && reorderModel != null) {
      child = Material(
        elevation: data.dragging ? addAnimatedElevation : 0.0,
        child: child,
      );
    }
    if (addFadeTransition) {
      child = FadeTransition(opacity: data.animation, child: child);
    }
    if (addLongPressReorderable && reorderModel != null) {
      child = LongPressReorderable(child: child);
    }
    if (addRepaintBoundaries) {
      child = RepaintBoundary(child: child);
    }
    if (addAutomaticKeepAlives) {
      child = AutomaticKeepAlive(child: child);
    }
    child = KeyedSubtree(key: key, child: child);
    if (kDebugMode) {
      child = ListDebugWidget(child, () => originalChild.toStringShort());
    }
    return child;
  }
}

class _SaltedValueKey extends ValueKey<Key> {
  const _SaltedValueKey(super.key);
}
