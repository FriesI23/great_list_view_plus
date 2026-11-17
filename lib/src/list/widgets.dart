import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core.dart';
import '../diff/dispatcher.dart';
import '../rendering/child_manager.dart';
import '../rendering/sliver_list.dart';
import '../transitions/morph_transition.dart';
import 'animation.dart';
import 'delegates.dart';
import 'reorder.dart';

/// A scrollable and animated list of widgets arranged linearly, inspired by [ListView].
class AnimatedListView extends BoxScrollView {
  /// Constructs an animated list view.
  ///
  /// Most of the attributes are identical to those of the [ListView].
  /// The specific ones are the following:
  /// - [listController], an [AnimatedListController] mainly used to be notified about any changes to the underlying list;
  /// - [itemBuilder], an [AnimatedWidgetBuilder] used to build the widgets of the underlying list items;
  /// - [initialItemCount], the initial count of the underlying list items;
  /// - [animator], an [AnimatedListAnimator] used to customize all the animations (see also
  ///   [AnimatedSliverChildBuilderDelegate.animator]);
  /// - [addLongPressReorderable], used to wrap each item in a [LongPressReorderable] (see also
  ///   [AnimatedSliverChildBuilderDelegate.addLongPressReorderable]);
  /// - [addAnimatedElevation], used to wrap each item in a `Material` (see also
  ///   [AnimatedSliverChildBuilderDelegate.addAnimatedElevation]);
  /// - [addFadeTransition], used to wrap each item in a [FadeTransition] (see also
  ///   [AnimatedSliverChildBuilderDelegate.addFadeTransition]);
  /// - [morphComparator], used to wrap each item in a [MorphTransition] (see also
  ///   [AnimatedSliverChildBuilderDelegate.morphComparator]);
  /// - [morphResizeWidgets], tells wheter or not resize widgets when they are crossfading (see also
  ///   [AnimatedSliverChildBuilderDelegate.morphResizeWidgets]);
  /// - [morphDuration], the duration of the [MorphTransition] effect (see also
  ///   [AnimatedSliverChildBuilderDelegate.morphDuration]);
  /// - [reorderModel], used to provide a model (a bunch of callbacks) which controls the behavior of reorders
  ///   (see also [AnimatedSliverChildBuilderDelegate.reorderModel]);
  /// - [initialScrollOffsetCallback], callback invoked at the first build that returns the initial scroll offset
  ///   (see also [AnimatedSliverChildBuilderDelegate.initialScrollOffsetCallback]);
  /// - [didFinishLayoutCallback], callback invoked when the list view has been layouted
  ///   (see also [AnimatedSliverChildBuilderDelegate.didFinishLayoutCallback]);
  /// - [holdScrollOffset], holds the scroll position when above items are modified (see also
  ///   [AnimatedSliverChildBuilderDelegate.holdScrollOffset]);
  AnimatedListView({
    super.key,
    required this.listController,
    required AnimatedWidgetBuilder itemBuilder,
    required int initialItemCount,
    this.itemExtent,
    AnimatedListAnimator animator = const DefaultAnimatedListAnimator(),
    bool addLongPressReorderable = true,
    double addAnimatedElevation = kDefaultAnimatedElevation,
    bool addFadeTransition = true,
    MorphComparator? morphComparator,
    bool morphResizeWidgets = true,
    Duration morphDuration = kDefaultMorphTransitionDuration,
    AnimatedListBaseReorderModel? reorderModel,
    InitialScrollOffsetCallback? initialScrollOffsetCallback,
    void Function(int, int)? didFinishLayoutCallback,
    bool holdScrollOffset = false,
    //
    super.scrollDirection,
    super.reverse,
    ScrollController? scrollController,
    super.primary,
    super.physics,
    super.shrinkWrap,
    super.padding,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    // Keep the existing public cacheExtent parameter.
    // ignore: deprecated_member_use
    super.cacheExtent,
    super.dragStartBehavior,
    ScrollViewKeyboardDismissBehavior super.keyboardDismissBehavior =
        ScrollViewKeyboardDismissBehavior.manual,
    super.restorationId,
    super.clipBehavior,
  }) : assert(initialItemCount >= 0),
       delegate = AnimatedSliverChildBuilderDelegate(
         itemBuilder,
         initialItemCount,
         addAutomaticKeepAlives: addAutomaticKeepAlives,
         addRepaintBoundaries: addRepaintBoundaries,

         animator: animator,
         addLongPressReorderable: addLongPressReorderable,
         addAnimatedElevation: addAnimatedElevation,
         addFadeTransition: addFadeTransition,
         morphResizeWidgets: morphResizeWidgets,
         morphDuration: morphDuration,
         morphComparator: morphComparator,
         reorderModel: reorderModel,
         initialScrollOffsetCallback: initialScrollOffsetCallback,
         didFinishLayoutCallback: didFinishLayoutCallback,
         holdScrollOffset: holdScrollOffset,
       ),
       super(controller: scrollController ?? ScrollController());

