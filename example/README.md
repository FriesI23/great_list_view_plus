# great_list_view_plus example

A list that animates between two data sets and supports long-press reordering.
Tap a row to switch lists.

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

CI runs the shared `make test` entry point for package and example tests, plus
analysis, with Flutter 3.47.0 and 3.47.9. The example has no separate CI job or
matrix. Build and run it locally using the Flutter commands above.
