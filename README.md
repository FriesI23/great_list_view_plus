# great_list_view_plus

![Package][pubdev-package]
![Likes][pubdev-likes]
![Points][pubdev-points]

Animated and reorderable Flutter lists with automatic diff updates and a tree
adapter.

A maintained fork of [great_list_view 0.2.3](https://github.com/DavideBelsole/great_list_view)
by Davide Belsole, distributed under the original MIT license.

## Features

- Animate insertions, removals, moves and content changes while supporting drag
  reordering in the same list.
- Replace a list and let the Myers diff algorithm dispatch updates, or send
  explicit controller notifications for individual items and ranges.
- Build by index without requiring an underlying `List` or per-item keys.
- Compose animated slivers with other slivers, including fixed-extent lists.
- Turn callback-defined tree data into a linear list, with expansion, subtree
  editing and cross-parent moves.

See the [runnable example](example/README.md) for the **List** and **Tree** tabs
and their available controls.

## Example gallery

Automatic updates, Morph transitions, drag handles, manual notifications and
sliver composition:

![List updates, reordering and slivers][list-demo]

Tree expansion, node editing, cross-parent dragging and a plain ListView host:

![Tree editing and cross-parent reordering][tree-demo]

## Requirements

Requires **Flutter 3.47.0 / Dart 3.13.0 or newer**.
Supports Android, iOS, macOS, Windows and Linux; web is not supported.

Material components use `material_ui`. Host Material UI, themes and localization
must use the same standalone package. Follow Flutter's
[official migration guide](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui)
when integrating it into your app.

Current limitations: no separated-list constructor, incomplete list semantics
support, and no infinite lists.

## Getting started

```sh
flutter pub add great_list_view_plus
```

Or add the dependency to `pubspec.yaml`, then run `flutter pub get`:

```yaml
dependencies:
  great_list_view_plus: ^0.3.0
```

Import the single public entry point:

```dart
import 'package:great_list_view_plus/great_list_view_plus.dart';
```

This replaces the previous list and auxiliary imports. `worker_manager` is no
longer re-exported; declare it directly if your application uses its API.

## Usage

Pass a new list to `AutomaticAnimatedListView` to animate its differences. Keep
previous lists and items unchanged so the comparator can compare old and new
values correctly.

```dart
import 'package:great_list_view_plus/great_list_view_plus.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MaterialApp(home: ListExample()));

class ListExample extends StatefulWidget {
  const ListExample({super.key});

  @override
  State<ListExample> createState() => _ListExampleState();
}

class _ListExampleState extends State<ListExample> {
  final _controller = AnimatedListController();
  List<int> _items = const [1, 2, 3];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Animated list')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => setState(() {
        _items = _items.contains(2) ? const [3, 1, 4] : const [1, 2, 3];
      }),
      child: const Icon(Icons.swap_horiz),
    ),
    body: AutomaticAnimatedListView<int>(
      list: _items,
      listController: _controller,
      comparator: AnimatedListDiffListComparator<int>(
        sameItem: (a, b) => a == b,
        sameContent: (a, b) => a == b,
      ),
      detectMoves: true,
      itemBuilder: (context, item, data) => data.measuring
          ? const SizedBox(height: 56)
          : SizedBox(height: 56, child: ListTile(title: Text('Item $item'))),
    ),
  );
}
```

`sameItem` compares identity; `sameContent` compares the content of matching
items. When `data.measuring` is true, return a lightweight widget with the same
final extent, without entry/exit animations. Content changes can use implicit
animations or `MorphTransition`.

For large lists, move detection adds work; enable `detectMoves` only when needed.
Optionally call `await GreatListView.init()` before `runApp()` to start diff
workers early. Otherwise workers start on demand.

## Detailed examples

Each folded example is a separate, complete `main.dart`. Material examples also
need a direct `material_ui` dependency. The [example app](example/README.md)
combines these capabilities with state-preserving tabs and controls.

### Automatic updates

`AutomaticAnimatedListView` compares old and new lists and notifies its
`AnimatedListController`. Use implicit animations for changes to size or color.
For text or other content that cannot animate implicitly, `morphComparator`
returns true when the old and new widgets have equivalent content, avoiding an
unnecessary cross-fade.

<details>
<summary>1. Automatic animated list</summary>

```dart
import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(
        child: Scaffold(body: Body(key: gkey)),
      ),
    );
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  late List<ItemData> currentList;

  @override
  void initState() {
    super.initState();
    currentList = listA;
  }

  void swapList() {
    setState(() {
      if (currentList == listA) {
        currentList = listB;
      } else {
        currentList = listA;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: AutomaticAnimatedListView<ItemData>(
        list: currentList,
        comparator: AnimatedListDiffListComparator<ItemData>(
          sameItem: (a, b) => a.id == b.id,
          sameContent: (a, b) =>
              a.color == b.color && a.fixedHeight == b.fixedHeight,
        ),
        itemBuilder: (context, item, data) => data.measuring
            ? Container(
                margin: EdgeInsets.all(5),
                height: item.fixedHeight ?? 60,
              )
            : Item(data: item),
        listController: controller,
        scrollController: scrollController,
        detectMoves: true,
      ),
    );
  }
}

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => gkey.currentState?.swapList(),
      child: AnimatedContainer(
        height: data.fixedHeight ?? 60,
        duration: const Duration(milliseconds: 500),
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: data.color,
          border: Border.all(color: Colors.black12, width: 0),
        ),
        child: Center(
          child: Text('Item ${data.id}', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class ItemData {
  final int id;
  final Color color;
  final double? fixedHeight;
  const ItemData(this.id, [this.color = Colors.blue, this.fixedHeight]);
}

List<ItemData> listA = [
  ItemData(1, Colors.orange),
  ItemData(2),
  ItemData(3),
  ItemData(4, Colors.cyan),
  ItemData(5),
  ItemData(8, Colors.green),
];
List<ItemData> listB = [
  ItemData(4, Colors.cyan),
  ItemData(2),
  ItemData(6),
  ItemData(5, Colors.pink, 100),
  ItemData(7),
  ItemData(8, Colors.yellowAccent),
];

final scrollController = ScrollController();
final controller = AnimatedListController();
final gkey = GlobalKey<_BodyState>();
```

</details>

<details>
<summary>2. Automatic animated list with MorphTransition</summary>

```dart
import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(
        child: Scaffold(body: Body(key: gkey)),
      ),
    );
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  late List<ItemData> currentList;

  @override
  void initState() {
    super.initState();
    currentList = listA;
  }

  void swapList() {
    setState(() {
      if (currentList == listA) {
        currentList = listB;
      } else {
        currentList = listA;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: AutomaticAnimatedListView<ItemData>(
        list: currentList,
        comparator: AnimatedListDiffListComparator<ItemData>(
          sameItem: (a, b) => a.id == b.id,
          sameContent: (a, b) =>
              a.text == b.text &&
              a.color == b.color &&
              a.fixedHeight == b.fixedHeight,
        ),
        itemBuilder: (context, item, data) => data.measuring
            ? Container(
                margin: EdgeInsets.all(5),
                height: item.fixedHeight ?? 60,
              )
            : Item(data: item),
        listController: controller,
        morphComparator: (a, b) {
          if (a is Item && b is Item) {
            return a.data.text == b.data.text &&
                a.data.color == b.data.color &&
                a.data.fixedHeight == b.data.fixedHeight;
          }
          return false;
        },
        scrollController: scrollController,
      ),
    );
  }
}

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => gkey.currentState?.swapList(),
      child: Container(
        height: data.fixedHeight ?? 60,
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: data.color,
          border: Border.all(color: Colors.black12, width: 0),
        ),
        child: Center(child: Text(data.text, style: TextStyle(fontSize: 16))),
      ),
    );
  }
}

class ItemData {
  final int id;
  final String text;
  final Color color;
  final double? fixedHeight;
  const ItemData(
    this.text,
    this.id, [
    this.color = Colors.blue,
    this.fixedHeight,
  ]);
}

List<ItemData> listA = [
  ItemData('Text 1', 1, Colors.orange),
  ItemData('Text 2', 2),
  ItemData('Text 3', 3),
  ItemData('Text 4', 4),
  ItemData('Text 5', 5),
  ItemData('Text 8', 8, Colors.green),
];
List<ItemData> listB = [
  ItemData('Text 2', 2),
  ItemData('Text 6', 6),
  ItemData('Other text 5', 5, Colors.pink, 100),
  ItemData('Text 7', 7),
  ItemData('Other text 8', 8, Colors.yellowAccent),
];

final scrollController = ScrollController();
final controller = AnimatedListController();
final gkey = GlobalKey<_BodyState>();
```

</details>

### Manual notifications and dispatchers

`AnimatedListView` builds by index. Mutate your data first, then call
`notifyInsertedRange`, `notifyRemovedRange`, `notifyChangedRange`,
`notifyReplacedRange` or `notifyMovedRange`. Outgoing builders must retain the
old items; their indexes are relative to the notified range. Group several
notifications with `controller.batch()`.

An explicit `AnimatedListDiffListDispatcher` provides diff updates for a manually
controlled list. Await `dispatchNewList()` and discard pending work when the
owning state is disposed.

<details>
<summary>3. Manual animated list</summary>

```dart
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(
        child: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            label: Text('Random Change'),
            onPressed: randomChange,
          ),
          body: Body(),
        ),
      ),
    );
  }
}

class Body extends StatelessWidget {
  const Body({super.key});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: AnimatedListView(
        initialItemCount: list.length,
        itemBuilder: (context, index, data) => data.measuring
            ? Container(margin: EdgeInsets.all(5), height: 60)
            : Item(data: list[index]),
        listController: controller,
        scrollController: scrollController,
      ),
    );
  }
}

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: 60,
      margin: EdgeInsets.all(5),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kColors[data.color],
        border: Border.all(color: Colors.black12, width: 0),
      ),
      child: Center(
        child: Text('Item ${data.id}', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

final kColors = const <Color>[
  Colors.teal,
  Colors.lightGreen,
  Colors.redAccent,
  Colors.pink,
];

class ItemData {
  final int id;
  final int color;
  const ItemData(this.id, [int color = 0]) : color = color % 4;
}

int id = 0;
List<ItemData> list = [for (var i = 1; i <= 10; i++) ItemData(++id)];

var r = Random();

void randomChange() {
  var activity = list.isEmpty ? 1 : r.nextInt(5);
  switch (activity) {
    case 0: // remove
      final from = r.nextInt(list.length);
      final to = from + 1 + r.nextInt(list.length - from);
      final subList = list.sublist(from, to);
      list.removeRange(from, to);
      controller.notifyRemovedRange(
        from,
        to - from,
        (context, index, data) => Item(data: subList[index]),
      );
      break;
    case 1: // insert
      final from = r.nextInt(list.length + 1);
      final count = 1 + r.nextInt(5);
      list.insertAll(from, [for (var i = 0; i < count; i++) ItemData(++id)]);
      controller.notifyInsertedRange(from, count);
      break;
    case 2: // replace
      final from = r.nextInt(list.length);
      final to = from + 1 + r.nextInt(list.length - from);
      final count = 1 + r.nextInt(5);
      final subList = list.sublist(from, to);
      list.replaceRange(from, to, [
        for (var i = 0; i < count; i++) ItemData(++id),
      ]);
      controller.notifyReplacedRange(
        from,
        to - from,
        count,
        (context, index, data) => Item(data: subList[index]),
      );
      break;
    case 3: // change
      final from = r.nextInt(list.length);
      final to = from + 1 + r.nextInt(list.length - from);
      final subList = list.sublist(from, to);
      list.replaceRange(from, to, [
        for (var i = 0; i < to - from; i++)
          ItemData(subList[i].id, subList[i].color + 1),
      ]);
      controller.notifyChangedRange(
        from,
        to - from,
        (context, index, data) => Item(data: subList[index]),
      );
      break;
    case 4: // move
      var from = r.nextInt(list.length);
      var count = 1 + r.nextInt(list.length - from);
      var newIndex = r.nextInt(list.length - count + 1);
      var to = from + count;
      final moveList = list.sublist(from, to);
      list.removeRange(from, to);
      list.insertAll(newIndex, moveList);
      controller.notifyMovedRange(from, count, newIndex);
      break;
  }
}

final scrollController = ScrollController();
final controller = AnimatedListController();
```

</details>

<details>
<summary>4. Animated list with an explicit diff dispatcher</summary>

```dart
import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(
        child: Scaffold(body: Body(key: gkey)),
      ),
    );
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  late AnimatedListDiffListDispatcher<ItemData> dispatcher;

  @override
  void initState() {
    super.initState();

    dispatcher = AnimatedListDiffListDispatcher<ItemData>(
      controller: controller,
      itemBuilder: itemBuilder,
      currentList: listA,
      comparator: AnimatedListDiffListComparator<ItemData>(
        sameItem: (a, b) => a.id == b.id,
        sameContent: (a, b) =>
            a.color == b.color && a.fixedHeight == b.fixedHeight,
      ),
    );
  }

  bool _dispatching = false;

  Future<void> swapList() async {
    if (_dispatching) return;
    _dispatching = true;
    try {
      await dispatcher.dispatchNewList(
        identical(dispatcher.currentList, listA) ? listB : listA,
        detectMoves: true,
      );
    } finally {
      _dispatching = false;
    }
  }

  @override
  void dispose() {
    dispatcher.discard();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: AnimatedListView(
        initialItemCount: dispatcher.currentList.length,
        itemBuilder: (context, index, data) =>
            itemBuilder(context, dispatcher.currentList[index], data),
        listController: controller,
        scrollController: scrollController,
      ),
    );
  }
}

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => gkey.currentState?.swapList(),
      child: AnimatedContainer(
        height: data.fixedHeight ?? 60,
        duration: const Duration(milliseconds: 500),
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: data.color,
          border: Border.all(color: Colors.black12, width: 0),
        ),
        child: Center(
          child: Text('Item ${data.id}', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

Widget itemBuilder(
  BuildContext context,
  ItemData item,
  AnimatedWidgetBuilderData data,
) {
  if (data.measuring) {
    return Container(margin: EdgeInsets.all(5), height: item.fixedHeight ?? 60);
  }
  return Item(data: item);
}

class ItemData {
  final int id;
  final Color color;
  final double? fixedHeight;
  const ItemData(this.id, [this.color = Colors.blue, this.fixedHeight]);
}

List<ItemData> listA = [
  ItemData(1, Colors.orange),
  ItemData(2),
  ItemData(3),
  ItemData(4, Colors.cyan),
  ItemData(5),
  ItemData(8, Colors.green),
];
List<ItemData> listB = [
  ItemData(4, Colors.cyan),
  ItemData(2),
  ItemData(6),
  ItemData(5, Colors.pink, 100),
  ItemData(7),
  ItemData(8, Colors.yellowAccent),
];

final scrollController = ScrollController();
final controller = AnimatedListController();
final gkey = GlobalKey<_BodyState>();
```

</details>

### Sliver composition

Use `AnimatedSliverList` in a `CustomScrollView` alongside ordinary slivers.
`AnimatedSliverFixedExtentList` supplies the fixed-height variant; the runnable
example demonstrates both.

<details>
<summary>5. Animated list using slivers</summary>

```dart
import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(
        child: Scaffold(body: Body(key: gkey)),
      ),
    );
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  late AnimatedListDiffListDispatcher<ItemData> dispatcher;

  @override
  void initState() {
    super.initState();

    dispatcher = AnimatedListDiffListDispatcher<ItemData>(
      controller: controller,
      itemBuilder: itemBuilder,
      currentList: listA,
      comparator: AnimatedListDiffListComparator<ItemData>(
        sameItem: (a, b) => a.id == b.id,
        sameContent: (a, b) =>
            a.color == b.color && a.fixedHeight == b.fixedHeight,
      ),
    );
  }

  bool _dispatching = false;

  Future<void> swapList() async {
    if (_dispatching) return;
    _dispatching = true;
    try {
      await dispatcher.dispatchNewList(
        identical(dispatcher.currentList, listA) ? listB : listA,
        detectMoves: true,
      );
    } finally {
      _dispatching = false;
    }
  }

  @override
  void dispose() {
    dispatcher.discard();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int itemIndex,
            ) {
              return Container(
                alignment: Alignment.center,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 4),
                ),
                child: ListTile(title: Text('This is another sliver')),
              );
            }, childCount: 1),
          ),
          AnimatedSliverList(
            controller: controller,
            delegate: AnimatedSliverChildBuilderDelegate(
              (context, index, data) =>
                  itemBuilder(context, dispatcher.currentList[index], data),
              dispatcher.currentList.length,
            ),
          ),
        ],
      ),
    );
  }
}

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => gkey.currentState?.swapList(),
      child: AnimatedContainer(
        height: data.fixedHeight ?? 60,
        duration: const Duration(milliseconds: 500),
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: data.color,
          border: Border.all(color: Colors.black12, width: 0),
        ),
        child: Center(
          child: Text('Item ${data.id}', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

Widget itemBuilder(
  BuildContext context,
  ItemData item,
  AnimatedWidgetBuilderData data,
) {
  if (data.measuring) {
    return Container(margin: EdgeInsets.all(5), height: item.fixedHeight ?? 60);
  }
  return Item(data: item);
}

class ItemData {
  final int id;
  final Color color;
  final double? fixedHeight;
  const ItemData(this.id, [this.color = Colors.blue, this.fixedHeight]);
}

List<ItemData> listA = [
  ItemData(1, Colors.orange),
  ItemData(2),
  ItemData(3),
  ItemData(4),
  ItemData(5),
  ItemData(8, Colors.green),
];
List<ItemData> listB = [
  ItemData(2),
  ItemData(6),
  ItemData(5, Colors.pink, 100),
  ItemData(7),
  ItemData(8, Colors.yellowAccent),
];

final scrollController = ScrollController();
final controller = AnimatedListController();
final gkey = GlobalKey<_BodyState>();
```

</details>

### Reordering

Pass a reorder model and enable `addLongPressReorderable` for long-press sorting.
`AutomaticAnimatedListReorderModel` updates a mutable list for you; a custom
`AnimatedListReorderModel` can restrict moves or update application data itself.

For drag handles, disable long-press sorting and call `notifyStartReorder`,
`notifyUpdateReorder` and `notifyStopReorder` from the gesture callbacks. Pass
`true` to `notifyStopReorder` when the gesture is cancelled.

`onReorderFeedback` can return extra drag state, available through `data.slot`
and in `onReorderComplete`. The tree example uses it to preview indentation and
choose the destination parent.

<details>
<summary>6. Automatic animated list with long-press reordering</summary>

```dart
import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(
        child: Scaffold(body: Body(key: gkey)),
      ),
    );
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  late List<ItemData> currentList;

  @override
  void initState() {
    super.initState();
    currentList = listA;
  }

  void swapList() {
    setState(() {
      if (currentList == listA) {
        currentList = listB;
      } else {
        currentList = listA;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: AutomaticAnimatedListView<ItemData>(
        list: currentList,
        comparator: AnimatedListDiffListComparator<ItemData>(
          sameItem: (a, b) => a.id == b.id,
          sameContent: (a, b) =>
              a.color == b.color && a.fixedHeight == b.fixedHeight,
        ),
        itemBuilder: (context, item, data) => data.measuring
            ? Container(
                margin: EdgeInsets.all(5),
                height: item.fixedHeight ?? 60,
              )
            : Item(data: item),
        listController: controller,
        addLongPressReorderable: true,
        reorderModel: AutomaticAnimatedListReorderModel(currentList),
        scrollController: scrollController,
      ),
    );
  }
}

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => gkey.currentState?.swapList(),
      child: AnimatedContainer(
        height: data.fixedHeight ?? 60,
        duration: const Duration(milliseconds: 500),
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: data.color,
          border: Border.all(color: Colors.black12, width: 0),
        ),
        child: Center(
          child: Text('Item ${data.id}', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class ItemData {
  final int id;
  final Color color;
  final double? fixedHeight;
  const ItemData(this.id, [this.color = Colors.blue, this.fixedHeight]);
}

List<ItemData> listA = [
  ItemData(1, Colors.orange),
  ItemData(2),
  ItemData(3),
  ItemData(4),
  ItemData(5),
  ItemData(8, Colors.green),
];
List<ItemData> listB = [
  ItemData(2),
  ItemData(6),
  ItemData(5, Colors.pink, 100),
  ItemData(7),
  ItemData(8, Colors.yellowAccent),
];

final scrollController = ScrollController();
final controller = AnimatedListController();
final gkey = GlobalKey<_BodyState>();
```

</details>

<details>
<summary>7. Animated list with a custom reorder model</summary>

```dart
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(
        child: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            label: Text('Random Change'),
            onPressed: randomChange,
          ),
          body: Body(),
        ),
      ),
    );
  }
}

class Body extends StatelessWidget {
  const Body({super.key});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: AnimatedListView(
        initialItemCount: list.length,
        itemBuilder: (context, index, data) => data.measuring
            ? Container(margin: EdgeInsets.all(5), height: 60)
            : Item(data: list[index]),
        listController: controller,
        addLongPressReorderable: true,
        reorderModel: AnimatedListReorderModel(
          onReorderStart: (index, dx, dy) {
            // only teal-colored items can be reordered
            return list[index].color == 0;
          },
          onReorderMove: (index, dropIndex) {
            // pink-colored items cannot be swapped
            return list[dropIndex].color != 3;
          },
          onReorderComplete: (index, dropIndex, slot) {
            list.insert(dropIndex, list.removeAt(index));
            return true;
          },
        ),
        scrollController: scrollController,
      ),
    );
  }
}

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: 60,
      margin: EdgeInsets.all(5),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kColors[data.color],
        border: Border.all(color: Colors.black12, width: 0),
      ),
      child: Center(
        child: Text('Item ${data.id}', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

final kColors = const <Color>[
  Colors.teal,
  Colors.lightGreen,
  Colors.redAccent,
  Colors.pink,
];

class ItemData {
  final int id;
  final int color;
  const ItemData(this.id, [int color = 0]) : color = color % 4;
}

int id = 0;
List<ItemData> list = [
  for (var i = 1; i <= 10; i++) ItemData(++id, (id - 1) % 4),
];

var r = Random();

void randomChange() {
  var activity = list.isEmpty ? 1 : r.nextInt(4);
  switch (activity) {
    case 0: // remove
      final from = r.nextInt(list.length);
      final to = from + 1 + r.nextInt(list.length - from);
      final subList = list.sublist(from, to);
      list.removeRange(from, to);
      controller.notifyRemovedRange(
        from,
        to - from,
        (context, index, data) => Item(data: subList[index]),
      );
      break;
    case 1: // insert
      final from = r.nextInt(list.length + 1);
      final count = 1 + r.nextInt(5);
      list.insertAll(from, [for (var i = 0; i < count; i++) ItemData(++id)]);
      controller.notifyInsertedRange(from, count);
      break;
    case 2: // replace
      final from = r.nextInt(list.length);
      final to = from + 1 + r.nextInt(list.length - from);
      final count = 1 + r.nextInt(5);
      final subList = list.sublist(from, to);
      list.replaceRange(from, to, [
        for (var i = 0; i < count; i++) ItemData(++id),
      ]);
      controller.notifyReplacedRange(
        from,
        to - from,
        count,
        (context, index, data) => Item(data: subList[index]),
      );
      break;
    case 3: // change
      final from = r.nextInt(list.length);
      final to = from + 1 + r.nextInt(list.length - from);
      final subList = list.sublist(from, to);
      list.replaceRange(from, to, [
        for (var i = 0; i < to - from; i++)
          ItemData(subList[i].id, subList[i].color + 1),
      ]);
      controller.notifyChangedRange(
        from,
        to - from,
        (context, index, data) => Item(data: subList[index]),
      );
      break;
  }
}

final scrollController = ScrollController();
final controller = AnimatedListController();
```

</details>

<details>
<summary>8. Automatic animated list with drag handles</summary>

```dart
import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(
        child: Scaffold(body: Body(key: gkey)),
      ),
    );
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  late List<ItemData> currentList;

  @override
  void initState() {
    super.initState();
    currentList = listA;
  }

  void swapList() {
    setState(() {
      if (currentList == listA) {
        currentList = listB;
      } else {
        currentList = listA;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: AutomaticAnimatedListView<ItemData>(
        list: currentList,
        comparator: AnimatedListDiffListComparator<ItemData>(
          sameItem: (a, b) => a.id == b.id,
          sameContent: (a, b) =>
              a.color == b.color && a.fixedHeight == b.fixedHeight,
        ),
        itemBuilder: (context, item, data) => data.measuring
            ? Container(
                margin: EdgeInsets.all(5),
                height: item.fixedHeight ?? 60,
              )
            : Item(data: item),
        listController: controller,
        reorderModel: AutomaticAnimatedListReorderModel(currentList),
        addLongPressReorderable: false,
        scrollController: scrollController,
      ),
    );
  }
}

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => gkey.currentState?.swapList(),
            child: AnimatedContainer(
              height: data.fixedHeight ?? 60,
              duration: const Duration(milliseconds: 500),
              margin: EdgeInsets.all(5),
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: data.color,
                border: Border.all(color: Colors.black12, width: 0),
              ),
              child: Center(
                child: Text('Item ${data.id}', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
        GestureDetector(
          onVerticalDragStart: (dd) {
            controller.notifyStartReorder(
              context,
              dd.localPosition.dx,
              dd.localPosition.dy,
            );
          },
          onVerticalDragUpdate: (dd) {
            controller.notifyUpdateReorder(
              dd.localPosition.dx,
              dd.localPosition.dy,
            );
          },
          onVerticalDragEnd: (dd) {
            controller.notifyStopReorder(false);
          },
          onVerticalDragCancel: () {
            controller.notifyStopReorder(true);
          },
          child: Icon(Icons.drag_handle),
        ),
      ],
    );
  }
}

class ItemData {
  final int id;
  final Color color;
  final double? fixedHeight;
  const ItemData(this.id, [this.color = Colors.blue, this.fixedHeight]);
}

List<ItemData> listA = [
  ItemData(1, Colors.orange),
  ItemData(2),
  ItemData(3),
  ItemData(4),
  ItemData(5),
  ItemData(8, Colors.green),
];
List<ItemData> listB = [
  ItemData(2),
  ItemData(6),
  ItemData(5, Colors.pink, 100),
  ItemData(7),
  ItemData(8, Colors.yellowAccent),
];

final scrollController = ScrollController();
final controller = AnimatedListController();
final gkey = GlobalKey<_BodyState>();
```

</details>

### Tree adapter

`TreeListAdapter` maps your node type into list indexes using `parentOf`,
`childrenCount`, `childAt`, `isNodeExpanded`, `indexOfChild` and `equals`
callbacks. Use `nodeToIndex` and `indexToNode` to move between nodes and indexes.

Expansion, collapse, insertion, removal and moves use the adapter's notification
methods, with callbacks that update the underlying tree. Supply a controller
and builder to animate these changes, or use the adapter with a plain
`ListView`. The runnable example covers both hosts.

<details>
<summary>9. Reorderable tree view</summary>

```dart
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() {
  buildTree(rnd, root, 5, 3);
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(child: Scaffold(body: Body())),
    );
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  @override
  Widget build(BuildContext context) {
    return AnimatedListView(
      listController: controller,
      itemBuilder: (context, index, data) =>
          itemBuilder(context, adapter, index, data),
      initialItemCount: adapter.count,
      reorderModel: AnimatedListReorderModel(
        onReorderStart: (index, dx, dy) {
          if (adapter.includeRoot && index == 0) return false;
          var node = adapter.indexToNode(index);
          if (!adapter.isLeaf(node) && adapter.isNodeExpanded(node)) {
            // cannot reorder an open node! the long click must first collapse it
            adapter.notifyNodeCollapsing(
              node,
              () {
                collapsedMap.add(node);
              },
              index: index,
              updateNode: true,
            );
            return false;
          }
          return true;
        },
        onReorderFeedback: (fromIndex, toIndex, offset, dx, dy) {
          var level =
              adapter.levelOf(adapter.indexToNode(fromIndex)) + dx ~/ 15.0;
          if (adapter.includeRoot && toIndex == 0) return level;
          var levels = adapter.getPossibleLevelsOfMove(fromIndex, toIndex);
          return level.clamp(levels.from, levels.to - 1);
        },
        onReorderMove: (fromIndex, toIndex) {
          return !adapter.includeRoot || toIndex != 0;
        },
        onReorderComplete: (fromIndex, toIndex, slot) {
          if (adapter.includeRoot && toIndex == 0) return false;
          var levels = adapter.getPossibleLevelsOfMove(fromIndex, toIndex);
          if (!levels.isIn(slot as int)) return false;
          adapter.notifyNodeMoving(
            fromIndex,
            toIndex,
            slot,
            (pNode, node) => pNode.children.remove(node),
            (pNode, node, pos) => pNode.add(node, pos),
            updateParentNodes: true,
          );
          return true;
        },
      ),
    );
  }
}

class NodeData {
  final String text;
  List<NodeData> children = [];
  NodeData? parent;

  NodeData(this.text);

  void add(NodeData n, [int? index]) {
    (index == null) ? children.add(n) : children.insert(index, n);
    n.parent = this;
  }

  @override
  String toString() => text;
}

class TreeNode extends StatelessWidget {
  final NodeData node;
  final int level;
  final bool? expanded;
  final void Function(bool expanded) onExpandCollapseTap;
  final void Function() onRemoveTap;
  final void Function() onInsertTap;
  const TreeNode({
    super.key,
    required this.node,
    required this.level,
    required this.expanded,
    required this.onExpandCollapseTap,
    required this.onRemoveTap,
    required this.onInsertTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      trailing: _buildExpandCollapseArrowButton(),
      leading: _buildAddRemoveButtons(),
      title: AnimatedContainer(
        padding: EdgeInsets.only(left: level * 15.0),
        duration: const Duration(milliseconds: 250),
        child: Text(node.toString(), style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildAddRemoveButtons() {
    return SizedBox(
      width: 40,
      child: Row(
        children: [
          _buildIconButton(Colors.red, const Icon(Icons.remove), onRemoveTap),
          _buildIconButton(Colors.green, const Icon(Icons.add), onInsertTap),
        ],
      ),
    );
  }

  Widget? _buildExpandCollapseArrowButton() {
    if (expanded == null) return null;
    return ArrowButton(
      expanded: expanded!,
      turns: 0.25,
      icon: const Icon(Icons.keyboard_arrow_right),
      duration: const Duration(milliseconds: 500),
      onTap: onExpandCollapseTap,
    );
  }

  static Widget _buildIconButton(
    Color color,
    Icon icon,
    void Function() onPressed,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
      child: SizedBox(
        width: 20,
        height: 25,
        child: IconButton(
          padding: EdgeInsets.all(0.0),
          iconSize: 15,
          icon: icon,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

Widget itemBuilder(
  BuildContext context,
  TreeListAdapter<NodeData> adapter,
  int index,
  AnimatedWidgetBuilderData data,
) {
  final node = adapter.indexToNode(index);
  return TreeNode(
    node: node,
    level: (data.dragging && data.slot != null)
        ? data.slot as int
        : adapter.levelOf(node),
    expanded: adapter.isLeaf(node) ? null : adapter.isNodeExpanded(node),
    onExpandCollapseTap: (expanded) {
      if (expanded) {
        adapter.notifyNodeExpanding(node, () {
          collapsedMap.remove(node);
        }, updateNode: true);
      } else {
        adapter.notifyNodeCollapsing(node, () {
          collapsedMap.add(node);
        }, updateNode: true);
      }
    },
    onRemoveTap: () {
      if (node == root) return; // The visible root cannot be removed.
      adapter.notifyNodeRemoving(node, () {
        node.parent!.children.remove(node);
      }, updateParentNode: true);
    },
    onInsertTap: () {
      var newTree = NodeData(kNames[rnd.nextInt(kNames.length)]);
      adapter.notifyNodeInserting(newTree, node, 0, () {
        node.add(newTree, 0);
      }, updateParentNode: true);
    },
  );
}

void buildTree(Random r, NodeData node, int maxChildren, [int? startWith]) {
  var n = startWith ?? (maxChildren > 0 ? r.nextInt(maxChildren) : 0);
  if (n == 0) return;
  for (var i = 0; i < n; i++) {
    var child = NodeData(kNames[r.nextInt(kNames.length)]);
    buildTree(r, child, maxChildren - 1);
    node.add(child);
  }
}

TreeListAdapter<NodeData> adapter = TreeListAdapter<NodeData>(
  childAt: (node, index) => node.children[index],
  childrenCount: (node) => node.children.length,
  parentOf: (node) => node.parent ?? root,
  indexOfChild: (parent, node) => parent.children.indexOf(node),
  isNodeExpanded: (node) => !collapsedMap.contains(node),
  includeRoot: true,
  root: root,
  controller: controller,
  builder: itemBuilder,
);

const List<String> kNames = [
  'Liam',
  'Olivia',
  'Noah',
  'Emma',
  'Oliver',
  'Ava',
  'William',
  'Sophia',
  'Elijah',
  'Isabella',
  'James',
  'Charlotte',
  'Benjamin',
  'Amelia',
  'Lucas',
  'Mia',
  'Mason',
  'Harper',
  'Ethan',
  'Evelyn',
];

final root = NodeData('Me');
final rnd = Random(23);
final collapsedMap = <NodeData>{};
final controller = AnimatedListController();
```

</details>

### Scroll to an index

`controller.computeItemBox(index, true)` returns item geometry for a shared
`ScrollController`. It can return null while layout or animation is updating;
wait before trying again. Use `initialScrollOffsetCallback` to choose the initial
position after measuring items.

<details>
<summary>10. Scroll to an index and set the initial offset</summary>

```dart
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:great_list_view_plus/great_list_view_plus.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus example',
      home: SafeArea(child: Scaffold(body: Body())),
    );
  }
}

class Body extends StatelessWidget {
  const Body({super.key});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      child: AutomaticAnimatedListView<ItemData>(
        list: myList,
        listController: controller,
        comparator: AnimatedListDiffListComparator<ItemData>(
          sameItem: (a, b) => a.id == b.id,
          sameContent: (a, b) =>
              a.color == b.color && a.fixedHeight == b.fixedHeight,
        ),
        itemBuilder: (context, item, data) => data.measuring
            ? Container(
                margin: EdgeInsets.all(5),
                height: item.fixedHeight ?? 60,
              )
            : Item(data: item),
        initialScrollOffsetCallback: (c) {
          final i = rnd.nextInt(myList.length);
          final box = controller.computeItemBox(i, true)!;
          debugPrint('scrolled to item ${myList[i]}');
          return max(
            0.0,
            box.top - (c.viewportMainAxisExtent - box.height) / 2.0,
          );
        },
        scrollController: scrollController,
      ),
    );
  }
}

final rnd = Random();

class Item extends StatelessWidget {
  final ItemData data;

  const Item({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final listIndex = rnd.nextInt(myList.length);
        final box = controller.computeItemBox(listIndex, true);
        if (box == null) return;
        debugPrint('scrolled to item ${myList[listIndex]}');
        final c = context
            .findAncestorRenderObjectOfType<RenderSliver>()!
            .constraints;
        final r = box.top - (c.viewportMainAxisExtent - box.height) / 2.0;
        scrollController.animateTo(
          r.clamp(0.0, scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeIn,
        );
      },
      child: AnimatedContainer(
        height: data.fixedHeight ?? 60,
        duration: const Duration(milliseconds: 500),
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: data.color,
          border: Border.all(color: Colors.black12, width: 0),
        ),
        child: Center(
          child: Text('Item ${data.id}', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class ItemData {
  final int id;
  final Color color;
  final double? fixedHeight;
  const ItemData(this.id, [this.color = Colors.blue, this.fixedHeight]);
  @override
  String toString() => '$id';
}

int n = 0;

List<ItemData> myList = [
  for (n = 1; n <= 10; n++) ItemData(n, Colors.blue, 60),
  for (; n <= 20; n++) ItemData(n, Colors.orange, 80),
  for (; n <= 30; n++) ItemData(n, Colors.yellow, 50),
  for (; n <= 40; n++) ItemData(n, Colors.red, 120),
];

final scrollController = ScrollController();
final controller = AnimatedListController();
```

</details>

## Development

Development uses Flutter 3.47.9, pinned in `.fvmrc`.

```sh
fvm install
make bootstrap
make check
```

`make test` runs package and example tests. Use `make capture-demos` to regenerate
the gallery; see the [example guide](example/README.md#readme-recordings) for
requirements. `make help` lists other commands.

<!-- friesi23-projects:start -->

## More projects

| Project | Description |
| --- | --- |
| ![Flutter Package](https://img.shields.io/badge/-02569B?style=flat-square&logo=flutter&logoColor=white) [Simple Heatmap Calendar](https://github.com/FriesI23/simple_heatmap_calendar) | Customizable Flutter heatmap calendar with internationalization support. |
| ![Flutter Package](https://img.shields.io/badge/-02569B?style=flat-square&logo=flutter&logoColor=white) [Adaptive Actions](https://github.com/FriesI23/adaptive_actions) | Adaptive Flutter action bars and overflow menus for Material and Cupertino. |
| ![Flutter Package](https://img.shields.io/badge/-02569B?style=flat-square&logo=flutter&logoColor=white) [Flutter Adaptive Sidebar](https://github.com/FriesI23/flutter_adaptive_sidebar) | Material and Cupertino sidebars for Flutter with a shared controller. |
| ![Flutter Package](https://img.shields.io/badge/-02569B?style=flat-square&logo=flutter&logoColor=white) [Named HTML Color](https://github.com/FriesI23/named_html_color) | HTML named colors for Flutter. |
| ![Flutter Plugin](https://img.shields.io/badge/-02569B?style=flat-square&logo=flutter&logoColor=white) [iOS Window Control Layout](https://github.com/FriesI23/ios_window_control_layout) | Keep Flutter layouts clear of iPadOS window controls. |
| ![Flutter Plugin](https://img.shields.io/badge/-02569B?style=flat-square&logo=flutter&logoColor=white) [Native Natural Sort](https://github.com/FriesI23/native_natural_sort) | Locale-aware natural sorting for Flutter using native platform engines. |
| ![Dart Package](https://img.shields.io/badge/-0175C2?style=flat-square&logo=dart&logoColor=white) [Simple WebDAV Client](https://github.com/FriesI23/simple_webdav_client) | Dart WebDAV client for file operations, properties, and resource locks. |
| ![Dart Package](https://img.shields.io/badge/-0175C2?style=flat-square&logo=dart&logoColor=white) [Dart Transmission RPC](https://github.com/FriesI23/dart_transmission_rpc) | Dart client for the Transmission RPC API. |
| ![Dart Package](https://img.shields.io/badge/-0175C2?style=flat-square&logo=dart&logoColor=white) [Win2IANA TimeZone Converter](https://github.com/FriesI23/win2iana_tz_converter) | Dart utilities for converting Windows and IANA time zone identifiers. |
| ![App](https://img.shields.io/badge/-02569B?style=flat-square&logo=flutter&logoColor=white) [Table Habit](https://github.com/FriesI23/mhabit) | Cross-platform habit tracker with scoring, charts, and WebDAV sync. |

<!-- friesi23-projects:end -->

## License

[MIT](LICENSE), copyright (c) 2020 Belsole Davide. This fork preserves the original
license and attribution.

[pubdev-package]: https://img.shields.io/pub/v/great_list_view_plus.svg
[pubdev-likes]: https://img.shields.io/pub/likes/great_list_view_plus?logo=dart
[pubdev-points]: https://img.shields.io/pub/points/great_list_view_plus?logo=dart
[list-demo]: https://raw.githubusercontent.com/FriesI23/great_list_view_plus/master/images/list.webp
[tree-demo]: https://raw.githubusercontent.com/FriesI23/great_list_view_plus/master/images/tree.webp
