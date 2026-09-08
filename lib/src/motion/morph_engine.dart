import '../core/diff.dart';
import '../core/number.dart';
import '../core/replacement.dart';
import '../core/segment.dart';
import '../core/segmenter.dart';
import 'carry.dart';
import 'container_motion.dart';
import 'easing.dart';
import 'flip.dart';
import 'track.dart';

typedef Point = ({double x, double y});
typedef Extent = ({double width, double height});

/// Resolved options the engine runs with (upstream `this.options` after
/// `resolveEase`).
class MorphConfig {
  MorphConfig({
    this.locale = 'en',
    this.duration = 400,
    this.ease = 'cubic-bezier(0.19, 1, 0.22, 1)',
    this.scale = true,
    this.numbers = true,
    this.decimals,
    this.blur = 0,
    this.debug = false,
    this.onAnimationStart,
    this.onAnimationComplete,
    this.onAnimationCancel,
  }) : easeFn = parseEasing(ease) ??
            (throw ArgumentError.value(ease, 'ease', 'unsupported CSS easing')) {
    if (!(duration >= 0)) {
      throw ArgumentError.value(duration, 'duration', 'must be a finite, non-negative number');
    }
    if (!blur.isFinite || blur < 0) {
      throw ArgumentError.value(blur, 'blur', 'must be a finite, non-negative number');
    }
  }

  final String locale;

  /// Milliseconds. Already replaced by the spring's own duration when `ease`
  /// was a spring.
  final double duration;

  /// The CSS easing string WAAPI would receive; `easeFn` is its evaluation.
  final String ease;
  final EasingFn easeFn;
  final bool scale;
  final bool numbers;
  final int? decimals;

  /// Blur sigma in logical pixels; zero adds no blur tracks at all.
  final double blur;
  final bool debug;
  final void Function()? onAnimationStart;
  final void Function()? onAnimationComplete;
  final void Function()? onAnimationCancel;
}

enum Lifecycle { rest, entering, persisting, exiting, groupEntering, groupExiting }

/// One `[torph-item]` element: a retained logical object, never a widget.
class MorphItem {
  MorphItem(this.id, this.string, {this.kind}) {
    syncSlot(kind);
  }

  final String id;
  String string;
  SegmentKind? kind;

  bool get isBreak => string == '\n';

  bool exiting = false;
  Lifecycle lifecycle = Lifecycle.rest;

  /// Layout box relative to the root. In flow: from the last measurement.
  /// Exiting: pinned (`position: absolute; left/top/width/height`).
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;

  /// `transform-origin`, relative to the item box; null is the CSS default
  /// (the box centre).
  Point? transformOrigin;

  final AnimatedBox box = AnimatedBox();

  /// The nested span a numeric character slides inside (upstream `moverOf`).
  AnimatedBox? mover;

  /// The fade whose `onfinish` removes an exiting element.
  Track<double>? removeWhen;

  /// Gives a numeric character the nested box its slide needs, and takes it
  /// away when it stops being one — both directions on a reused element.
  void syncSlot(SegmentKind? newKind) {
    kind = newKind;
    if (newKind == null) {
      mover = null;
    } else {
      mover ??= AnimatedBox();
    }
  }

  /// `moverOf(element)`: the nested span for a slot, else the element itself.
  AnimatedBox get moverBox => mover ?? box;

  Point get origin => transformOrigin ?? (x: width / 2, y: height / 2);
}

/// Root-relative layout of live items, as the DOM would lay them out under a
/// given container width (`white-space: nowrap`, inline-block items, `<br>`
/// line breaks, `text-align`).
class MeasureResult {
  const MeasureResult({
    required this.offsets,
    required this.sizes,
    required this.naturalWidth,
    required this.naturalHeight,
  });

  final Map<String, Point> offsets;
  final Map<String, Extent> sizes;
  final double naturalWidth;
  final double naturalHeight;
}

