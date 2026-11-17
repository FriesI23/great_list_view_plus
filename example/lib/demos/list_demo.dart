import 'package:great_list_view_plus/great_list_view_plus.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_widgets.dart';

enum _Mode { automatic, manual, sliver }

class ListDemoPage extends StatefulWidget {
  const ListDemoPage({super.key});

  @override
  State<ListDemoPage> createState() => ListDemoPageState();
}

class ListDemoPageState extends State<ListDemoPage> {
  final _keys = List.generate(3, (_) => GlobalKey<_ListDemoState>());
  _Mode _mode = _Mode.automatic;

  void cancelDrag() => _keys[_mode.index].currentState?.cancelDrag();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoToolbar(
        children: [
          const Text('List mode'),
          DropdownButton<_Mode>(
            value: _mode,
            items: const [
              DropdownMenuItem(
                value: _Mode.automatic,
                child: Text('Automatic'),
              ),
              DropdownMenuItem(value: _Mode.manual, child: Text('Manual')),
              DropdownMenuItem(value: _Mode.sliver, child: Text('Sliver')),
            ],
            onChanged: (mode) {
              if (mode == null || mode == _mode) return;
              cancelDrag();
              setState(() => _mode = mode);
            },
          ),
        ],
      ),
      Expanded(
        child: IndexedStack(
          index: _mode.index,
          children: [
            for (final mode in _Mode.values)
              TickerMode(
                enabled: mode == _mode,
                child: _ListDemo(key: _keys[mode.index], mode: mode),
              ),
          ],
        ),
      ),
    ],
  );
}

class _ListDemo extends StatefulWidget {
  const _ListDemo({super.key, required this.mode});

  final _Mode mode;

  @override
  State<_ListDemo> createState() => _ListDemoState();
}

class _ListDemoState extends State<_ListDemo> {
  final _controller = AnimatedListController();
  final _scrollController = ScrollController();
  final _indexInput = TextEditingController(text: '10');
  final _first = List.of(_firstItems);
  final _second = List.of(_secondItems);
  late List<_Item> _items = _first;
  late final AnimatedListDiffListDispatcher<_Item> _dispatcher;
  bool _firstSelected = true;
  bool _morph = true;
  bool _handles = false;
  bool _fixedExtent = false;
  bool _slow = false;
  bool _dragging = false;
  bool _dispatching = false;
  int _nextId = 100;

  @override
  void initState() {
    super.initState();
    _dispatcher = AnimatedListDiffListDispatcher<_Item>(
      controller: _controller,
      currentList: _items,
      itemBuilder: _buildItem,
      comparator: _comparator,
    );
  }

  void cancelDrag() {
    if (!_dragging) return;
    _controller.notifyStopReorder(true);
    _dragging = false;
  }

  void _configure(VoidCallback update) {
    cancelDrag();
    setState(update);
  }

  @override
  void dispose() {
    _dispatcher.discard();
    _scrollController.dispose();
    _indexInput.dispose();
    super.dispose();
  }

  Future<void> _swap() async {
    cancelDrag();
    _firstSelected = !_firstSelected;
    final next = _firstSelected ? _first : _second;
    if (widget.mode == _Mode.sliver) {
      setState(() {
        _dispatching = true;
        _items = next;
      });
      try {
        await _dispatcher.dispatchNewList(next, detectMoves: true);
      } finally {
        if (mounted) setState(() => _dispatching = false);
      }
    } else {
      setState(() => _items = next);
    }
  }