  /// Constructs an animated list view with a custom delegate.
  ///
  /// Most of the attributes are identical to those of the [ListView].
  /// The specific ones are the following:
  /// - [listController], an [AnimatedListController] mainly used to be notified about any changes to the underlying list;
  /// - [delegate], your custom [AnimatedSliverChildDelegate] delegate.
  const AnimatedListView.custom({
    super.key,
    required this.listController,
    required this.delegate,
    //
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.shrinkWrap,
    super.padding,
    this.itemExtent,
    // Keep the existing public cacheExtent parameter.
    // ignore: deprecated_member_use
    super.cacheExtent,
    super.semanticChildCount,
    super.dragStartBehavior,
    ScrollViewKeyboardDismissBehavior super.keyboardDismissBehavior =
        ScrollViewKeyboardDismissBehavior.manual,
    super.restorationId,
    super.clipBehavior,
  });

  final AnimatedListController listController;

  final double? itemExtent;

  final AnimatedSliverChildDelegate delegate;

  @override
  Widget buildChildLayout(BuildContext context) {
    if (itemExtent != null) {
      return AnimatedSliverFixedExtentList(
        delegate: delegate,
        itemExtent: itemExtent!,
        controller: listController,
      );
    }
    return AnimatedSliverList(delegate: delegate, controller: listController);
  }
}

/// An animated sliver that places multiple box children in a linear array along the main
/// axis, inspired by [SliverList].
class AnimatedSliverList extends AnimatedSliverMultiBoxAdaptorWidget {
  const AnimatedSliverList({
    super.key,
    required super.delegate,
    required AnimatedListController controller,
  }) : super(listController: controller);

  @override
  RenderObjectElement createElement() =>
      AnimatedSliverMultiBoxAdaptorElement(this);

  @override
  RenderSliverWithKeepAliveMixin createRenderObject(BuildContext context) {
    return AnimatedRenderSliverList(
      context as AnimatedSliverMultiBoxAdaptorElement,
    );
  }
}

/// An animated sliver that places multiple box children with the same main axis extent in
/// a linear array, inspired by [SliverFixedExtentList].
class AnimatedSliverFixedExtentList
    extends AnimatedSliverMultiBoxAdaptorWidget {
  const AnimatedSliverFixedExtentList({
    super.key,
    required super.delegate,
    required AnimatedListController controller,
    required this.itemExtent,
  }) : super(listController: controller);

  final double itemExtent;

  @override
  RenderObjectElement createElement() =>
      AnimatedSliverMultiBoxAdaptorElement(this);

  @override
  RenderSliverWithKeepAliveMixin createRenderObject(BuildContext context) {
    return AnimatedRenderSliverFixedExtentList(
      childManager: context as AnimatedSliverMultiBoxAdaptorElement,
      itemExtent: itemExtent,
    );
  }
}

