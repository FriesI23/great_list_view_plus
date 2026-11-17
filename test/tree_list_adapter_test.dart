import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() {
  for (final includeRoot in [true, false]) {
    group('includeRoot=$includeRoot', () {
      test('multi-level mapping traverses both ends of a small cache', () {
        final tree = _Tree(includeRoot: includeRoot);
        tree.check();
        final indices = [tree.adapter.count - 1, 0, 5, 2, 8, 1, 6];
        for (final index in indices) {
          final node = tree.visible[index];
          expect(tree.adapter.indexToNode(index), same(node));
          expect(tree.adapter.nodeToIndex(node), index);
          expect(
            tree.adapter.levelOf(node),
            tree.depth(node) - (includeRoot ? 0 : 1),
          );
        }
        tree.check();
      });

      test(
        'collapse, expand, insertion and subtree removal invalidate caches',
        () {
          final tree = _Tree(includeRoot: includeRoot);
          tree.check();
          final branch = tree.nodes[1];
          final hidden = tree.nodes[3];
          final collapsed = tree.adapter.notifyNodeCollapsing(
            branch,
            () => branch.expanded = false,
          );
          expect(collapsed!.length, 4);
          expect(tree.adapter.nodeToIndex(hidden), isNull);
          tree.check();
          tree.adapter.notifyNodeExpanding(
            branch,
            () => branch.expanded = true,
          );
          tree.check();

          final child = _Node(20)..add(_Node(21));
          tree.adapter.notifyNodeInserting(
            child,
            branch,
            1,
            () => branch.add(child, 1),
          );
          tree.check();
          expect(tree.adapter.nodeToIndex(child.children.single), isNotNull);
          tree.adapter.notifyNodeRemoving(
            child,
            () => branch.children.remove(child),
          );
          tree.check();
          expect(tree.adapter.nodeToIndex(child), isNull);
        },
      );

      test('hidden insertion appears when the parent is expanded', () {
        final tree = _Tree(includeRoot: includeRoot);
        tree.check();
        final branch = tree.nodes[1];
        tree.adapter.notifyNodeCollapsing(
          branch,
          () => branch.expanded = false,
        );
        final count = tree.adapter.count;
        final child = _Node(20);
        tree.adapter.notifyNodeInserting(
          child,
          branch,
          0,
          () => branch.add(child, 0),
        );
        expect(tree.adapter.count, count);
        expect(tree.adapter.nodeToIndex(child), isNull);
        tree.adapter.notifyNodeExpanding(branch, () => branch.expanded = true);
        tree.check();
      });

      test('same-parent and cross-parent moves preserve node ownership', () {
        final tree = _Tree(includeRoot: includeRoot);
        tree.check();
        final moved = tree.nodes[3];
        final sibling = tree.nodes[4];
        var from = tree.adapter.nodeToIndex(moved)!;
        var to = tree.adapter.nodeToIndex(sibling)!;
        tree.move(from, to, tree.adapter.levelOf(moved));
        expect(moved.parent, same(sibling.parent));
        expect(moved.parent!.children.last, same(moved));
        tree.check();

        tree.move(
          tree.adapter.nodeToIndex(moved)!,
          tree.adapter.nodeToIndex(sibling)!,
          tree.adapter.levelOf(moved),
        );
        expect(moved.parent!.children.first, same(moved));
        tree.check();

        // Drop the leaf into the expanded second root branch.
        from = tree.adapter.nodeToIndex(moved)!;
        final newParent = tree.nodes[6];
        final parentIndex = tree.adapter.nodeToIndex(newParent)!;
        to = parentIndex + (from > parentIndex ? 1 : 0);
        final level = tree.adapter.levelOf(newParent) + 1;
        expect(
          tree.adapter.getPossibleLevelsOfMove(from, to).isIn(level),
          isTrue,
        );
        tree.move(from, to, level);
        expect(moved.parent, same(newParent));
        expect(newParent.children.first, same(moved));
        tree.check();
      });

      test(
        'collapsed subtree moves as a unit and expands in its new location',
        () {
          final tree = _Tree(includeRoot: includeRoot);
          tree.check();
          final branch = tree.nodes[2];
          tree.adapter.notifyNodeCollapsing(
            branch,
            () => branch.expanded = false,
          );
          final parent = tree.nodes[6];
          tree.move(
            tree.adapter.nodeToIndex(branch)!,
            tree.adapter.nodeToIndex(parent)! + 1,
            tree.adapter.levelOf(parent) + 1,
          );
          tree.check();
          expect(tree.nodes[3].parent, same(branch));
          tree.adapter.notifyNodeExpanding(
            branch,
            () => branch.expanded = true,
          );
          tree.check();
          expect(
            tree.adapter.levelOf(tree.nodes[3]),
            tree.adapter.levelOf(parent) + 2,
          );
        },
      );

      test('subtree keeps levels and a replaced root clears cached nodes', () {
        final tree = _Tree(includeRoot: includeRoot);
        tree.check();
        final node = tree.nodes[2];
        final sub = tree.adapter.subTreeOf(node, true, true, true, 2);
        expect(sub.count, 3);
        expect(sub.indexToNode(2), same(tree.nodes[4]));
        expect(sub.levelOf(node), tree.adapter.levelOf(node));
        final replacement = _Node(30)..add(_Node(31));
        tree.adapter.notifyTreeChanged(replacement);
        expect(tree.adapter.count, includeRoot ? 2 : 1);
        expect(tree.adapter.indexToNode(tree.adapter.count - 1).id, 31);
        expect(tree.adapter.nodeToIndex(tree.nodes[3]), isNull);
      });
    });
  }

  test(
    'cross-parent move refreshes parents at their final visible indices',
    () {
      final controller = _RecordingController();
      final tree = _Tree(controller: controller);
      tree.check();
      final moved = tree.nodes[3];
      final oldParent = moved.parent!;
      final newParent = tree.nodes[6];
      tree.adapter.notifyNodeMoving(
        tree.adapter.nodeToIndex(moved)!,
        tree.adapter.nodeToIndex(newParent)!,
        tree.adapter.levelOf(newParent) + 1,
        (parent, node) => parent.children.remove(node),
        (parent, node, index) => parent.add(node, index),
        updateParentNodes: true,
      );
      tree.check();
      expect(controller.changed, [
        tree.adapter.nodeToIndex(oldParent),
        tree.adapter.nodeToIndex(newParent),
      ]);
    },
  );

  test(
    'expanded branches cannot move and visible root cannot be a drop target',
    () {
      final tree = _Tree();
      tree.check();
      expect(
        () => tree.adapter.getPossibleLevelsOfMove(1, 6),
        throwsAssertionError,
      );
      expect(
        () => tree.adapter.getPossibleLevelsOfMove(3, 0),
        throwsAssertionError,
      );
      expect(() => tree.move(3, 4, 99), throwsAssertionError);
      tree.check();
    },
  );
}

