import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../debug/morph_snapshot.dart';
import '../motion/morph_engine.dart';
import '../rendering/render_text_morph.dart';
import '../rendering/text_measurer.dart';
import '../semantics/accessibility.dart';
import 'options.dart';

/// Text that morphs from its previous value to its current one.
///
/// The Flutter port of upstream's `TextMorph` React component: this widget is
/// the controller (upstream `MorphController`), [MorphEngine] is the instance,
/// and `RenderTextMorph` is the DOM.
class TextMorph extends StatefulWidget {
  TextMorph({
    super.key,
    required this.value,
    this.cursorIndex,
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.duration = defaultDuration,
    this.ease = defaultEase,
    this.scale = true,
    this.numbers = true,
    this.decimals,
    this.blur = defaultBlur,
    this.disabled = false,
    this.respectReducedMotion = true,
    this.debug = false,
    this.onAnimationStart,
    this.onAnimationComplete,
    this.onAnimationCancel,
  }) {
    if (value is! String && value is! num) {
      throw ArgumentError.value(value, 'value', 'must be a String or a num');
    }
    // Fails here rather than on the first frame, so the stack names the caller.
    validateEase(ease);
    validateBlur(blur);
    if (duration < Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
  }

  /// A `String` used verbatim, or a `num` formatted with [locale] and
  /// [decimals] (upstream `toLocaleString`).
  final Object value;

  /// Caret position: switches a single-number value from place matching to
  /// caret matching.
  final int? cursorIndex;

  /// Merged over the enclosing `DefaultTextStyle`.
  final TextStyle? style;

  /// Null falls back to the enclosing `DefaultTextStyle`, then `start`.
  final TextAlign? textAlign;

  /// Null falls back to the ambient `Directionality`.
  final TextDirection? textDirection;

  /// Null falls back to `Localizations.maybeLocaleOf`, then `Locale('en')`
  /// (upstream's default locale).
  final Locale? locale;

  /// Ignored when [ease] is a `SpringParams`, which settles on its own physics.
  final Duration duration;

  /// A CSS easing `String` or a `SpringParams`.
  final Object ease;

  /// Whether entering and exiting items scale as well as fade.
  final bool scale;

  /// Whether numeric words morph by place value.
  final bool numbers;

  /// Fraction digits for a `num` value.
  final int? decimals;

  /// Blur sigma (logical pixels) entering items start from and exiting items
  /// fade into. Zero disables it.
  final double blur;

  /// Renders plain text, with no motion.
  final bool disabled;

  /// Whether `prefers-reduced-motion` disables motion.
  final bool respectReducedMotion;

  /// Outlines the root (magenta) and every item (cyan).
  final bool debug;

  final VoidCallback? onAnimationStart;
  final VoidCallback? onAnimationComplete;
  final VoidCallback? onAnimationCancel;

  @override
  TextMorphState createState() => TextMorphState();
}

/// The state upstream's `MorphController` holds: the engine, the last value,
/// the config key, and — Flutter's own concern — the clock.
class TextMorphState extends State<TextMorph> with SingleTickerProviderStateMixin<TextMorph> {
  late final Ticker _ticker;

  MorphEngine? _engine;
  _MeasurerRef? _measurerRef;
  RenderTextMorph? _render;
  FrameState? _frame;

  // Resolved inputs, kept to detect changes.
  MorphConfigKey? _configKey;
  TextStyle _style = const TextStyle();
  TextScaler _textScaler = TextScaler.noScaling;
  TextDirection _direction = TextDirection.ltr;
  Locale _locale = const Locale(defaultLocaleTag);
  TextAlign _align = TextAlign.start;
  TextHeightBehavior? _textHeightBehavior;

  /// Upstream `MorphController.lastText` / `lastCursorIndex`.
  Object _lastValue = '';
  int? _lastCursorIndex;
  bool _hasValue = false;

  /// Engine time, in milliseconds: what elapsed before the current ticker run.
  double _base = 0;
  double _elapsedMs = 0;

  final List<VoidCallback> _deferred = <VoidCallback>[];
  bool _flushScheduled = false;
  bool _disposed = false;

  double get _engineTime => _base + _elapsedMs;

  /// The engine, for tests. Null before the first `didChangeDependencies`.
  MorphEngine? get debugEngine => _engine;

  /// The last frame handed to the render object.
  TextMorphSnapshot? debugSnapshot() {
    final frame = _frame;
    return frame == null ? null : TextMorphSnapshot(frame);
  }

  bool get debugTickerActive => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    // createTicker, so TickerMode mutes it.
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TextMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  // ─── configuration ───

  void _sync() {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = widget.textDirection ?? Directionality.of(context);
    final locale = widget.locale ?? Localizations.maybeLocaleOf(context) ?? const Locale(defaultLocaleTag);
    final align = widget.textAlign ?? DefaultTextStyle.of(context).textAlign ?? TextAlign.start;
    final textHeightBehavior = DefaultTextStyle.of(context).textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context);

    // Read live at every update, as upstream reads the media query.
    final disabled = isMorphDisabled(
      context,
      disabled: widget.disabled,
      respectReducedMotion: widget.respectReducedMotion,
    );

    final geometryChanged = _measurerRef == null ||
        style != _style ||
        textScaler != _textScaler ||
        direction != _direction ||
        locale != _locale ||
        align != _align ||
        textHeightBehavior != _textHeightBehavior;

    _style = style;
    _textScaler = textScaler;
    _direction = direction;
    _locale = locale;
    _align = align;
    _textHeightBehavior = textHeightBehavior;