/// The geometry authority (TextPainter in Flutter, a fake in tests).
abstract class Measurer {
  /// Lays out [items] in order. [width] pins the container width (upstream
  /// `element.style.width = ...px`), null lets it take its natural width.
  MeasureResult measure(List<MorphItem> items, {double? width});
}

/// Everything painted at one instant.
class ItemFrame {
  const ItemFrame({
    required this.id,
    required this.text,
    required this.kind,
    required this.exiting,
    required this.isBreak,
    required this.lifecycle,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.transform,
    required this.originX,
    required this.originY,
    required this.opacity,
    required this.blur,
    required this.moverTransform,
    required this.moverOpacity,
    required this.moverBlur,
  });

  final String id;
  final String text;
  final SegmentKind? kind;
  final bool exiting;
  final bool isBreak;
  final Lifecycle lifecycle;
  final double x;
  final double y;
  final double width;
  final double height;
  final Transform2 transform;
  final double originX;
  final double originY;
  final double opacity;
  final double blur;

  /// Present for numeric slots only.
  final Transform2? moverTransform;
  final double? moverOpacity;
  final double? moverBlur;

  /// The box after its transform, in root coordinates.
  ({double left, double top, double right, double bottom}) get visualRect {
    final ox = x + originX;
    final oy = y + originY;
    final l = ox + (x - ox) * transform.sx + transform.tx;
    final t = oy + (y - oy) * transform.sy + transform.ty;
    final r = ox + (x + width - ox) * transform.sx + transform.tx;
    final b = oy + (y + height - oy) * transform.sy + transform.ty;
    return (left: l, top: t, right: r, bottom: b);
  }
}

class FrameState {
  const FrameState({
    required this.now,
    required this.width,
    required this.height,
    required this.naturalWidth,
    required this.naturalHeight,
    required this.items,
    required this.animating,
    required this.value,
    required this.plainText,
  });

  final double now;

  /// The root's layout size right now (animated or natural).
  final double width;
  final double height;
  final double naturalWidth;
  final double naturalHeight;
  final List<ItemFrame> items;
  final bool animating;

  /// The accessible value.
  final String value;

  /// Non-null while disabled: the value is drawn as plain text.
  final String? plainText;
}

// Shares of the morph, not fixed lengths.
const double _textExitFade = 0.25;
const double _textEnterFade = 0.5;
const double _textEnterDelay = 0.25;
const double _textPersistFade = 0.25;
const double _numberExitFade = 0.45;
const double _numberEnterFade = 0.25;
const double _groupExitFade = 0.45;
const double _groupEnterFade = 0.35;
const double _itemScale = 0.95;

/// The port of upstream `TextMorph` (lib/text-morph/index.ts): reconciliation
/// plus the WAAPI-equivalent timeline. Time is injected; nothing here touches
/// Flutter.
class MorphEngine {
  MorphEngine({required this.measurer, required this.config});

  final Measurer measurer;
  MorphConfig config;

  /// Children of the root in DOM order: exiting first, then live in value order.
  final List<MorphItem> items = [];
  List<Segment> previousSegments = [];
  bool isInitialRender = true;

  /// Upstream `this.data` starts as `""`, so a first `update("")` is a no-op.
  String data = '';
  String accessibleValue = '';
  String? plainText;

  ContainerTransition? _container;
  Measures _prevMeasures = {};
  Measures _currentMeasures = {};
  double _naturalWidth = 0;
  double _naturalHeight = 0;

  /// The last frame time, in ms. Reads during an update see this instant.
  double now = 0;

  bool _disabled = false;

  bool get disabled => _disabled;

  ContainerTransition? get containerTransition => _container;

  List<MorphItem> get liveItems => items.where((i) => !i.exiting).toList();

  /// `layoutSize(element)`: the box a width/height write means — the
  /// in-flight animated size, else the natural size of the current content.
  Extent layoutSize() {
    final c = _container;
    if (c != null && !c.stopped) return (width: c.widthAt(now), height: c.heightAt(now));
    return (width: _naturalWidth, height: _naturalHeight);
  }