class _Node {
  _Node(this.id);
  final int id;
  _Node? parent;
  final children = <_Node>[];
  bool expanded = true;

  void add(_Node node, [int? index]) {
    node.parent = this;
    children.insert(index ?? children.length, node);
  }
}

class _Tree {
  _Tree({bool includeRoot = true, AnimatedListController? controller}) {
    nodes[0].add(nodes[1]);
    nodes[1].add(nodes[2]);
    nodes[2].add(nodes[3]);
    nodes[2].add(nodes[4]);
    nodes[1].add(nodes[5]);
    nodes[0].add(nodes[6]);
    nodes[6].add(nodes[7]);
    nodes[6].add(nodes[8]);
    nodes[0].add(nodes[9]);
    adapter = TreeListAdapter<_Node>(
      root: nodes[0],
      parentOf: (node) => node.parent ?? adapter.root,
      childrenCount: (node) => node.children.length,
      childAt: (node, index) => node.children[index],
      isNodeExpanded: (node) => node.expanded,
      indexOfChild: (parent, node) => parent.children.indexOf(node),
      includeRoot: includeRoot,
      windowSize: 3,
      controller: controller,
      builder: (context, adapter, index, data) => const SizedBox(),
    );
  }

  final nodes = List.generate(10, _Node.new);
  late final TreeListAdapter<_Node> adapter;

  List<_Node> get visible {
    final result = <_Node>[];
    void visit(_Node node) {
      result.add(node);
      if (node.expanded) {
        for (final child in node.children) {
          visit(child);
        }
      }
    }

    visit(adapter.root);
    if (!adapter.includeRoot) result.removeAt(0);
    return result;
  }

  int depth(_Node node) => node.parent == null ? 0 : depth(node.parent!) + 1;

  void check() {
    final expected = visible;
    expect(adapter.count, expected.length);
    for (final i in List.generate(expected.length, (i) => i).reversed) {
      expect(adapter.indexToNode(i), same(expected[i]));
      expect(adapter.nodeToIndex(expected[i]), i);
    }
  }

  void move(int from, int to, int level) => adapter.notifyNodeMoving(
    from,
    to,
    level,
    (parent, node) => parent.children.remove(node),
    (parent, node, index) => parent.add(node, index),
  );
}

class _RecordingController extends AnimatedListController {
  final changed = <int>[];

  @override
  void batch(VoidCallback callback) => callback();

  @override
  void notifyChangedRange(int from, int count, AnimatedWidgetBuilder builder) {
    changed.add(from);
  }
}