    final configKey = MorphConfigKey(
      ease: widget.ease,
      duration: widget.duration,
      locale: locale.toLanguageTag(),
      scale: widget.scale,
      numbers: widget.numbers,
      decimals: widget.decimals,
      blur: widget.blur,
      debug: widget.debug,
      disabled: widget.disabled,
      respectReducedMotion: widget.respectReducedMotion,
    );

    if (geometryChanged) {
      final measurer = TextMeasurer(
        style: style,
        textScaler: textScaler,
        textDirection: direction,
        textAlign: align,
        locale: locale,
        textHeightBehavior: textHeightBehavior,
      );
      final ref = _measurerRef;
      if (ref == null) {
        _measurerRef = _MeasurerRef(measurer);
      } else {
        // The engine holds the reference, not the measurer itself, so a
        // rebuilt measurer never leaves it looking at disposed painters.
        final old = ref.measurer;
        ref.measurer = measurer;
        old.dispose();
      }
    }

    final recreate = _engine == null || configKey != _configKey;
    _configKey = configKey;

    var updated = false;

    if (recreate) {
      // Upstream `MorphController.attach`: destroy, recreate, replay the last
      // value — which the fresh instance renders as an initial render.
      _engine?.dispose();
      _engine = MorphEngine(measurer: _measurerRef!, config: _buildConfig(locale));
      _stopTicker();
      _base = 0;
      _elapsedMs = 0;
      if (_hasValue) {
        _engine!.update(_lastValue, cursorIndex: _lastCursorIndex, disabled: disabled);
      }
      // A value that changed in the same frame as the config still morphs, as
      // upstream's two effects do: attach replays, then the value effect runs.
      if (!_hasValue ||
          !_sameValue(widget.value, _lastValue) ||
          widget.cursorIndex != _lastCursorIndex) {
        _engine!.update(widget.value, cursorIndex: widget.cursorIndex, disabled: disabled);
      }
      updated = true;
    } else {
      if (geometryChanged) {
        // The scene keeps its morph history; only its geometry is restated.
        _engine!.remeasure();
        updated = true;
      }
      final valueChanged = !_hasValue ||
          !_sameValue(widget.value, _lastValue) ||
          widget.cursorIndex != _lastCursorIndex;
      if (valueChanged) {
        _engine!.update(widget.value, cursorIndex: widget.cursorIndex, disabled: disabled);
        updated = true;
      }
    }

    _lastValue = widget.value;
    _lastCursorIndex = widget.cursorIndex;
    _hasValue = true;

    if (updated || _frame == null) {
      // The frame the update happened in must also be delivered, so a
      // play-pending track starts at the update's instant.
      _frame = _engine!.frame(_engineTime);
      if (_engine!.isAnimating) {
        _startTicker();
      } else {
        _stopTicker();
      }
    }
  }

  static bool _sameValue(Object a, Object b) => a == b && a.runtimeType == b.runtimeType;

  MorphConfig _buildConfig(Locale locale) => buildMorphConfig(
        ease: widget.ease,
        duration: widget.duration,
        locale: locale.toLanguageTag(),
        scale: widget.scale,
        numbers: widget.numbers,
        decimals: widget.decimals,
        blur: widget.blur,
        debug: widget.debug,
        // Read through the latest widget, never captured.
        onAnimationStart: () => _fire(widget.onAnimationStart),
        onAnimationComplete: () => _fire(widget.onAnimationComplete),
        onAnimationCancel: () => _fire(widget.onAnimationCancel),
      );

  // ─── callbacks (DEV-003) ───

  /// The engine calls back synchronously, and `update` runs inside the build
  /// phase where user `setState` is illegal — so a callback raised there is
  /// queued and flushed at the end of the same frame, order preserved.
  void _fire(VoidCallback? callback) {
    if (callback == null || _disposed) return;
    switch (SchedulerBinding.instance.schedulerPhase) {
      case SchedulerPhase.idle:
      case SchedulerPhase.transientCallbacks:
      case SchedulerPhase.postFrameCallbacks:
        callback();
      case SchedulerPhase.midFrameMicrotasks:
      case SchedulerPhase.persistentCallbacks:
        _deferred.add(callback);
        if (!_flushScheduled) {
          _flushScheduled = true;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _flushScheduled = false;
            final pending = List<VoidCallback>.of(_deferred);
            _deferred.clear();
            if (_disposed) return;
            for (final cb in pending) {
              cb();
            }
          });
        }
    }
  }

  // ─── clock ───

  void _startTicker() {
    if (_ticker.isActive) return;
    _elapsedMs = 0;
    _ticker.start();
  }

  void _stopTicker() {
    if (!_ticker.isActive) return;
    _base = _engineTime;
    _elapsedMs = 0;
    _ticker.stop();
  }

  void _onTick(Duration elapsed) {
    _elapsedMs = elapsed.inMicroseconds / 1000.0;
    final engine = _engine;
    if (engine == null) return;
    final frame = engine.frame(_engineTime);
    _frame = frame;
    _render?.frame = frame;
    if (!frame.animating) _stopTicker();
  }

  @override
  void dispose() {
    _disposed = true;
    _deferred.clear();
    _ticker.dispose();
    _engine?.dispose();
    _measurerRef?.measurer.dispose();
    _render = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextMorphRenderWidget(
      frame: _frame!,
      measurer: _measurerRef!.measurer,
      style: _style,
      textDirection: _direction,
      debug: widget.debug,
      onRenderObject: (render) => _render = render,
    );
  }
}

/// A stable [Measurer] the engine can hold across measurer rebuilds: geometry
/// inputs change by swapping the [TextMeasurer] behind this reference.
class _MeasurerRef implements Measurer {
  _MeasurerRef(this.measurer);

  TextMeasurer measurer;

  @override
  MeasureResult measure(List<MorphItem> items, {double? width}) =>
      measurer.measure(items, width: width);
}
