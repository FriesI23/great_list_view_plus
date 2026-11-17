/// List animation policy, defaults and interval animation lifecycle.
library;

import 'package:flutter/widgets.dart';

/// Default duration of a dismiss or incoming animation.
const Duration kDismissOrIncomingAnimationDuration = Duration(
  milliseconds: 500,
);

/// Default duration of a resizing animation.
const Duration kResizeAnimationDuration = Duration(milliseconds: 500);

/// Default duration of a reordering animation.
const Duration kReorderAnimationDuration = Duration(milliseconds: 250);

/// Default duration of a moving animation.
const Duration kMovingAnimationDuration = Duration(milliseconds: 500);

/// Default curve of a dismiss or incoming animation.
const Curve kDismissOrIncomingAnimationCurve = Curves.ease;

/// Default curve of a resizing animation.
const Curve kResizeAnimationCurve = Curves.easeInOut;

/// Default curve of a reordering animation.
const Curve kReorderAnimationCurve = Curves.linear;

/// Default curve of a moving animation.
const Curve kMovingAnimationCurve = Curves.easeInOut;

/// Default value of the `Material.elevation`.
const double kDefaultAnimatedElevation = 10.0;

/// Default duration of the `MorphTransition` effect.
const Duration kDefaultMorphTransitionDuration = Duration(milliseconds: 500);

/// This interface can be implemented to customize all animations.
/// [DefaultAnimatedListAnimator] is the default implementation.
abstract class AnimatedListAnimator {
  const AnimatedListAnimator();

  /// Provides info about the animation of an outgoing item.
  AnimatedListAnimationData dismiss();

  /// Provides info about the animation of an incoming item.
  AnimatedListAnimationData incoming();

  /// Provides info about the animation of an incoming item that doesn't complete and
  /// is turning into an outgoing item.
  /// The current [time] of the incoming animation is provided (`0` indicates that is
  /// just started whereas `1` is pratically completed).
  AnimatedListAnimationData dismissDuringIncoming(double time);

  /// Provides info about the animation of a resizing interval (space between items)
  /// that appear after removing/replacing old items or before inserting new ones.
  /// The starting [fromSize] and ending [toSize] measures of the interval are also provided.
  AnimatedListAnimationData resizing(double fromSize, double toSize);

  /// Provides info about the animation of a resizing interval (space between items)
  /// that appear only during reordering.
  /// The starting [fromSize] and ending [toSize] sizes of the interval are also provided.
  AnimatedListAnimationData resizingDuringReordering(
    double fromSize,
    double toSize,
  );

  /// Provides info about the animation of a moving item.
  AnimatedListAnimationData moving();
}

/// Holds information about an animation.
///
/// The [animation] attribute is used to convert the linear animation (from `0.0` to `1.0`) in a customized way,
/// like [Tween]s.
///
/// The [duration] attribute indicates the duration of the entire animation.
///
/// The [startTime] attribute, if is greater than zero, indicates that the animation won't start from the beginning
/// but at a specific point.
class AnimatedListAnimationData {
  const AnimatedListAnimationData(
    this.animation,
    this.duration, [
    this.startTime = 0.0,
  ]) : assert(startTime >= 0.0 && startTime <= 1.0);

  final Animatable<double> animation;
  final Duration duration;
  final double startTime;
}

/// Default implementation of the inteface [AnimatedListAnimator] that uses [CurveTween]s objects.
/// Custom animation durations and curves can also be provided.
class DefaultAnimatedListAnimator extends AnimatedListAnimator {
  const DefaultAnimatedListAnimator({
    this.dismissIncomingDuration = kDismissOrIncomingAnimationDuration,
    this.resizeDuration = kResizeAnimationDuration,
    this.reorderDuration = kReorderAnimationDuration,
    this.movingDuration = kMovingAnimationDuration,
    this.dismissIncomingCurve = kDismissOrIncomingAnimationCurve,
    this.resizeCurve = kResizeAnimationCurve,
    this.reorderCurve = kReorderAnimationCurve,
    this.movingCurve = kMovingAnimationCurve,
  });

  final Duration dismissIncomingDuration,
      resizeDuration,
      reorderDuration,
      movingDuration;
  final Curve dismissIncomingCurve, resizeCurve, reorderCurve, movingCurve;