  /// Whether the root currently has a pinned width (in-flight transition or hold).
  double? get _pinnedWidth {
    final c = _container;
    return c != null && !c.stopped ? c.widthAt(now) : null;
  }

  /// `update(value, cursorIndex)`. [value] is a String or a num.
  void update(Object value, {int? cursorIndex, required bool disabled}) {
    final formatted = value is num
        ? formatNumber(value, config.locale, config.decimals)
        : value as String;

    if (formatted == data) return;
    data = formatted;

    if (disabled) {
      _disabled = true;
      plainText = formatted;
      accessibleValue = formatted;
      for (final item in items) {
        item.box.cancelAll();
        item.mover?.cancelAll();
      }
      items.clear();
      // A later diff against these would animate from elements no longer in the DOM.
      previousSegments = [];
      isInitialRender = true;
      final natural = measurer.measure(const [], width: null);
      _naturalWidth = natural.naturalWidth;
      _naturalHeight = natural.naturalHeight;
      return;
    }
    _disabled = false;
    plainText = null;

    if (config.onAnimationStart != null && !isInitialRender) {
      config.onAnimationStart!();
    }
    _createTextGroup(formatted, cursorIndex);
  }

  void _createTextGroup(String value, int? cursorIndex) {
    // Before the running transition is aborted below, so an interrupt carries
    // on from screen.
    final old = layoutSize();
    final oldWidth = old.width;
    final oldHeight = old.height;
    final numbers = config.numbers;

    accessibleValue = value;

    List<Segment> segments;
    Map<String, List<Segment>> splits;

    if (previousSegments.isNotEmpty) {
      final result = diffSegments(
        previousSegments,
        value,
        config.locale,
        DiffOptions(numbers: numbers, cursorIndex: cursorIndex),
      );
      segments = result.segments;
      splits = result.splits;
    } else {
      segments = segmentText(value, config.locale, numbers: numbers);
      splits = {};
    }

    // A zero-width space keeps in-flow content, preserving line box height during exits.
    final isEmptyTransition = segments.isEmpty;
    if (isEmptyTransition) {
      segments = [const Segment(emptyId, emptyString)];
    }

    _splitWordSpans(splits);

    _prevMeasures = _measureInto(liveItems, width: _pinnedWidth);

    final oldChildren = List<MorphItem>.of(items);
    final newIds = segments.map((b) => b.id).toSet();

    final exiting = oldChildren
        .where((child) => !newIds.contains(child.id) && !child.exiting)
        .toList();

    final oldIds = oldChildren.map((c) => c.id).toList();
    final exitingIdx = {
      for (var i = 0; i < oldChildren.length; i++)
        if (exiting.contains(oldChildren[i])) i,
    };
    final exitingAnchorByIndex = resolveExitingAnchors(oldIds, exitingIdx, newIds);
    final exitingAnchorId = <MorphItem, String?>{
      for (final i in exitingIdx) oldChildren[i]: exitingAnchorByIndex[i],
    };

    _detachFromFlow(exiting);
    _reconcileChildren(oldChildren, newIds, segments);

    final live = liveItems;
    final measured = _measureInto(live, width: _pinnedWidth, natural: true);
    _currentMeasures = measured;

    // One line's worth. The root is nowrap, so a line exists only where the value put one.
    final lineCount = segments.where((s) => s.string == '\n').length + 1;
    final blockHeight = _pinnedHeight ?? _naturalHeight;
    final offsetHeight = jsRound(blockHeight);
    final slideDistance = (offsetHeight != 0 ? offsetHeight : 20 * lineCount) / lineCount;

    // Measured at the old width, not derived — text-align does nothing to
    // overflowing content.
    final firstFrameMeasures = _measureInto(live, width: oldWidth, apply: false);

    _updateStyles(segments, firstFrameMeasures, slideDistance);

    // A run with no survivors inside it recedes as one shape.
    final leavingRuns = isInitialRender
        ? <List<MorphItem>>[]
        : replacedRuns(oldChildren, exiting.toSet());
    final leavingTogether = leavingRuns.expand((r) => r).toSet();

    for (final run in leavingRuns) {
      _animateGroupExit(run);
    }

    for (final child in exiting) {
      if (isInitialRender || child.id == emptyId) {
        items.remove(child);
        continue;
      }
      if (leavingTogether.contains(child)) continue;

      final anchorId = exitingAnchorId[child];
      final delta = anchorId != null
          ? computeDelta(_currentMeasures, _prevMeasures, anchorId)
          : (dx: 0.0, dy: 0.0);

      if (child.kind != null) {
        _animateNumberExit(child, delta.dx, delta.dy, slideDistance);
      } else {
        _animateExit(child, delta.dx, delta.dy);
      }
    }

    previousSegments = segments;

    if (isInitialRender) {
      isInitialRender = false;
      return;
    }

    if (isEmptyTransition) {
      _holdContainerSize(oldWidth, oldHeight);
    } else {
      _transitionContainerSize(oldWidth, oldHeight);
    }
  }

