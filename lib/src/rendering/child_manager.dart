import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core.dart';
import '../list/delegates.dart';
import '../list/diagnostics.dart';
import '../list/interval_manager.dart';
import '../list/interval_model.dart';
import '../list/intervals.dart';
import 'rendering_contracts.dart';
import 'sliver_list.dart';
import 'sliver_multi_box_adaptor.dart';

/// An element that lazily builds children for a [SliverWithKeepAliveWidget].
///
/// Implements [RenderSliverBoxChildManager], which lets this element manage
/// the children of subclasses of [RenderSliverMultiBoxAdaptor].
///
/// This class takes the implementation of the standard [SliverMultiBoxAdaptorElement] class
/// and adds support for animations and reordering feature.
class AnimatedSliverMultiBoxAdaptorElement extends RenderObjectElement
    implements AnimatedSliverChildManager, AnimatedListControllerDelegate {
  /// Creates an element that lazily builds children for the given widget with
  /// support for animations and reordering.
  AnimatedSliverMultiBoxAdaptorElement(
    AnimatedSliverMultiBoxAdaptorWidget super.widget,
  ) {
    _childElements[null] = SplayTreeMap<int, Element?>();
  }

  /// Support for the method didChangeDependencies like in [State.didChangeDependencies].
  bool _didChangeDependencies = false;
  bool _delegateChanged = false;

  @override
  BuildContext get context => this;

  @override
  AnimatedListController get listController => widget.listController;

  @override
  AnimatedSliverMultiBoxAdaptorWidget get widget =>
      super.widget as AnimatedSliverMultiBoxAdaptorWidget;

  @override
  AnimatedRenderSliverMultiBoxAdaptor get renderObject =>
      super.renderObject as AnimatedRenderSliverMultiBoxAdaptor;

  IntervalManager get _intervalListManager => renderObject.intervalManager;

  /// This method has been overridden to give the render object the `didChangeDependencies` method
  /// and to link this list view to its controller.
  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    renderObject.didChangeDependencies(this);
    ListControllerBinding.attach(widget.listController, this);
  }

  /// This method has been overridden to give the render object a `dispose` method and to unlink
  /// this list view from its controller.
  @override
  void unmount() {
    ListControllerBinding.detach(widget.listController, this);
    super.unmount();
  }

  @override
  void deactivate() {
    ListControllerBinding.detach(widget.listController, this);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    ListControllerBinding.attach(widget.listController, this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _didChangeDependencies = true;
  }

  @override
  void update(covariant AnimatedSliverMultiBoxAdaptorWidget newWidget) {
    final oldWidget = widget;
    _delegateChanged = newWidget.delegate != oldWidget.delegate;
    super.update(newWidget);
    if (newWidget.listController != oldWidget.listController) {
      ListControllerBinding.detach(oldWidget.listController, this);
      ListControllerBinding.attach(newWidget.listController, this);
    }
    if (_delegateChanged || _intervalListManager.hasPendingUpdates) {
      performRebuild();
    }
  }

  /// This function takes the old [index] of a child and calculates the new one by considering
  /// all the pending [updates].
  /// This method can return `null` if the child no longer exists (for example,
  /// all elements of a remove interval disappear when it becomes a resizing interval).
  @override
  ChildReindexResult oldIndexToNewIndex(int? index, PopUpList? popUpList) {
    var needsRebuild = _delegateChanged;
    var clearLayoutOffset = false;
    var discardElement = false;

    for (final upd in _intervalListManager.updates) {
      if (upd.popUpList == popUpList) {
        // stessa popup, ci interessa
      } else if (upd.flags.hasPopupDrop && popUpList == upd.toPopUpList) {
        // l'elemento sta per posarsi nella nostra popup, ci interessa
      } else {
        // siamo in un'altra popup, questo update non ci interessa
        continue;
      }

      if (upd.flags.hasPopupDrop && upd.popUpList == popUpList) {
        // l'elemento sta per uscire dalla nostra popup per posarsi in un'altra

        // index è la posizione dell'elemento relativa alla popup, dobbiamo sommare upd.index ch'è la posizione
        // della vecchia popup in cui si inserirà il primo elemento dell'intervallo
        index = index! + upd.index;
        popUpList = upd.toPopUpList; // cambio popup!
        needsRebuild = true;
        clearLayoutOffset = true;
        continue;
      }

      if (index! >= upd.index && index < upd.index + upd.oldBuildCount) {
        // l'indice ricade nell'intervallo di update (il vecchio)
        if (upd.flags.hasPopupDrop) {
          // l'indice ricade in un vecchio intervallo che sta per essere completamente sovrascritto dagli elementi
          // che prevongono da un'altra popup, pertanto l'elemento non esiste più
          index = null;
          // clearLayoutOffset = true;
          break;
        } else if (upd.flags.hasPopupPick) {
          // l'elemento si sta per spostare in un'altra popup
          // index va reso relativo alla nuova popup, pertanto va sotratto la posizione in cui si trovava nella
          // vecchia popup
          index -= upd.index;
          popUpList = upd.toPopUpList; // cambio popup!
          needsRebuild = true;
          clearLayoutOffset = true;
          continue;
        }
        if (index >= upd.index + upd.newBuildCount) {
          // l'elemento non esiste più, ricadeva nella parte finale del vecchio intervallo che era più grande
          // di quello nuovo
          index = null;
          break;
        }
        if (upd.flags.hasClearLayoutOffset) {
          // se c'è il flag clearLayoutOffset....
          if (index != upd.index || !upd.flags.hasKeepFirstLayoutOffset) {
            // azzera l'offset se non è il primo elemento dell'update, oppure se è il primo elemento
            // quest'ultimo non ha il flag kEEP_FIRST_LAYOUT_OFFSET
            clearLayoutOffset = true;
          }
        }

        // l'indice ricade nell'update, pertanto necessita di un rebuild
        needsRebuild = true;

        if (upd.flags.hasDiscardElement) {
          discardElement = true;
        }
      }
      if (index >= upd.index + upd.oldBuildCount) {
        // se l'indice ricade dopo quest'update, l'indice va riadattato di un delta dato dalla lunghezza
        // del nuovo intervallo meno quella del vecchio intervallo (per esempio, se l'update agisce su 4 elementi
        // che vengono convertiti in soli 3 nuovi elementi, il delta da sommare all'indice è -1)
        index += upd.skipCount;
      }
    }
    return ChildReindexResult(
      index,
      needsRebuild,
      discardElement,
      clearLayoutOffset,
      popUpList,
    );
  }

  String _debugChildrenList(SplayTreeMap<int, Element?> cl) {
    final l = <String>[];
    cl.forEach((index, element) => l.add('$index: ${debugElement(element!)}'));
    return "{${l.join(', ')}}";
  }

  @override
  Widget? build(int index, {bool measureOnly = false, PopUpList? popUpList}) {
    if (popUpList == null) {
      final count = _intervalListManager.list.buildCount;
      if (index < 0 || index >= count) return null;
      return _intervalListManager.list.build(this, index, measureOnly);
    } else {
      if (index < 0 || index >= popUpList.popUpBuildCount) return null;
      return popUpList.buildPopUp(this, index, measureOnly);
    }
  }

  MultiSliverMultiBoxAdaptorParentData? _parentDataOf(Element? element) =>
      element?.renderObject?.parentData
          as MultiSliverMultiBoxAdaptorParentData?;

  int? _currentlyUpdatingChildIndex;
  PopUpList? _currentlyUpdatingPopUpList;

  final Map<PopUpList?, SplayTreeMap<int, Element?>> _childElements =
      <PopUpList?, SplayTreeMap<int, Element?>>{};

  RenderBox? _currentBeforeChild;

  @override
  Iterable<PopUpList> get managedPopUpLists => _childElements.keys.nonNulls;

  SplayTreeMap<int, Element?> get _mainChildElements => _childElements[null]!;

  //
  // ### RenderSliverBoxChildManager implementation
  //

  /// Copied from [SliverMultiBoxAdaptorElement.createChild].
  @override
  void createChild(
    PopUpList? popUpList,
    int index, {
    required RenderBox? after,
  }) {
    assert(_currentlyUpdatingChildIndex == null);
    owner!.buildScope(this, () {
      final childElements = _childElements.putIfAbsent(
        popUpList,
        () => SplayTreeMap<int, Element?>(),
      );
      final insertFirst = after == null;
      assert(insertFirst || childElements[index - 1] != null);
      _currentBeforeChild = insertFirst
          ? null
          : (childElements[index - 1]!.renderObject as RenderBox?);
      Element? newChild;
      try {
        _currentlyUpdatingPopUpList = popUpList;
        _currentlyUpdatingChildIndex = index;
        newChild = updateChild(
          childElements[index],
          build(index, popUpList: popUpList),
          ChildSlot(index, popUpList),
        );
      } finally {
        _currentlyUpdatingChildIndex = null;
        _currentlyUpdatingPopUpList = null;
      }
      if (newChild != null) {
        childElements[index] = newChild;
      } else {
        childElements.remove(index);
      }
    });
  }

  /// Copied from [SliverMultiBoxAdaptorElement.removeChild].
  @override
  void removeChild(PopUpList? popUpList, RenderBox child) {
    final index = renderObject.indexOf(child);
    final popUpList =
        (child.parentData! as MultiSliverMultiBoxAdaptorParentData).key;
    assert(_currentlyUpdatingPopUpList == null);
    assert(_currentlyUpdatingChildIndex == null);
    assert(index >= 0);
    owner!.buildScope(this, () {
      final childElements = _childElements[popUpList]!;
      assert(childElements.containsKey(index));
      try {
        _currentlyUpdatingPopUpList = popUpList;
        _currentlyUpdatingChildIndex = index;
        final result = updateChild(
          childElements[index],
          null,
          ChildSlot(index, popUpList),
        );
        assert(result == null);
      } finally {
        _currentlyUpdatingChildIndex = null;
        _currentlyUpdatingPopUpList = null;
      }
      childElements.remove(index);
      assert(!childElements.containsKey(index));
    });
  }

  /// Copied from [SliverMultiBoxAdaptorElement.estimateMaxScrollOffset].
  /// The [SliverMultiBoxAdaptorWidget.estimateMaxScrollOffset] method call
  /// has been removed just now.
  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) {
    return renderObject.extrapolateMaxScrollOffset(
      null,
      firstIndex!,
      lastIndex!,
      leadingScrollOffset!,
      trailingScrollOffset!,
      childCount,
    );
  }

  @override
  int get childCount => _intervalListManager.list.buildCount;

  /// Copied from [SliverMultiBoxAdaptorElement.didAdoptChild].
  /// An assertion has been removed to allow adoption of off-list elements.
  @override
  void didAdoptChild(RenderBox child) {
    if (_creatingDisposableElement) return;
    assert(_currentlyUpdatingChildIndex != null);
    final childParentData =
        child.parentData! as MultiSliverMultiBoxAdaptorParentData;
    childParentData.index = _currentlyUpdatingChildIndex;
    childParentData.key = _currentlyUpdatingPopUpList;
  }

  /// Copied from [SliverMultiBoxAdaptorElement.setDidUnderflow].
  /// The `didUnderflow` variabile is no longer needed.
  @override
  void setDidUnderflow(bool value) {
    // _didUnderflow = value;
  }

  /// Copied from [SliverMultiBoxAdaptorElement.didStartLayout].
  @override
  void didStartLayout(PopUpList? popUpList) {
    assert(debugAssertChildListLocked());
  }

  /// Copied from [SliverMultiBoxAdaptorElement.didFinishLayout].
  // TODO: to be changed; firstChild and lastChild should be used and item index conversion applied.
  @override
  void didFinishLayout(PopUpList? popUpList) {
    assert(debugAssertChildListLocked());
    if (popUpList == null) {
      final firstIndex = _mainChildElements.firstKey() ?? 0;
      final lastIndex = _mainChildElements.lastKey() ?? 0;
      widget.delegate.didFinishLayout(firstIndex, lastIndex);
    }
  }

  /// Copied from [SliverMultiBoxAdaptorElement.debugAssertChildListLocked].
  @override
  bool debugAssertChildListLocked() {
    assert(_currentlyUpdatingChildIndex == null);
    return true;
  }

  //
  // ### RenderObjectElement overrides
  //

  /// Inspired by [SliverMultiBoxAdaptorElement.performRebuild].
  ///
  /// This method is called to process any pending updates (for example, new intervals
  /// have been added, old intervals have changed state, reordering has started, and so on).
  ///
  /// It considers all pending build updates to move each old last rendered child
  /// to its new position.
  ///
  /// It also calls the [AnimatedRenderSliverMultiBoxAdaptor.didChangeDependencies] method
  /// if a dependency has been changed.
  @override
  void performRebuild() {
    listLogBegin('performRebuild');
    for (var e in _intervalListManager.updates) {
      listLogPrint(e.toString());
    }

    if (_didChangeDependencies) {
      renderObject.didChangeDependencies(this);
      _didChangeDependencies = false;
    }

    super.performRebuild();

    assert(_currentlyUpdatingChildIndex == null);
    _currentBeforeChild = null;
    try {
      // moving children will temporary violate the integrity
      renderObject.debugChildIntegrityEnabled = false;

      final results = <PopUpList?, SplayTreeMap<int, _RebuildResult>>{};
      final removeList = <Element>[];

      final newChildrenMap = <PopUpList?, SplayTreeMap<int, Element?>>{};

      Element? update(Element? element, ChildReindexResult r) {
        if (r.needsRebuild) {
          if (r.discardElement && element != null) {
            listLogPrint(
              'updating ${debugElement(element)} discard and update...',
            );
            element = updateChild(
              element,
              null,
              ChildSlot(r.newIndex!, r.popUpList),
            );
          } else {
            listLogPrint('updating ${debugElement(element)} update...');
          }
          _currentlyUpdatingChildIndex = r.newIndex;
          _currentlyUpdatingPopUpList = r.popUpList;
          final widget = build(r.newIndex!, popUpList: r.popUpList)!;
          element = updateChild(
            element,
            widget,
            ChildSlot(r.newIndex!, r.popUpList),
          )!;
          _currentlyUpdatingChildIndex = null;
          _currentlyUpdatingPopUpList = null;
          listLogPrint('    ....updated into ${debugElement(element)}');
        } else {
          assert(!r.discardElement);
          final newSlot = ChildSlot(r.newIndex!, r.popUpList);
          if (newSlot != element?.slot) {
            listLogPrint(
              'updating ${debugElement(element)} slot only: ${element?.slot} -> $newSlot',
            );
          }
          _currentlyUpdatingChildIndex = r.newIndex;
          _currentlyUpdatingPopUpList = r.popUpList;
          updateChild(element, element!.widget, newSlot);
          _currentlyUpdatingChildIndex = null;
          _currentlyUpdatingPopUpList = null;
        }
        return element;
      }

      void considerElements(
        PopUpList? popUpList,
        SplayTreeMap<int, Element?> childElements,
      ) {
        listLogBegin('considering popUpList=${popUpList?.debugId}');
        listLogPrint('children=${_debugChildrenList(childElements)}');
        listLogPrint('renderBoxes=${renderObject.debugRenderBoxes(popUpList)}');
        for (int? index in childElements.keys.toList()) {
          var element = childElements[index]!;

          final r = oldIndexToNewIndex(index!, popUpList);

          if (r.newIndex == null) {
            removeList.add(element);
            listLogPrint(
              'element ${debugElement(element)} scheduled for removing',
            );
          } else {
            listLogPrint(
              'element ${debugElement(element)} from pl(${popUpList?.debugId}):$index -> pl(${r.popUpList?.debugId}}):${r.newIndex}',
            );
            results.putIfAbsent(
              r.popUpList,
              () => SplayTreeMap<int, _RebuildResult>(),
            )[r.newIndex!] = _RebuildResult(
              r,
              element,
            );
          }
        }
        listLogEnd();
      }

      _childElements.forEach((popUpList, elements) {
        results.putIfAbsent(
          popUpList,
          () => SplayTreeMap<int, _RebuildResult>(),
        );
        considerElements(popUpList, elements);
      });

      for (final popUpList in results.keys) {
        final newChildren = newChildrenMap.putIfAbsent(
          popUpList,
          () => SplayTreeMap<int, Element?>(),
        );

        _currentBeforeChild = null;

        listLogBegin('finalizing popUpList=${popUpList?.debugId}');
        for (final index in results[popUpList]!.keys) {
          final rr = results[popUpList]![index]!;
          final r = rr.result;
          var childParentData = _parentDataOf(rr.element);

          if (childParentData != null && r.clearLayoutOffset) {
            listLogPrint(
              'clearing layout offset of ${debugElement(rr.element)}',
            );
            childParentData.layoutOffset = null;
          }

          _currentlyUpdatingChildIndex = r.newIndex;

          final element = update(rr.element, r)!;

          newChildren[r.newIndex!] = element;

          childParentData = _parentDataOf(element);
          if (r.newIndex == 0) {
            childParentData?.layoutOffset = 0.0;
          }

          if (!childParentData!.keptAlive) {
            _currentBeforeChild = element.renderObject as RenderBox?;
          }
        }

        _childElements.putIfAbsent(popUpList, () => newChildren);
        _childElements[popUpList] = newChildren;
        listLogPrint(
          'result childrenList: ${_debugChildrenList(_childElements[popUpList]!)}',
        );

        if (newChildren.isEmpty && popUpList != null) {
          listLogPrint('dismissing popup ${popUpList.debugId}');
          _childElements.remove(popUpList);
        }

        listLogEnd();
      }

      listLogBegin('result RenderBoxes');
      for (final popUpList in results.keys) {
        listLogPrint(
          'popup ${popUpList?.debugId}: ${renderObject.debugRenderBoxes(popUpList)}',
        );
      }
      listLogEnd();

      for (final element in removeList) {
        listLogPrint('removing ${debugElement(element)}');
        final slot = element.slot as ChildSlot;
        _currentlyUpdatingChildIndex = slot.index;
        _currentlyUpdatingPopUpList = slot.popUpList;
        updateChild(element, null, slot);
      }
    } catch (e) {
      listLogPrint('EXCEPTION!!!!');
    } finally {
      _currentlyUpdatingChildIndex = null;
      _currentlyUpdatingPopUpList = null;
      renderObject.debugChildIntegrityEnabled = true;
      _intervalListManager.clearUpdates();
      _delegateChanged = false;
      // renderObject.removeEmptyKeys();
      listLogEnd();
    }
  }

  /// Copied from [SliverMultiBoxAdaptorElement.insertRenderObjectChild].
  /// This method has been changed to prevent inserting off-list elements into the children list.
  @override
  void insertRenderObjectChild(covariant RenderObject child, ChildSlot? slot) {
    if (_creatingDisposableElement) {
      assert(slot == null);
      renderObject.setupParentData(child);
      renderObject.adoptChild(child);
      return;
    }
    assert(_currentlyUpdatingChildIndex == slot!.index);

    renderObject.insert(
      _currentlyUpdatingPopUpList,
      child as RenderBox,
      after: _currentBeforeChild,
    );
    assert(() {
      final childParentData =
          child.parentData! as MultiSliverMultiBoxAdaptorParentData;
      assert(slot!.index == childParentData.index);
      return true;
    }());
  }

  /// Copied from [SliverMultiBoxAdaptorElement.removeRenderObjectChild].
  /// This method has been changed to prevent the removal of unlisted children (eg off-list elements).
  @override
  void removeRenderObjectChild(covariant RenderObject child, ChildSlot? slot) {
    if (_creatingDisposableElement) {
      assert(slot == null);
      renderObject.dropDisposableChild(child);
      return;
    }
    assert(_creatingDisposableElement || _currentlyUpdatingChildIndex != null);
    final childParentData =
        child.parentData! as MultiSliverMultiBoxAdaptorParentData;
    renderObject.remove(childParentData.key, child as RenderBox);
  }

  /// Copied from [SliverMultiBoxAdaptorElement.moveRenderObjectChild].
  /// This method has been changed to prevent assertion errors.
  @override
  void moveRenderObjectChild(
    covariant RenderObject child,
    ChildSlot? oldSlot,
    ChildSlot? newSlot,
  ) {
    assert(newSlot != null);
    assert(_currentlyUpdatingChildIndex == newSlot!.index);
    assert(_currentlyUpdatingPopUpList == newSlot!.popUpList);
    renderObject.move(
      newSlot!.popUpList,
      child as RenderBox,
      after: _currentBeforeChild,
    );
  }

  //
  // ### Element overrides
  //

  /// Copied from [SliverMultiBoxAdaptorElement.updateChild].
  @override
  Element? updateChild(Element? child, Widget? newWidget, dynamic newSlot) {
    final oldParentData = _parentDataOf(child);
    final newChild = super.updateChild(child, newWidget, newSlot);
    final newParentData = _parentDataOf(newChild);

    // Preserve the old layoutOffset if the renderObject was swapped out.
    if (oldParentData != newParentData &&
        oldParentData != null &&
        newParentData != null) {
      newParentData.layoutOffset = oldParentData.layoutOffset;
    }
    return newChild;
  }

  /// Copied from [SliverMultiBoxAdaptorElement.forgetChild].
  @override
  void forgetChild(Element child) {
    assert(child.slot != null);
    final popUpList = _parentDataOf(child)!.key;
    final childElements = _childElements[popUpList]!;
    assert(childElements.containsKey(child.slot));
    childElements.remove(child.slot);
    super.forgetChild(child);
  }

  /// Copied from [SliverMultiBoxAdaptorElement.visitChildren].
  /// This method has been changed to include pop-up elements.
  @override
  void visitChildren(ElementVisitor visitor) {
    _childElements.values
        .expand((l) => l.values)
        .toList()
        .forEach((e) => visitor.call(e!));
  }

  /// Copied from [SliverMultiBoxAdaptorElement.debugVisitOnstageChildren].
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    _mainChildElements.values
        .cast<Element>()
        .where((Element child) {
          final parentData = _parentDataOf(child)!;
          late double itemExtent;
          switch (renderObject.constraints.axis) {
            case Axis.horizontal:
              itemExtent = child.renderObject!.paintBounds.width;
              break;
            case Axis.vertical:
              itemExtent = child.renderObject!.paintBounds.height;
              break;
          }

          return parentData.layoutOffset != null &&
              parentData.layoutOffset! <
                  renderObject.constraints.scrollOffset +
                      renderObject.constraints.remainingPaintExtent &&
              parentData.layoutOffset! + itemExtent >
                  renderObject.constraints.scrollOffset;
        })
        .forEach(visitor);
  }

  // Searchs and returns the build index of specified item by its [context], if it can be found.
  @override
  ChildSlot? buildIndexFromContext(BuildContext context) {
    if (context is! Element) return null;
    ChildSlot? slot;
    if (context.slot is! ChildSlot) {
      context.visitAncestorElements((element) {
        if (element is AnimatedSliverMultiBoxAdaptorElement) return false;
        if (element.slot is ChildSlot) {
          slot = element.slot as ChildSlot;
          return false;
        }
        return true;
      });
      if (slot == null || slot is! ChildSlot) return null;
    } else {
      slot = context.slot as ChildSlot;
    }
    assert(() {
      AnimatedSliverMultiBoxAdaptorElement? e;
      context.visitAncestorElements((element) {
        if (element is AnimatedSliverMultiBoxAdaptorElement) {
          e = element;
          return false;
        }
        return true;
      });
      return e != null && e == this;
    }());
    return slot;
  }

  var _creatingDisposableElement = false;

  /// It creates an disposable off-list element built with the specified [widget],
  /// and executes the [callback]. Eventually, the child is disposed.
  @override
  void disposableElement(Widget widget, void Function(RenderBox) callback) {
    owner!.lockState(() {
      _currentlyUpdatingChildIndex = null;
      _currentlyUpdatingPopUpList = null;
      _creatingDisposableElement = true;
      var measuringOffListChild = updateChild(null, widget, null);
      assert(measuringOffListChild != null);
      callback.call(measuringOffListChild!.renderObject! as RenderBox);
      measuringOffListChild = updateChild(measuringOffListChild, null, null);
      _creatingDisposableElement = false;
      assert(measuringOffListChild == null);
    });
  }

  //
  // ListIntervalInterface implementation
  //

  @override
  AnimatedSliverChildDelegate get delegate => widget.delegate;

  @override
  bool get isHorizontal => renderObject.constraints.axis == Axis.horizontal;

  @override
  Widget wrapWidget(
    AnimatedWidgetBuilder builder,
    int index,
    AnimatedWidgetBuilderData data, [
    bool map = true,
  ]) {
    Widget child;
    try {
      child = builder.call(this, index, data);
    } catch (exception, stackTrace) {
      child = _createErrorWidget(exception, stackTrace);
    }
    return widget.delegate.wrapWidget(this, child, data);
  }

  /// Notifies that the resizing interval has changed its size by the delta amount.
  @override
  void resizingIntervalUpdated(AnimatedSpaceInterval interval, double delta) {
    renderObject.resizingIntervalUpdated(interval, delta);
  }

  /// Measures the size of a bunch of off-list children up to [count] elements.
  /// You have to provide a [builder] to build the `i`-th widget.
  /// The calculation is asynchronous and can be [cancelled].
  @override
  Future<ItemMeasure> measureItems(
    Cancelled? cancelled,
    int count,
    IndexedWidgetBuilder builder, [
    double startingSize = 0,
    int startingCount = 0,
  ]) async {
    return await renderObject.measureItems(
      cancelled,
      count,
      builder,
      startingSize,
      startingCount,
    );
  }

  /// Measures the size of the [widget].
  @override
  double measureItem(Widget widget) {
    return renderObject.measureItem(widget);
  }

  @override
  void markNeedsLayout() {
    renderObject.markSafeNeedsLayout();
  }

  @override
  ItemSizeRange? getItemSizesFromSliverList(int buildFrom, int buildTo) {
    return renderObject.getItemSizesFromSliverList(buildFrom, buildTo);
  }

  //
  // _ControllerInterface implementation
  //

  int _batch = 0;

  /// See [AnimatedListController.batch].
  @override
  void batch(VoidCallback callback) {
    _batch++;
    callback();
    _batch--;
    assert(_batch >= 0);
    if (_batch == 0) _intervalListManager.coordinate();
  }

  /// See [AnimatedListController.notifyInsertedRange].
  @override
  void notifyInsertedRange(int from, int count) =>
      _notifyReplacedRange(from, 0, count, null);

  /// See [AnimatedListController.notifyRemovedRange].
  @override
  void notifyRemovedRange(
    int from,
    int count,
    AnimatedWidgetBuilder removedItemBuilder,
  ) => _notifyReplacedRange(from, count, 0, removedItemBuilder);

  /// See [AnimatedListController.notifyReplacedRange].
  @override
  void notifyReplacedRange(
    int from,
    int removeCount,
    int insertCount,
    AnimatedWidgetBuilder removedItemBuilder,
  ) => _notifyReplacedRange(from, removeCount, insertCount, removedItemBuilder);

  void _notifyReplacedRange(
    int from,
    int removeCount,
    int insertCount,
    AnimatedWidgetBuilder? removedItemBuilder,
  ) {
    _intervalListManager.notifyReplacedRange(
      from,
      removeCount,
      insertCount,
      removedItemBuilder,
    );
    if (_batch == 0) _intervalListManager.coordinate();
  }

  /// See [AnimatedListController.notifyChangedRange].
  @override
  void notifyChangedRange(
    int from,
    int count,
    AnimatedWidgetBuilder changedItemBuilder,
  ) {
    _intervalListManager.notifyChangedRange(from, count, changedItemBuilder);
    if (_batch == 0) _intervalListManager.coordinate();
  }

  /// See [AnimatedListController.notifyMovedRange].
  @override
  void notifyMovedRange(int from, int count, int newIndex) {
    _intervalListManager.notifyMovedRange(from, count, newIndex);
    if (_batch == 0) _intervalListManager.coordinate();
  }

  /// See [AnimatedListController.notifyStartReorder].
  @override
  bool notifyStartReorder(BuildContext context, double dx, double dy) {
    return renderObject.reorderStart(context, dx, dy);
  }

  /// See [AnimatedListController.notifyUpdateReorder].
  @override
  void notifyUpdateReorder(double dx, double dy) {
    renderObject.reorderUpdate(dx, dy);
  }

  /// See [AnimatedListController.notifyStopReorder].
  @override
  void notifyStopReorder(bool cancel) {
    renderObject.reorderStop(cancel);
  }

  /// See [AnimatedListController.computeItemBox].
  @override
  Rect? computeItemBox(int index, bool absolute) {
    return renderObject.computeItemBox(index, absolute, false);
  }

  /// See [AnimatedListController.getItemVisibleSize].
  @override
  AnimatedListItemVisibility? getItemVisibleSize(int index) {
    final box = renderObject.computeItemBox(index, true, true);
    if (box != null) {
      final c = renderObject.constraints;
      final v1 =
          c.scrollOffset +
          c.precedingScrollExtent -
          (c.viewportMainAxisExtent - c.remainingPaintExtent);
      final v2 = v1 + c.viewportMainAxisExtent;

      final r1 = (isHorizontal ? box.left : box.top).clamp(v1, v2);
      final r2 = (isHorizontal ? box.right : box.bottom).clamp(v1, v2);
      return AnimatedListItemVisibility(
        math.max(0.0, r2 - r1),
        (isHorizontal ? box.width : box.height),
      );
    }
    return null;
  }

  @override
  ItemMeasure estimateLayoutOffset(
    int buildIndex,
    int childCount, {
    double? time,
    MovingPopUpList? popUpList,
  }) {
    return renderObject.estimateLayoutOffset(
      buildIndex,
      childCount,
      time,
      popUpList,
    );
  }

  @override
  RenderBox? renderBoxAt(int buildIndex) =>
      _childElements[null]?[buildIndex]?.renderObject as RenderBox?;

  @override
  void reorderCancel() => renderObject.reorderStop(true);

  @override
  List<PopUpList> get listOfPopUps => _intervalListManager.listOfPopUps;
}

/*
 *
 */

// Returns a Widget for the given Exception (copied from the standard package).
Widget _createErrorWidget(Object exception, StackTrace stackTrace) {
  final details = FlutterErrorDetails(
    exception: exception,
    stack: stackTrace,
    library: 'widgets library',
    context: ErrorDescription('building'),
  );
  FlutterError.reportError(details);
  return ErrorWidget.builder(details);
}

class _RebuildResult {
  final ChildReindexResult result;
  final Element element;

  PopUpList? get toPopUpList => result.popUpList;

  const _RebuildResult(this.result, this.element);
}
