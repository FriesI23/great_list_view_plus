import 'package:flutter/widgets.dart';

import '../list/interval_model.dart';
import 'sliver_multi_box_adaptor.dart';

class ChildReindexResult {
  const ChildReindexResult(
    this.newIndex,
    this.needsRebuild,
    this.discardElement,
    this.clearLayoutOffset,
    this.popUpList,
  ); //, this.droppedBy);

  /// The new index of the child.
  final int? newIndex;

  /// Marks the child as to be rebuilt.
  final bool needsRebuild;

  /// Marks the child as to be rebuilt as new, discarding its previous [Element].
  final bool discardElement;

  /// Marks to invalidate its current layout offset (especially used by new resizing intervals in order
  /// to forget the layout offset of the previously built child, to avoid annoying scroll jumps when
  /// these intervals are not accurately measured).
  final bool clearLayoutOffset;

  /// La [PopUpList] nella quale il child ricadrà a valle degli update.
  final PopUpList? popUpList;

  @override
  String toString() =>
      '(${['newIndex=$newIndex', if (needsRebuild) 'NEEDS_REBUILD', if (discardElement) 'discardElement', if (clearLayoutOffset) 'clearLayoutOffset', if (popUpList != null) 'popUpList=$popUpList'].join(', ')})';
}

class ChildSlot {
  final int index;
  final PopUpList? popUpList;

  const ChildSlot(this.index, this.popUpList);

  @override
  bool operator ==(Object other) =>
      other is ChildSlot &&
      other.index == index &&
      other.popUpList == popUpList;

  @override
  int get hashCode => popUpList.hashCode ^ index;

  @override
  String toString() => '($index,${popUpList?.debugId})';
}

/// The capabilities needed by sliver layout, independent of a concrete Element.
abstract interface class AnimatedSliverChildManager
    implements ListIntervalHost, MultiRenderSliverBoxChildManager {
  Iterable<PopUpList> get managedPopUpLists;
  ChildSlot? buildIndexFromContext(BuildContext context);
  ChildReindexResult oldIndexToNewIndex(int? index, PopUpList? popUpList);
  RenderBox? renderBoxAt(int index);
  void disposableElement(Widget widget, void Function(RenderBox) callback);
  Widget? build(int index, {bool measureOnly = false, PopUpList? popUpList});
}
