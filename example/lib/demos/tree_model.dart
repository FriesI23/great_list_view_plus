import 'package:great_list_view_plus/great_list_view_plus.dart';

/// Application data, independent of any tree widget or adapter base class.
class DemoNode {
  DemoNode(this.id, this.label);

  final int id;
  final String label;
  DemoNode? parent;
  final children = <DemoNode>[];
  bool expanded = true;

  void insert(DemoNode child, [int? index]) {
    child.parent = this;
    children.insert(index ?? children.length, child);
  }
}

DemoNode createDemoTree() {
  final root = DemoNode(0, 'Workspace');
  final projects = DemoNode(1, 'Projects');
  final flutter = DemoNode(2, 'Flutter');
  flutter.insert(DemoNode(3, 'List animations'));
  flutter.insert(DemoNode(4, 'Tree adapter'));
  projects.insert(flutter);
  projects.insert(DemoNode(5, 'Website'));
  final notes = DemoNode(6, 'Notes');
  notes.insert(DemoNode(7, 'Ideas'));
  notes.insert(DemoNode(8, 'Reading'));
  root.insert(projects);
  root.insert(notes);
  root.insert(DemoNode(9, 'Archive'));
  return root;
}

TreeListAdapter<DemoNode> createTreeAdapter(
  DemoNode root, {
  AnimatedListController? controller,
  AnimatedListTreeBuilder<DemoNode>? builder,
}) => TreeListAdapter<DemoNode>(
  root: root,
  parentOf: (node) => node.parent ?? root,
  childrenCount: (node) => node.children.length,
  childAt: (node, index) => node.children[index],
  isNodeExpanded: (node) => node.expanded,
  indexOfChild: (parent, node) => parent.children.indexOf(node),
  equals: (a, b) => a.id == b.id,
  controller: controller,
  builder: builder,
);