  /// See [AnimatedListAnimator.dismissDuringIncoming].
  @override
  AnimatedListAnimationData dismissDuringIncoming(double dismissTime) {
    return AnimatedListAnimationData(
      Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: dismissIncomingCurve.flipped)),
      dismissIncomingDuration,
      1.0 - dismissTime,
    );
  }

  /// See [AnimatedListAnimator.dismiss].
  @override
  AnimatedListAnimationData dismiss() {
    return AnimatedListAnimationData(
      Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: dismissIncomingCurve)),
      dismissIncomingDuration,
    );
  }

  /// See [AnimatedListAnimator.incoming].
  @override
  AnimatedListAnimationData incoming() {
    return AnimatedListAnimationData(
      CurveTween(curve: dismissIncomingCurve),
      dismissIncomingDuration,
    );
  }

  /// See [AnimatedListAnimator.resizing].
  @override
  AnimatedListAnimationData resizing(double fromSize, double toSize) {
    return AnimatedListAnimationData(
      CurveTween(curve: resizeCurve),
      resizeDuration,
    );
  }

  /// See [AnimatedListAnimator.resizingDuringReordering].
  @override
  AnimatedListAnimationData resizingDuringReordering(
    double fromSize,
    double toSize,
  ) {
    return AnimatedListAnimationData(
      CurveTween(curve: reorderCurve),
      reorderDuration,
    );
  }

  /// See [AnimatedListAnimator.moving].
  @override
  AnimatedListAnimationData moving() {
    return AnimatedListAnimationData(
      CurveTween(curve: movingCurve),
      movingDuration,
    );
  }
}

// Interval runtime: policies above describe animations; these objects run them.

abstract class IntervalAnimation<T> {
  const IntervalAnimation();

  Animation<double> get animation;
  double get time;

  double futureValue(double time);

  bool get isWaitingAtBeginning =>
      time == 0.0 && animation.status == AnimationStatus.dismissed;
  bool get isWaitingAtEnd =>
      time == 1.0 && animation.status == AnimationStatus.completed;

  void attachTo(T interval) {}
  void detachFrom(T interval) {}
  void dispose() {}
}

class ControlledAnimation<T> extends IntervalAnimation<T> {
  ControlledAnimation(
    TickerProvider vsync,
    this.animatable,
    Duration duration, {
    double startTime = 0.0,
    this.onDispose,
    this.onCompleted,
  }) : assert(startTime >= 0.0 && startTime <= 1.0),
       _controller = AnimationController(
         value: startTime,
         vsync: vsync,
         duration: duration,
       ) {
    _animation = _controller.drive(animatable);
  }

  final Animatable<double> animatable;
  final AnimationController _controller;
  final intervals = <T>{};
  final void Function(ControlledAnimation<T> a)? onDispose;
  final void Function(ControlledAnimation<T> a)? onCompleted;

  bool _disposed = false;
  late Animation<double> _animation;

  @override
  Animation<double> get animation => _animation;

  @override
  double get time => _controller.value;

  double get value => animation.value;

  double get durationInSec => _controller.duration!.inMicroseconds / 1000000.0;

  double get timeInSec => time * durationInSec;

  @override
  double futureValue(double time) {
    final t = (_controller.value + time).clamp(0.0, 1.0);
    return animatable.transform(t);
  }

  @override
  void attachTo(T interval) {
    assert(_debugAssertNotDisposed());
    assert(!intervals.contains(interval));
    intervals.add(interval);
  }

  @override
  void detachFrom(T interval) {
    assert(_debugAssertNotDisposed());
    assert(intervals.contains(interval));
    intervals.remove(interval);
    if (intervals.isEmpty) {
      dispose();
    }
  }

  @override
  void dispose() {
    assert(_debugAssertNotDisposed());
    assert(intervals.isEmpty);
    _controller.dispose();
    _disposed = true;
    super.dispose();
    onDispose?.call(this);
  }

  void start() {
    assert(_debugAssertNotDisposed());
    _controller.forward().whenComplete(_onCompleted);
  }

  void stop() {
    assert(_debugAssertNotDisposed());
    _controller.stop();
  }

  void reset() {
    assert(_debugAssertNotDisposed());
    _controller.value = 0.0;
  }

  void complete() {
    assert(_debugAssertNotDisposed());
    _controller.value = 1.0;
    Future.microtask(_onCompleted);
  }

  void _onCompleted() {
    if (!_disposed) {
      onCompleted?.call(this);
    }
  }

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_disposed) {
        throw FlutterError(
          'A $runtimeType was used after being disposed.\n'
          'Once you have called dispose() on a $runtimeType, it can no longer be used.',
        );
      }
      return true;
    }());
    return true;
  }

  @override
  String toString() =>
      'attachedTo: $intervals, time: $time, value: $value${_disposed ? ' DISPOSED' : ''}';
}

class CompletedAnimation<T> extends IntervalAnimation<T> {
  const CompletedAnimation();

  @override
  Animation<double> get animation => kAlwaysCompleteAnimation;

  @override
  double get time => 1;

  @override
  double futureValue(double time) => 1;
}

class DismissedAnimation<T> extends IntervalAnimation<T> {
  const DismissedAnimation();

  @override
  Animation<double> get animation => kAlwaysDismissedAnimation;

  @override
  double get time => 0;

  @override
  double futureValue(double time) => 0;
}