/// Extension of the [AnimatedListView] that offers intrisic use of the [AnimatedListDiffListDispatcher]
/// to automatically animate the list view when this widget is rebuilt with a different [list].
/// All attributes, except for [list], are identical to those of the [AnimatedListView].
class AutomaticAnimatedListView<T> extends AnimatedListView {
  AutomaticAnimatedListView({
    super.key,
    required this.list,
    required super.listController,
    required this.itemBuilder,
    required this.comparator,
    AnimatedListAnimator animator = const DefaultAnimatedListAnimator(),
    bool addLongPressReorderable = true,
    double addAnimatedElevation = kDefaultAnimatedElevation,
    bool addFadeTransition = true,
    bool morphResizeWidgets = true,
    Duration morphDuration = kDefaultMorphTransitionDuration,
    MorphComparator? morphComparator,
    AnimatedListBaseReorderModel? reorderModel,
    InitialScrollOffsetCallback? initialScrollOffsetCallback,
    void Function(int, int)? didFinishLayoutCallback,
    bool holdScrollOffset = false,
    this.detectMoves = false,
    //
    super.scrollDirection,
    super.reverse,
    ScrollController? scrollController,
    super.primary,
    super.physics,
    super.shrinkWrap,
    super.padding,
    super.itemExtent,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    // Keep the existing public cacheExtent parameter.
    // ignore: deprecated_member_use
    super.cacheExtent,
    int? semanticChildCount,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.restorationId,
    super.clipBehavior,
  }) : super.custom(
         controller: scrollController ?? ScrollController(),
         delegate: AnimatedSliverChildBuilderDelegate(
           (context, index, data) {
             return itemBuilder(context, list[index], data);
           },
           list.length,
           addAutomaticKeepAlives: addAutomaticKeepAlives,
           addRepaintBoundaries: addRepaintBoundaries,

           animator: animator,
           addLongPressReorderable: addLongPressReorderable,
           addAnimatedElevation: addAnimatedElevation,
           addFadeTransition: addFadeTransition,
           morphResizeWidgets: morphResizeWidgets,
           morphDuration: morphDuration,
           morphComparator: morphComparator,
           reorderModel: reorderModel,
           initialScrollOffsetCallback: initialScrollOffsetCallback,
           didFinishLayoutCallback: didFinishLayoutCallback,
           holdScrollOffset: holdScrollOffset,
         ),
       );

  final AnimatedListDiffListBuilder<T> itemBuilder;

  final AnimatedListDiffListBaseComparator<T> comparator;

  final List<T> list;

  final bool detectMoves;

  @override
  Widget buildChildLayout(BuildContext context) {
    final widget = super.buildChildLayout(context);
    return _DiffDispatcherWidget(
      comparator: comparator,
      controller: listController,
      itemBuilder: itemBuilder,
      list: list,
      detectMoves: detectMoves,
      child: widget,
    );
  }
}

class _DiffDispatcherWidget<T> extends StatefulWidget {
  const _DiffDispatcherWidget({
    super.key,
    required this.controller,
    required this.comparator,
    required this.list,
    required this.itemBuilder,
    required this.child,
    required this.detectMoves,
  });

  final AnimatedListController controller;
  final AnimatedListDiffListBuilder<T> itemBuilder;
  final AnimatedListDiffListBaseComparator<T> comparator;
  final List<T> list;
  final Widget child;
  final bool detectMoves;

  @override
  _DiffDispatcherWidgetState<T> createState() =>
      _DiffDispatcherWidgetState<T>();
}

class _DiffDispatcherWidgetState<T> extends State<_DiffDispatcherWidget<T>> {
  AnimatedListDiffListDispatcher<T>? _dispatcher;

  void _createDispatcher() {
    final oldProcessingList = _dispatcher?.discard();
    _dispatcher = AnimatedListDiffListDispatcher<T>(
      controller: widget.controller,
      currentList: _dispatcher?.currentList ?? widget.list,
      itemBuilder: widget.itemBuilder,
      comparator: widget.comparator,
    );
    if (oldProcessingList != null) {
      _dispatcher!.dispatchNewList(
        oldProcessingList,
        detectMoves: widget.detectMoves,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _createDispatcher();
  }

  @override
  void didUpdateWidget(_DiffDispatcherWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.itemBuilder != widget.itemBuilder ||
        oldWidget.comparator != widget.comparator) {
      _createDispatcher();
    }
    if (oldWidget.list != widget.list) {
      _dispatcher!.dispatchNewList(
        widget.list,
        detectMoves: widget.detectMoves,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