  double? get _pinnedHeight {
    final c = _container;
    return c != null && !c.stopped ? c.heightAt(now) : null;
  }

  /// `measure(root)` — layout offsets with the current translate subtracted,
  /// which is exactly what the measurer reports. Also refreshes each item's
  /// layout box and, when [natural], the root's natural size.
  Measures _measureInto(List<MorphItem> live, {double? width, bool natural = false, bool apply = true}) {
    final result = measurer.measure(live, width: width);
    final measures = <String, Point>{};
    for (final item in live) {
      if (item.isBreak) continue;
      final p = result.offsets[item.id];
      final s = result.sizes[item.id];
      if (p == null || s == null) continue;
      if (apply) {
        item
          ..x = p.x
          ..y = p.y
          ..width = s.width
          ..height = s.height;
      }
      // `getBoundingClientRect` is the visual box: a running scale about the
      // current transform-origin shifts it, and only the translate is subtracted.
      final t = item.box.transformAt(now);
      final o = item.transformOrigin ?? (x: s.width / 2, y: s.height / 2);
      measures[item.id] = (x: p.x + o.x * (1 - t.sx), y: p.y + o.y * (1 - t.sy));
    }
    if (natural) {
      _naturalWidth = result.naturalWidth;
      _naturalHeight = result.naturalHeight;
    }
    return measures;
  }

  /// Restates the current scene's geometry after a measurement input changed
  /// (style, text scaler, direction, locale, alignment) without touching the
  /// morph history: re-runs the item measurement at the current pinned width
  /// and refreshes the natural size.
  void remeasure() {
    _measureInto(liveItems, width: _pinnedWidth, natural: true);
  }

  void _splitWordSpans(Map<String, List<Segment>> splits) {
    if (splits.isEmpty) return;
    final split = <String>{};
    for (var i = 0; i < items.length; i++) {
      final child = items[i];
      if (child.exiting) continue;
      if (split.contains(child.id)) continue;
      final charSegs = splits[child.id];
      if (charSegs == null) continue;
      split.add(child.id);

      final spans = [for (final seg in charSegs) MorphItem(seg.id, seg.string, kind: seg.kind)];
      items.replaceRange(i, i + 1, spans);
      i += spans.length - 1;
    }
  }

  /// `detachFromFlow`: pins departing boxes where they are on screen.
  void _detachFromFlow(List<MorphItem> elements) {
    final snapshots = <MorphItem, ({double left, double top, double width, double height, double opacity, double blur})>{};
    for (final child in elements) {
      if (child.isBreak) continue;
      // offsetLeft/offsetTop are integers; the translate keeps the subpixel part.
      final transform = child.box.transformAt(now);
      final tx = transform.tx;
      final ty = transform.ty;
      final opacity = _opacityOrOne(child.box.opacityAt(now));
      final blur = child.box.blurAt(now);
      child.box.cancelAll();
      snapshots[child] = (
        left: jsRound(child.x) + tx,
        top: jsRound(child.y) + ty,
        width: child.width,
        height: child.height,
        opacity: opacity,
        blur: blur,
      );
    }

    // BRs can't be animated, so they leave the flow before reconciliation.
    for (var i = elements.length - 1; i >= 0; i--) {
      if (elements[i].isBreak) {
        items.remove(elements[i]);
        elements.removeAt(i);
      }
    }

    for (final child in elements) {
      final snap = snapshots[child]!;
      child
        ..exiting = true
        ..lifecycle = Lifecycle.exiting
        ..x = snap.left
        ..y = snap.top
        ..width = snap.width
        ..height = snap.height;
      child.box.underlyingOpacity = snap.opacity;
      child.box.underlyingBlur = snap.blur;
    }
  }