  // Manual notifications must retain the old objects for outgoing builders.
  void _edit(String action) {
    cancelDrag();
    final old = List.of(_items);
    Widget oldBuilder(
      BuildContext context,
      int index,
      AnimatedWidgetBuilderData data,
    ) => _buildItem(context, old[index], data);
    setState(() {
      switch (action) {
        case 'Insert':
          _items.insert(0, _Item(_nextId++, Colors.teal));
          _controller.notifyInsertedRange(0, 1);
        case 'Change':
          if (_items.isEmpty) return;
          final item = _items[0];
          _items[0] = _Item(item.id, Colors.pink, item.height == 64 ? 104 : 64);
          _controller.notifyChangedRange(0, 1, oldBuilder);
        case 'Remove':
          if (_items.isEmpty) return;
          _items.removeAt(0);
          _controller.notifyRemovedRange(0, 1, oldBuilder);
        case 'Replace':
          if (_items.isEmpty) return;
          _items.replaceRange(0, 1, [
            _Item(_nextId++, Colors.orange),
            _Item(_nextId++, Colors.teal),
          ]);
          _controller.notifyReplacedRange(0, 1, 2, oldBuilder);
        case 'Move range':
          if (_items.length < 4) return;
          final moved = _items.sublist(0, 2);
          _items.removeRange(0, 2);
          _items.insertAll(2, moved);
          _controller.notifyMovedRange(0, 2, 2);
        case 'Batch':
          _controller.batch(() {
            _items.insert(0, _Item(_nextId++, Colors.teal));
            _controller.notifyInsertedRange(0, 1);
            _items.add(_Item(_nextId++, Colors.orange));
            _controller.notifyInsertedRange(_items.length - 1, 1);
          });
      }
    });
  }

  void _scrollToIndex() {
    final index = int.tryParse(_indexInput.text);
    String? error;
    if (index == null || index < 0 || index >= _items.length) {
      error = 'Enter an index from 0 to ${_items.length - 1}.';
    } else {
      final box = _controller.computeItemBox(index, true);
      if (box == null) {
        error = 'Layout is updating. Try again after the animation.';
      } else {
        _scrollController.animateTo(
          box.top.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _buildItem(
    BuildContext context,
    _Item item,
    AnimatedWidgetBuilderData data,
  ) {
    final height = _fixedExtent ? 64.0 : item.height;
    if (data.measuring) return SizedBox(height: height);
    return _ItemRow(
      key: ValueKey('${widget.mode.name}-item-${item.id}'),
      item: item,
      height: height,
      handle: _handles
          ? ReorderHandle(
              controller: _controller,
              onStarted: () => _dragging = true,
              onFinished: () => _dragging = false,
            )
          : null,
    );
  }

  AnimatedListBaseReorderModel get _reorderModel => AnimatedListReorderModel(
    onReorderStart: (index, dx, dy) {
      _dragging = true;
      return true;
    },
    onReorderComplete: (from, to, slot) {
      _dragging = false;
      _items.insert(to, _items.removeAt(from));
      return true;
    },
    onReorderMove: (from, to) => true,
  );

  AnimatedListAnimator get _animator => _slow
      ? const DefaultAnimatedListAnimator(
          dismissIncomingDuration: Duration(milliseconds: 900),
          resizeDuration: Duration(milliseconds: 900),
          movingDuration: Duration(milliseconds: 900),
          reorderDuration: Duration(milliseconds: 450),
          dismissIncomingCurve: Curves.easeInOutCubic,
        )
      : const DefaultAnimatedListAnimator();

  @override
  Widget build(BuildContext context) {
    final manual = widget.mode == _Mode.manual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoToolbar(
          children: [
            if (manual)
              for (final action in [
                'Insert',
                'Change',
                'Remove',
                'Replace',
                'Move range',
                'Batch',
              ])
                OutlinedButton(
                  onPressed: () => _edit(action),
                  child: Text(action),
                )
            else
              FilledButton(
                onPressed: _dispatching ? null : _swap,
                child: Text(
                  widget.mode == _Mode.sliver
                      ? 'Dispatch new list'
                      : 'Switch data',
                ),
              ),
            SizedBox(
              width: 76,
              child: TextField(
                controller: _indexInput,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Index'),
                onSubmitted: (_) => _scrollToIndex(),
              ),
            ),
            OutlinedButton(
              onPressed: _scrollToIndex,
              child: const Text('Scroll to index'),
            ),
          ],
        ),
        DemoToolbar(
          children: [
            const Text('Reorder'),
            DropdownButton<bool>(
              value: _handles,
              items: const [
                DropdownMenuItem(value: false, child: Text('Long press')),
                DropdownMenuItem(value: true, child: Text('Drag handle')),
              ],
              onChanged: (value) => _configure(() => _handles = value!),
            ),
            if (widget.mode != _Mode.automatic) ...[
              const Text('Fixed extent'),
              Switch(
                value: _fixedExtent,
                onChanged: (value) => _configure(() => _fixedExtent = value),
              ),
            ],
            const Text('Morph'),
            Switch(
              value: _morph,
              onChanged: (value) => _configure(() => _morph = value),
            ),
            const Text('Slow animation'),
            Switch(
              value: _slow,
              onChanged: (value) => _configure(() => _slow = value),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(switch (widget.mode) {
            _Mode.automatic => 'Replace a List; automatic diff animates identity, content and size changes.',
            _Mode.manual => 'Update the data, then notify the controller. Range operations include outgoing builders.',
            _Mode.sliver => 'An explicit diff dispatcher drives an animated sliver alongside regular slivers.',
          }, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Scrollbar(controller: _scrollController, child: _buildList()),
        ),
      ],
    );
  }

  Widget _buildList() {
    final morph = _morph ? _sameRow : null;
    if (widget.mode == _Mode.automatic) {
      return AutomaticAnimatedListView<_Item>(
        list: _items,
        listController: _controller,
        scrollController: _scrollController,
        comparator: _comparator,
        itemBuilder: _buildItem,
        animator: _animator,
        reorderModel: _reorderModel,
        addLongPressReorderable: !_handles,
        morphComparator: morph,
        detectMoves: true,
        padding: EdgeInsets.zero,
      );
    }
    final delegate = AnimatedSliverChildBuilderDelegate(
      (context, index, data) => _buildItem(context, _items[index], data),
      _items.length,
      animator: _animator,
      reorderModel: _reorderModel,
      addLongPressReorderable: !_handles,
      morphComparator: morph,
    );
    if (widget.mode == _Mode.sliver) {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Regular sliver header'),
            ),
          ),
          if (_fixedExtent)
            AnimatedSliverFixedExtentList(
              controller: _controller,
              delegate: delegate,
              itemExtent: 64,
            )
          else
            AnimatedSliverList(controller: _controller, delegate: delegate),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Regular sliver footer'),
            ),
          ),
        ],
      );
    }
    return AnimatedListView.custom(
      controller: _scrollController,
      listController: _controller,
      delegate: delegate,
      itemExtent: _fixedExtent ? 64 : null,
      padding: EdgeInsets.zero,
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.height,
    this.handle,
  });

  final _Item item;
  final double height;
  final Widget? handle;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.circle, color: item.color, size: 12),
          const SizedBox(width: 12),
          Expanded(child: Text('Item ${item.id}')),
          ?handle,
        ],
      ),
    ),
  );
}

