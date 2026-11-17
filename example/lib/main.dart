import 'package:great_list_view_plus/great_list_view_plus.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _listController = AnimatedListController();
  final _scrollController = ScrollController();
  bool _showingFirstList = true;
  final _firstItems = List.of(_firstList);
  final _secondItems = List.of(_secondList);
  late List<_ItemData> _items = _firstItems;

  void _swapList() {
    setState(() {
      _showingFirstList = !_showingFirstList;
      _items = _showingFirstList ? _firstItems : _secondItems;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_list_view_plus',
      home: SafeArea(
        child: Scaffold(
          body: Scrollbar(
            controller: _scrollController,
            child: AutomaticAnimatedListView<_ItemData>(
              list: _items,
              listController: _listController,
              scrollController: _scrollController,
              comparator: AnimatedListDiffListComparator<_ItemData>(
                sameItem: (a, b) => a.id == b.id,
                sameContent: (a, b) =>
                    a.color == b.color && a.height == b.height,
              ),
              itemBuilder: (context, item, data) => data.measuring
                  ? Container(
                      margin: const EdgeInsets.all(5),
                      height: item.height,
                    )
                  : _Item(data: item, onTap: _swapList),
              reorderModel: AutomaticAnimatedListReorderModel(_items),
              detectMoves: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.data, required this.onTap});

  final _ItemData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        height: data.height,
        duration: const Duration(milliseconds: 500),
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: data.color,
          border: Border.all(color: Colors.black12, width: 0),
        ),
        child: Center(
          child: Text('Item ${data.id}', style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _ItemData {
  const _ItemData(this.id, [this.color = Colors.blue, this.height = 60]);

  final int id;
  final Color color;
  final double height;
}

const _firstList = [
  _ItemData(1, Colors.orange),
  _ItemData(2),
  _ItemData(3),
  _ItemData(4, Colors.cyan),
  _ItemData(5),
  _ItemData(8, Colors.green),
];

const _secondList = [
  _ItemData(4, Colors.cyan),
  _ItemData(2),
  _ItemData(6),
  _ItemData(5, Colors.pink, 100),
  _ItemData(7),
  _ItemData(8, Colors.yellowAccent),
];