  /// `Number(getComputedStyle(el).opacity) || 1` — a fully faded box reads as opaque.
  static double _opacityOrOne(double opacity) => opacity == 0 || opacity.isNaN ? 1 : opacity;

  void _reconcileChildren(List<MorphItem> oldChildren, Set<String> newIds, List<Segment> segments) {
    final reusable = <String, MorphItem>{};
    for (final child in oldChildren) {
      if (newIds.contains(child.id) && !child.exiting) {
        reusable[child.id] = child;
      }
    }

    final exitingChildren = items.where((c) => c.exiting).toList();
    items
      ..clear()
      ..addAll(exitingChildren);

    for (final segment in segments) {
      // Claimed once only: a shared ID would leave the earlier position empty.
      final existing = reusable.remove(segment.id);

      if (segment.string == '\n') {
        if (existing != null && existing.isBreak) {
          items.add(existing);
        } else {
          items.add(MorphItem(segment.id, '\n'));
        }
        continue;
      }

      if (existing != null && !existing.isBreak) {
        // A group replacement leaves a shared origin behind; the next morph would use it.
        existing.transformOrigin = null;
        existing.string = segment.string;
        existing.syncSlot(segment.kind);
        items.add(existing);
      } else {
        items.add(MorphItem(segment.id, segment.string, kind: segment.kind));
      }
    }
  }

  void _updateStyles(List<Segment> segments, Measures firstFrameMeasures, double slideDistance) {
    if (isInitialRender) return;

    final children = List<MorphItem>.of(items);
    final segmentIds = segments.map((b) => b.id).toList();
    final kinds = {for (final b in segments) b.id: b.kind};

    // The arriving half of the same gesture.
    final settled = children
        .where((child) => !child.exiting && !child.isBreak && child.id != emptyId)
        .toList();
    final arriving = settled.where((child) => !_prevMeasures.containsKey(child.id)).toSet();
    final arrivingTogether = <MorphItem>{};
    for (final run in replacedRuns(settled, arriving)) {
      arrivingTogether.addAll(run);
      _animateGroupEnter(run);
    }

    final persistentIds = segmentIds.where((id) => _prevMeasures.containsKey(id)).toSet();

    for (final child in children) {
      if (child.exiting) continue;
      if (child.isBreak) continue;
      if (arrivingTogether.contains(child)) continue;
      final key = child.id;
      if (key == emptyId) continue;
      final isNew = !_prevMeasures.containsKey(key);

      final deltaKey = isNew
          ? findNearestAnchor(segmentIds.indexOf(key), segmentIds, persistentIds)
          : key;

      final delta = deltaKey != null
          ? computeDelta(_prevMeasures, firstFrameMeasures, deltaKey)
          : (dx: 0.0, dy: 0.0);

      final kind = kinds[key];

      if (kind != null && isNew) {
        _animateNumberEnter(child, delta.dx, delta.dy, slideDistance, kind);
      } else if (kind != null) {
        _animateNumberPersist(child, delta.dx, delta.dy);
      } else {
        _animateEnterOrPersist(child, delta.dx, delta.dy, isNew);
      }
    }
  }

  // ─── text animations (text-morph/utils/animate.ts) ───

