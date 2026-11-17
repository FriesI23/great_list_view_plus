part of 'core.dart';

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
  /// - [addAnimatedElevation], used to wrap each item in a [Material] (see also
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

  static AnimatedSliverMultiBoxAdaptorElement? of(BuildContext context) {
    try {
      return context
          .findAncestorRenderObjectOfType<AnimatedRenderSliverMultiBoxAdaptor>()
          ?.childManager;
    } catch (e) {
      return null;
    }
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
  AnimatedSliverMultiBoxAdaptorElement createElement() =>
      AnimatedSliverMultiBoxAdaptorElement(this);

  @override
  AnimatedRenderSliverList createRenderObject(BuildContext context) {
    return AnimatedRenderSliverList(
      this,
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
  AnimatedSliverMultiBoxAdaptorElement createElement() =>
      AnimatedSliverMultiBoxAdaptorElement(this);

  @override
  AnimatedRenderSliverFixedExtentList createRenderObject(BuildContext context) {
    return AnimatedRenderSliverFixedExtentList(
      widget: this,
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
/// by the most used classes, such [AnimatedListView], [AutomaticAnimatedListView],
/// [AnimatedSliverChildBuilderDelegate] and so on.
class LongPressReorderable extends StatelessWidget {
  const LongPressReorderable({super.key, required this.child});

  final Widget child;

  AnimatedListController? _findListController(BuildContext context) {
    return (AnimatedSliverMultiBoxAdaptorWidget.of(context))
        ?.widget
        .listController;
  }

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
    return GestureDetector(
      onLongPressStart: (d) => _onLongPressStart(context, d),
      onLongPressEnd: (d) => _onLongPressEnd(context, d),
      onLongPressMoveUpdate: (d) => _onLongPressMoveUpdate(context, d),
      child: child,
    );
  }
}

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