class _Item {
  const _Item(this.id, this.color, [this.height = 64]);

  final int id;
  final Color color;
  final double height;
}

bool _sameItem(_Item a, _Item b) => a.id == b.id;
bool _sameContent(_Item a, _Item b) =>
    a.color == b.color && a.height == b.height;
bool _sameRow(Widget a, Widget b) =>
    a is _ItemRow &&
    b is _ItemRow &&
    _sameContent(a.item, b.item) &&
    a.height == b.height;
const _comparator = AnimatedListDiffListComparator<_Item>(
  sameItem: _sameItem,
  sameContent: _sameContent,
);

const _firstItems = [
  _Item(1, Colors.orange),
  _Item(2, Colors.blue),
  _Item(3, Colors.blue),
  _Item(4, Colors.cyan),
  _Item(5, Colors.blue),
  _Item(8, Colors.green),
  ..._tailItems,
];
const _secondItems = [
  _Item(4, Colors.cyan),
  _Item(2, Colors.blue),
  _Item(6, Colors.blue),
  _Item(5, Colors.pink, 104),
  _Item(7, Colors.blue),
  _Item(8, Colors.amber),
  ..._tailItems,
];
const _tailItems = [
  _Item(9, Colors.blue),
  _Item(10, Colors.teal),
  _Item(11, Colors.blue),
  _Item(12, Colors.blue),
  _Item(13, Colors.indigo),
  _Item(14, Colors.blue),
  _Item(15, Colors.blue),
  _Item(16, Colors.teal),
  _Item(17, Colors.blue),
  _Item(18, Colors.blue),
  _Item(19, Colors.indigo),
  _Item(20, Colors.blue),
];