  void _animateExit(MorphItem child, double dx, double dy) {
    final duration = config.duration;
    child.lifecycle = Lifecycle.exiting;
    child.box.animateTransform(
      from: null,
      to: config.scale
          ? Transform2(tx: dx, ty: dy, sx: _itemScale, sy: _itemScale)
          : Transform2(tx: dx, ty: dy),
      duration: duration,
      easing: config.easeFn,
    );
    child.removeWhen = child.box.animateOpacity(
      from: null,
      to: 0,
      duration: fadeDuration(duration, _textExitFade),
    );
    _blurOut(child.box, fadeDuration(duration, _textExitFade));
  }

  void _blurOut(AnimatedBox box, double duration) {
    if (config.blur == 0) return;
    box.animateBlur(from: null, to: config.blur, duration: duration);
  }

  void _blurIn(AnimatedBox box, double prevBlur, double duration, {double delay = 0}) {
    if (config.blur == 0) return;
    box.animateBlur(
      from: prevBlur > 0 ? prevBlur : config.blur,
      to: 0,
      duration: duration,
      delay: delay,
    );
  }

  void _animateEnterOrPersist(MorphItem child, double deltaX, double deltaY, bool isNew) {
    final duration = config.duration;
    final prev = _cancelAnimations(child.box);

    final startX = deltaX + prev.tx;
    final startY = deltaY + prev.ty;
    final startOpacity = isNew && prev.opacity >= 1 ? 0.0 : prev.opacity;

    child.lifecycle = isNew ? Lifecycle.entering : Lifecycle.persisting;
    child.box.animateTransform(
      from: Transform2(tx: startX, ty: startY, sx: isNew ? _itemScale : 1, sy: isNew ? _itemScale : 1),
      to: Transform2.none,
      duration: duration,
      easing: config.easeFn,
    );

    if (startOpacity < 1) {
      child.box.animateOpacity(
        from: startOpacity,
        to: 1,
        duration: fadeDuration(duration, isNew ? _textEnterFade : _textPersistFade),
        delay: isNew ? fadeDuration(duration, _textEnterDelay) : 0,
      );
    }
    if (isNew || prev.blur > 0) {
      _blurIn(
        child.box,
        prev.blur,
        fadeDuration(duration, isNew ? _textEnterFade : _textPersistFade),
        delay: isNew ? fadeDuration(duration, _textEnterDelay) : 0,
      );
    }
  }

  /// `cancelAnimations(element)`: read the running translate and opacity, then cancel.
  ({double tx, double ty, double opacity, double blur}) _cancelAnimations(AnimatedBox box) {
    final t = box.transformAt(now);
    final opacity = _opacityOrOne(box.opacityAt(now));
    final blur = box.blurAt(now);
    box.cancelAll();
    return (tx: t.tx, ty: t.ty, opacity: opacity, blur: blur);
  }

  // ─── number animations (text-morph/utils/number-animate.ts) ───

  /// The slot takes the FLIP correction, the character inside it takes the
  /// slide and fade.
  void _animateNumberExit(MorphItem slot, double dx, double dy, double slideDistance) {
    final duration = config.duration;
    final mover = slot.moverBox;

    slot.box.animateTransform(
      from: null,
      to: Transform2(tx: dx, ty: dy),
      duration: duration,
      easing: config.easeFn,
    );

    mover.animateTransform(
      from: null,
      to: Transform2(tx: 0, ty: slideDistance),
      duration: duration,
      easing: config.easeFn,
    );

    // The slot goes, not just its contents.
    slot.removeWhen = mover.animateOpacity(
      from: null,
      to: 0,
      duration: duration * _numberExitFade,
    );
    _blurOut(mover, duration * _numberExitFade);
  }

  void _animateNumberEnter(MorphItem slot, double deltaX, double deltaY, double slideDistance, SegmentKind kind) {
    final duration = config.duration;
    _animateNumberPersist(slot, deltaX, deltaY);
    slot.lifecycle = Lifecycle.entering;

    final mover = slot.moverBox;
    final prev = _cancelAnimations(mover);

    // Digits arrive from above, separators from below, so each reads as its own event.
    final from = kind == SegmentKind.digit ? -slideDistance : slideDistance;

    mover.animateTransform(
      from: Transform2(tx: 0, ty: prev.ty + from),
      to: null,
      duration: duration,
      easing: config.easeFn,
    );

    final startOpacity = prev.opacity >= 1 ? 0.0 : prev.opacity;
    if (startOpacity < 1) {
      mover.animateOpacity(
        from: startOpacity,
        to: 1,
        duration: duration * _numberEnterFade,
      );
    }
    _blurIn(mover, prev.blur, duration * _numberEnterFade);
  }

