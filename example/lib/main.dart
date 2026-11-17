import 'package:material_ui/material_ui.dart';

import 'demos/list_demo.dart';
import 'demos/tree_demo.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _listKey = GlobalKey<ListDemoPageState>();
  final _treeKey = GlobalKey<TreeDemoPageState>();
  int _selected = 0;

  void _select(int index) {
    if (index == _selected) return;
    _listKey.currentState?.cancelDrag();
    _treeKey.currentState?.cancelDrag();
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'great_list_view_plus',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: Scaffold(
      appBar: AppBar(title: const Text('great_list_view_plus')),
      body: SafeArea(
        child: IndexedStack(
          index: _selected,
          children: [
            TickerMode(
              enabled: _selected == 0,
              child: ListDemoPage(key: _listKey),
            ),
            TickerMode(
              enabled: _selected == 1,
              child: TreeDemoPage(key: _treeKey),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.view_list), label: 'List'),
          NavigationDestination(icon: Icon(Icons.account_tree), label: 'Tree'),
        ],
      ),
    ),
  );
}
