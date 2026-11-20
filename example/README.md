# great_list_view_plus example

The bottom navigation separates **List** and **Tree**. Each page keeps its state
when switching tabs; restart the app to restore all list data.

| Page / mode | Try it |
| --- | --- |
| List / Automatic | Press **Switch data** to animate insertions, removals, moves and content/height changes. Toggle **Morph** to compare transitions. |
| List / Manual | Use **Insert**, **Change**, **Remove**, **Replace**, **Move range** and **Batch**. These update application data and explicitly notify the controller. |
| List / Sliver | Press **Dispatch new list** to use an explicit diff dispatcher with a header, animated sliver and footer. Toggle **Fixed extent** for both sliver implementations. |
| List controls | Choose **Long press** or **Drag handle** for sorting. Toggle **Slow animation** for custom durations and curves. Enter a zero-based **Index** and press **Scroll to index**. On phones, scroll the toolbars horizontally for more controls. |
| Tree / Animated list | Select a node, **Add child** or **Delete subtree**, and use the arrow to expand/collapse. Long press a leaf or closed branch, drag vertically to reorder and sideways (24 logical pixels per level) to change parent. The dragged row previews its permitted indentation. |
| Tree / Plain ListView | The same callback-defined data feeds a standard ListView, with expansion and subtree editing. Tree data and expansion survive host changes; each host retains its scroll position. |

The tree root stays visible and cannot be deleted or dragged. An open branch
closes on its first long press; long press it again to move the entire closed
subtree. Pointer cancellation and tab/mode changes cancel active drags.
**Reset tree** restores deterministic sample data.

From the repository root, run `fvm install`, `fvm use 3.47.9 --skip-pub-get`, and
`make bootstrap`. `make analyze` checks the package and example together, and
`make test` runs both test suites. The example shares the root FVM pin and minimum
SDK requirements.

The example includes Android, iOS, macOS, Windows, and Linux runner projects,
generated with Flutter 3.47.9. Each platform uses the same Dart example and the
local package dependency. The package currently supports these five native
platforms; its `dart:io` and worker implementation does not support web.

## Run

From this directory, use the SDK selected by the repository's FVM configuration:

```sh
fvm flutter devices
fvm flutter run -d <device-id>
```

Use `-d macos`, `-d windows`, or `-d linux` for the desktop host. Android and iOS
can run on a connected device or an emulator/simulator. A physical iOS device
requires selecting your own signing team in `ios/Runner.xcworkspace`.

## Build

From this directory, use Flutter's build commands directly:

```sh
fvm flutter build apk --debug
fvm flutter build ios --simulator --debug
fvm flutter build macos --debug
fvm flutter build windows --debug
fvm flutter build linux --debug
```

Build on the corresponding host: Android needs its SDK and JDK 17; iOS and macOS
need macOS and Xcode; Windows needs Visual Studio with desktop C++ tooling; Linux
needs Clang, CMake, Ninja, pkg-config, GTK 3 development files, and the C++ standard
library development files. See [Flutter platform setup](https://docs.flutter.dev/platform-integration).

Use `--release` instead of `--debug` for local release builds. Android release
builds use the template's debug signing configuration for demonstration;
publishing an app requires your own identity and signing configuration.

## README recordings

The README gallery is rendered from this app with scripted widget gestures.
It records automatic/manual/sliver list updates, drag handles, and tree editing
and cross-parent moves. These recordings show the Flutter UI; they do not
represent native device acceptance tests.

Install the WebP tools (`brew install webp` on macOS), then run from the
repository root:

```sh
make bootstrap
make capture-demos
```

The command requires Bash and `img2webp`. It loads real app fonts, captures a
1100 x 900 light canvas at 83 ms intervals, and writes looping 880 x 720 WebP
animations to `images/list.webp` and `images/tree.webp`. Intermediate PNG frames
stay in `build/example-demos/`, which is ignored by Git. The gallery media stays
in Git and is excluded from the published package.
