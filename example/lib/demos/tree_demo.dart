import 'package:great_list_view_plus/great_list_view_plus.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_widgets.dart';
import 'tree_model.dart';

class TreeDemoPage extends StatefulWidget {
  const TreeDemoPage({super.key});

  @override
  State<TreeDemoPage> createState() => TreeDemoPageState();
}

class TreeDemoPageState extends State<TreeDemoPage> {
  final _controller = AnimatedListController();
  final _animatedScroll = ScrollController();
  final _plainScroll = ScrollController();
  late DemoNode _root;
  late DemoNode _selected;
  late TreeListAdapter<DemoNode> _adapter;
  bool _animated = true;
  bool _dragging = false;
  int _nextId = 10;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _root = createDemoTree();
    _selected = _root;
    _createAdapter();
  }

  void _createAdapter() {
    _adapter = createTreeAdapter(
      _root,
      controller: _animated ? _controller : null,
      builder: _animated ? _buildRow : null,
    );
  }

  void cancelDrag() {
    if (!_dragging) return;
    _controller.notifyStopReorder(true);
    _dragging = false;
  }

  @override
  void dispose() {
    _animatedScroll.dispose();
    _plainScroll.dispose();
    super.dispose();
  }

  void _toggle(DemoNode node) {
    if (node == _root || node.children.isEmpty) return;
    cancelDrag();
    setState(() {
      if (node.expanded) {
        _adapter.notifyNodeCollapsing(
          node,
          () => node.expanded = false,
          updateNode: true,
        );
        // Keep selection visible when its ancestor is collapsed.
        if (_adapter.nodeToIndex(_selected) == null) _selected = node;
      } else {
        _adapter.notifyNodeExpanding(
          node,
          () => node.expanded = true,
          updateNode: true,
        );
      }
    });
  }

  void _add() {
    cancelDrag();
    final parent = _selected;
    if (!parent.expanded) _toggle(parent);
    setState(() {
      final child = DemoNode(_nextId, 'New node ${_nextId++}');
      _adapter.notifyNodeInserting(
        child,
        parent,
        parent.children.length,
        () => parent.insert(child),
        updateParentNode: true,
      );
      _selected = child;
    });
  }

  void _remove() {
    if (_selected == _root) return;
    cancelDrag();
    setState(() {
      final node = _selected;
      final parent = node.parent!;
      _adapter.notifyNodeRemoving(
        node,
        () => parent.children.remove(node),
        updateParentNode: true,
      );
      // Retain the detached node's parent reference for its outgoing builder.
      _selected = parent;
    });
  }

  void _reset() {
    cancelDrag();
    setState(() {
      _root = createDemoTree();
      _selected = _root;
      _nextId = 10;
      _generation++;
      _createAdapter();
    });
  }

  AnimatedListReorderModel get _reorderModel => AnimatedListReorderModel(
    onReorderStart: (index, dx, dy) {
      if (index == 0) return false;
      final node = _adapter.indexToNode(index);
      if (!_adapter.isLeaf(node) && node.expanded) {
        _toggle(node);
        return false;
      }
      _dragging = true;
      return true;
    },
    onReorderMove: (from, to) => to != 0,
    onReorderFeedback: (from, to, offset, dx, dy) {
      final level = _adapter.levelOf(_adapter.indexToNode(from));
      if (to == 0) return level;
      final levels = _adapter.getPossibleLevelsOfMove(from, to);
      return (level + dx ~/ 24).clamp(levels.from, levels.to - 1);
    },
    onReorderComplete: (from, to, slot) {
      _dragging = false;
      if (to == 0) return false;
      final levels = _adapter.getPossibleLevelsOfMove(from, to);
      final level = slot is int
          ? slot
          : _adapter.levelOf(_adapter.indexToNode(from));
      if (!levels.isIn(level)) return false;
      _adapter.notifyNodeMoving(
        from,
        to,
        level,
        (parent, node) => parent.children.remove(node),
        (parent, node, index) => parent.insert(node, index),
        updateParentNodes: true,
      );
      // Reorder completion supplies the movement notification itself.
      setState(() {});
      return true;
    },
  );

  Widget _buildRow(
    BuildContext context,
    TreeListAdapter<DemoNode> adapter,
    int index,
    AnimatedWidgetBuilderData data,
  ) {
    if (data.measuring) return const SizedBox(height: 56);
    final node = adapter.indexToNode(index);
    final level = data.dragging && data.slot is int
        ? data.slot! as int
        : adapter.levelOf(node);
    final selected = node == _selected;
    return SizedBox(
      key: ValueKey('tree-node-${node.id}'),
      height: 56,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: 12 + level * 24.0, end: 12),
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selected = node),
            child: Row(
              children: [
                if (node == _root)
                  const SizedBox(width: 48, child: Icon(Icons.account_tree))
                else if (node.children.isNotEmpty)
                  ArrowButton(
                    key: ValueKey('tree-arrow-${node.id}'),
                    expanded: node.expanded,
                    onTap: (_) => _toggle(node),
                  )
                else
                  const SizedBox(
                    width: 48,
                    child: Icon(Icons.description_outlined, size: 20),
                  ),
                Expanded(
                  child: Text(
                    node.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${node.children.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scroll = _animated ? _animatedScroll : _plainScroll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoToolbar(
          children: [
            const Text('Tree host'),
            DropdownButton<bool>(
              value: _animated,
              items: const [
                DropdownMenuItem(value: true, child: Text('Animated list')),
                DropdownMenuItem(value: false, child: Text('Plain ListView')),
              ],
              onChanged: (value) {
                if (value == null || value == _animated) return;
                cancelDrag();
                setState(() {
                  _animated = value;
                  _createAdapter();
                });
              },
            ),
          ],
        ),
        DemoToolbar(
          children: [
            FilledButton(onPressed: _add, child: const Text('Add child')),
            OutlinedButton(
              onPressed: _selected == _root ? null : _remove,
              child: const Text('Delete subtree'),
            ),
            TextButton(onPressed: _reset, child: const Text('Reset tree')),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            _animated
                ? 'Select a node to edit. Long press to reorder; drag sideways to change parent. An open branch closes on its first long press.'
                : 'The same callback model feeds a regular ListView. Select, expand and edit nodes; reordering is available in Animated list.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: scroll,
            child: _animated
                ? AnimatedListView(
                    key: ValueKey('animated-tree-$_generation'),
                    listController: _controller,
                    scrollController: scroll,
                    initialItemCount: _adapter.count,
                    itemExtent: 56,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index, data) =>
                        _buildRow(context, _adapter, index, data),
                    reorderModel: _reorderModel,
                  )
                : ListView.builder(
                    key: ValueKey('plain-tree-$_generation'),
                    controller: scroll,
                    itemCount: _adapter.count,
                    itemExtent: 56,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) => _buildRow(
                      context,
                      _adapter,
                      index,
                      const AnimatedWidgetBuilderData(
                        AlwaysStoppedAnimation(1),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