  void _animateNumberPersist(MorphItem slot, double deltaX, double deltaY) {
    final duration = config.duration;
    final t = slot.box.transformAt(now);
    slot.box.cancelAll();
    slot.lifecycle = Lifecycle.persisting;

    final startX = deltaX + t.tx;
    final startY = deltaY + t.ty;

    if (startX == 0 && startY == 0) return;

    slot.box.animateTransform(
      from: Transform2(tx: startX, ty: startY),
      to: null,
      duration: duration,
      easing: config.easeFn,
    );
  }

  // ─── group animations (text-morph/utils/replace-animate.ts) ───

  /// A run's centre, restated per member — `transform-origin` is relative to
  /// each box. Rects are the visual boxes at this instant.
  List<Point> _originsFor(List<MorphItem> elements) {
    var left = double.infinity;
    var right = double.negativeInfinity;
    var top = double.infinity;
    var bottom = double.negativeInfinity;
    final rects = <({double left, double top})>[];
    for (final e in elements) {
      final t = e.box.transformAt(now);
      final o = e.origin;
      final ox = e.x + o.x;
      final oy = e.y + o.y;
      final l = ox + (e.x - ox) * t.sx + t.tx;
      final tp = oy + (e.y - oy) * t.sy + t.ty;
      final r = ox + (e.x + e.width - ox) * t.sx + t.tx;
      final b = oy + (e.y + e.height - oy) * t.sy + t.ty;
      rects.add((left: l, top: tp));
      if (l < left) left = l;
      if (r > right) right = r;
      if (tp < top) top = tp;
      if (b > bottom) bottom = b;
    }
    final centreX = (left + right) / 2;
    final centreY = (top + bottom) / 2;
    return [for (final r in rects) (x: centreX - r.left, y: centreY - r.top)];
  }

