library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A ticker provider that can be used without necessarily having a [StatefulWidget].
mixin TickerProviderMixin implements TickerProvider {
  Set<_WidgetTicker>? _tickers;

  @override
  Ticker createTicker(TickerCallback onTick) {
    _tickers ??= <_WidgetTicker>{};
    final result = _WidgetTicker(onTick, this, debugLabel: 'created by $this');
    _tickers!.add(result);
    return result;
  }

  void _removeTicker(_WidgetTicker ticker) {
    assert(_tickers != null);
    assert(_tickers!.contains(ticker));
    _tickers!.remove(ticker);
  }

  bool get hasActiveTickers =>
      _tickers != null && _tickers!.any((t) => t.isActive);

  void dispose() {
    assert(() {
      if (_tickers != null) {
        for (final ticker in _tickers!) {
          if (ticker.isActive) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('$this was disposed with an active Ticker.'),
              ErrorDescription(
                '$runtimeType created a Ticker via its TickerProviderMixin, but at the time '
                'dispose() was called on the mixin, that Ticker was still active. All Tickers must '
                'be disposed before calling dispose().',
              ),
              ErrorHint(
                'Tickers used by AnimationControllers '
                'should be disposed by calling dispose() on the AnimationController itself. '
                'Otherwise, the ticker will leak.',
              ),
              ticker.describeForError('The offending ticker was'),
            ]);
          }
        }
      }
      return true;
    }());
  }

  void updateTickerMuted(BuildContext context) {
    final mode = TickerMode.valuesOf(context);
    if (_tickers != null) {
      for (final ticker in _tickers!) {
        ticker
          ..muted = !mode.enabled
          ..forceFrames = mode.forceFrames;
      }
    }
  }
}

class _WidgetTicker extends Ticker {
  _WidgetTicker(super.onTick, this._creator, {super.debugLabel});

  final TickerProviderMixin _creator;

  @override
  void dispose() {
    _creator._removeTicker(this);
    super.dispose();
  }
}
