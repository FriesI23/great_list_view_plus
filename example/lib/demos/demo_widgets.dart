import 'package:great_list_view_plus/great_list_view_plus.dart';
import 'package:material_ui/material_ui.dart';

/// A compact, horizontally scrollable toolbar that also fits phone screens.
class DemoToolbar extends StatelessWidget {
  const DemoToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        for (final child in children) ...[child, const SizedBox(width: 12)],
      ],
    ),
  );
}

/// Owns a drag gesture; the parent cancels the controller before navigation.
class ReorderHandle extends StatelessWidget {
  const ReorderHandle({
    super.key,
    required this.controller,
    required this.onStarted,
    required this.onFinished,
  });

  final AnimatedListController controller;
  final VoidCallback onStarted;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerCancel: (_) {
      controller.notifyStopReorder(true);
      onFinished();
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        if (controller.notifyStartReorder(
          context,
          details.localPosition.dx,
          details.localPosition.dy,
        )) {
          onStarted();
        }
      },
      onVerticalDragUpdate: (details) {
        controller.notifyUpdateReorder(
          details.localPosition.dx,
          details.localPosition.dy,
        );
      },
      onVerticalDragEnd: (_) {
        controller.notifyStopReorder(false);
        onFinished();
      },
      onVerticalDragCancel: () {
        controller.notifyStopReorder(true);
        onFinished();
      },
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Tooltip(
          message: 'Drag to reorder',
          child: Icon(Icons.drag_handle),
        ),
      ),
    ),
  );
}