  /// Collapses a wholly-replaced run towards its own centre and fades it out.
  void _animateGroupExit(List<MorphItem> elements) {
    final duration = config.duration;
    final origins = _originsFor(elements);

    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      element.box.cancelAll();
      element.transformOrigin = origins[i];
      element.lifecycle = Lifecycle.groupExiting;

      element.box.animateTransform(
        from: null,
        to: const Transform2(sx: groupScale, sy: groupScale),
        duration: duration,
        easing: config.easeFn,
      );

      element.removeWhen = element.box.animateOpacity(
        from: null,
        to: 0,
        duration: duration * _groupExitFade,
      );
      _blurOut(element.box, duration * _groupExitFade);
    }
  }

  /// The same gesture in reverse, for the run arriving in its place.
  void _animateGroupEnter(List<MorphItem> elements) {
    final duration = config.duration;
    final origins = _originsFor(elements);

    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      final prev = _cancelAnimations(element.box);
      element.transformOrigin = origins[i];
      element.lifecycle = Lifecycle.groupEntering;

      element.box.animateTransform(
        from: const Transform2(sx: groupScale, sy: groupScale),
        to: null,
        duration: duration,
        easing: config.easeFn,
      );

      final startOpacity = prev.opacity >= 1 ? 0.0 : prev.opacity;
      element.box.animateOpacity(
        from: startOpacity,
        to: 1,
        duration: duration * _groupEnterFade,
      );
      _blurIn(element.box, prev.blur, duration * _groupEnterFade);
    }
  }

  // ─── container (utils/animate.ts) ───

  /// A running transition's `fill: "both"` outranks inline styles, so stop it first.
  void _abortContainerTransition() {
    final entry = _container;
    if (entry == null) return;
    _container = null;
    entry.stop();
    entry.onCancel?.call();
  }

  /// Fires neither callback — teardown is not an animation event.
  void clearContainerTransition() {
    final entry = _container;
    if (entry != null) {
      _container = null;
      entry.stop();
    }
  }

  void _transitionContainerSize(double oldWidth, double oldHeight) {
    // Read before the abort, off the curves the box is still riding.
    final previous = _container;
    final previousSnapshot =
        previous != null && !previous.stopped ? previous.snapshot(now) : null;
    _abortContainerTransition();

    if (oldWidth == 0 || oldHeight == 0) {
      config.onAnimationCancel?.call();
      return;
    }

    final newWidth = _naturalWidth;
    final newHeight = _naturalHeight;

    _container = ContainerTransition.transition(
      oldWidth: oldWidth,
      oldHeight: oldHeight,
      newWidth: newWidth,
      newHeight: newHeight,
      previous: previousSnapshot,
      duration: config.duration,
      ease: config.ease,
      now: now,
      onComplete: config.onAnimationComplete,
      onCancel: config.onAnimationCancel,
    );
  }

  /// An emptied value has nothing left to size to, so the container would
  /// collapse and drag the exiting text with it when centred.
  void _holdContainerSize(double width, double height) {
    _abortContainerTransition();
    _container = ContainerTransition.hold(
      width: width,
      height: height,
      duration: config.duration,
      now: now,
      onComplete: config.onAnimationComplete,
      onCancel: config.onAnimationCancel,
    );
  }

  // ─── timeline ───

  /// Advances the timeline to [t]: resolves play-pending tracks, finishes the
  /// container, removes faded-out departures, and reports the scene.
  FrameState frame(double t) {
    now = t;

    for (final item in items) {
      item.box.start(t);
      item.mover?.start(t);
    }

    final c = _container;
    final released = c != null && !c.stopped && c.finished(t);
    if (released) {
      _container = null;
      c.stop();
    }

    // Lines are aligned within whatever width the root has this frame, so a
    // centred or right-aligned line moves with the animated container while
    // its items' transforms stay untouched.
    final pinned = _pinnedWidth;
    if (pinned != null || released) _measureInto(liveItems, width: pinned);

    // `restoreSize` runs before `onComplete` upstream: the callback sees the reflow.
    if (released) c.onComplete?.call();

    items.removeWhere((item) {
      final fade = item.removeWhen;
      return item.exiting && fade != null && !fade.cancelled && fade.finished(t);
    });

    return snapshot();
  }

  bool get isAnimating {
    final c = _container;
    if (c != null && !c.stopped) return true;
    for (final item in items) {
      if (!item.box.settled(now) || !(item.mover?.settled(now) ?? true)) return true;
      if (item.exiting) return true;
    }
    return false;
  }

  FrameState snapshot() {
    final size = layoutSize();
    final frames = <ItemFrame>[];
    for (final item in items) {
      final o = item.origin;
      final mover = item.mover;
      frames.add(ItemFrame(
        id: item.id,
        text: item.string,
        kind: item.kind,
        exiting: item.exiting,
        isBreak: item.isBreak,
        lifecycle: item.lifecycle,
        x: item.x,
        y: item.y,
        width: item.width,
        height: item.height,
        transform: item.box.transformAt(now),
        originX: o.x,
        originY: o.y,
        opacity: item.box.opacityAt(now),
        blur: item.box.blurAt(now),
        moverTransform: mover?.transformAt(now),
        moverOpacity: mover?.opacityAt(now),
        moverBlur: mover?.blurAt(now),
      ));
    }
    return FrameState(
      now: now,
      width: size.width,
      height: size.height,
      naturalWidth: _naturalWidth,
      naturalHeight: _naturalHeight,
      items: frames,
      animating: isAnimating,
      value: accessibleValue,
      plainText: plainText,
    );
  }

  /// `destroy()`: no callbacks, everything cancelled.
  void dispose() {
    clearContainerTransition();
    for (final item in items) {
      item.box.cancelAll();
      item.mover?.cancelAll();
    }
  }
}
