import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '../core/joining.dart';
import '../core/segment.dart';
import '../motion/morph_engine.dart';

/// The horizontal placement of a line inside the container, after
/// `TextAlign.start/end/justify` have been resolved against the direction.
enum LineAlign { left, center, right }

/// Resolves a [TextAlign] the way the browser resolves `text-align` for the
/// root's direction: `start`→left in LTR / right in RTL, `end` the opposite,
/// `justify`→left (a `nowrap` root has nothing to justify).
LineAlign resolveLineAlign(TextAlign align, TextDirection direction) {
  switch (align) {
    case TextAlign.left:
      return LineAlign.left;
    case TextAlign.right:
      return LineAlign.right;
    case TextAlign.center:
      return LineAlign.center;
    case TextAlign.justify:
      return LineAlign.left;
    case TextAlign.start:
      return direction == TextDirection.rtl ? LineAlign.right : LineAlign.left;
    case TextAlign.end:
      return direction == TextDirection.rtl ? LineAlign.left : LineAlign.right;
  }
}

/// Cache key of one item painter. The style, scaler, direction and locale are
/// fixed per [TextMeasurer], but they are part of the key so a painter can
/// never outlive the inputs it was laid out under.
typedef _PainterKey = ({
  String string,
  TextStyle style,
  TextScaler textScaler,
  TextDirection textDirection,
  Locale? locale,
});

/// Where one item's shaped run sits inside a whole-line [TextPainter], for
/// scripts that join across item boundaries (`RenderTextMorph._paintItem`).
typedef ItemSlice = ({TextPainter painter, double left, double baseline});

/// A line's layout relative to its own left edge (`left: 0`) — independent of
/// the container width, so it is safe to cache across frames where only the
/// container is resizing (a transition's per-frame `measure()` calls).
class _LineGeometry {
  const _LineGeometry({
    required this.itemX,
    required this.itemY,
    required this.itemWidth,
    required this.itemHeight,
    required this.lineWidth,
    required this.lineHeight,
  });

  /// Per item (same order as the line's items), x relative to `left: 0`.
  final List<double> itemX;
  final List<double> itemY;
  final List<double> itemWidth;
  final List<double> itemHeight;
  final double lineWidth;
  final double lineHeight;
}

/// The geometry authority: one cached [TextPainter] per logical item
/// (Strategy A, spec/RENDERER_CONTRACT.md), positioned into baseline-aligned
/// lines.
///
/// Pure: no render tree is needed, so `State` can measure during
/// `didUpdateWidget`. The same inputs always give the same result.
class TextMeasurer implements Measurer {
  TextMeasurer({
    required this.style,
    required this.textScaler,
    required this.textDirection,
    required this.textAlign,
    this.locale,
    this.textHeightBehavior,
    this.strutStyle,
    this.bidi = true,
  }) : align = resolveLineAlign(textAlign, textDirection);

  /// Already merged with the enclosing `DefaultTextStyle`.
  final TextStyle style;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final Locale? locale;

  /// The unresolved alignment, kept so a widget can tell whether it changed.
  final TextAlign textAlign;

  /// [textAlign] resolved against [textDirection].
  final LineAlign align;

  final TextHeightBehavior? textHeightBehavior;
  final StrutStyle? strutStyle;

  /// Place each item where the Unicode Bidirectional Algorithm puts its text
  /// inside the line. False restores upstream's atomic-inline rule, where
  /// items keep logical order (spec/RTL_KNOWN_LIMITATIONS.md, RTL-002).
  final bool bidi;

  final Map<_PainterKey, TextPainter> _painters = {};

  bool _disposed = false;

  /// How many painters are alive (tests assert the cache is actually reused).
  int get cachedPainterCount => _painters.length;

  /// Per-line layout relative to the line's own left edge, keyed by its item
  /// strings: only the alignment offset depends on the container width.
  final Map<String, _LineGeometry> _lineCache = {};

  /// Shaped-run slices for joining scripts, keyed the same way.
  final Map<String, List<ItemSlice?>> _sliceCache = {};

  static const int _maxCacheEntries = 300;

  void _boundCache(Map<String, Object?> cache) {
    if (cache.length > _maxCacheEntries) cache.clear();
  }

  /// Every distinct value adds a line and a plain painter, so a long-lived
  /// widget would grow without bound. Called from [measure], never mid-paint.
  void _boundPainters() {
    if (_painters.length <= _maxCacheEntries) return;
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
    _lineCache.clear();
    _sliceCache.clear();
  }

  // NUL never appears in segment text, so the join is unambiguous.
  static String _lineKey(Iterable<String> strings) => strings.join('\u0000');

  _PainterKey _keyFor(String string) => (
    string: string,
    style: style,
    textScaler: textScaler,
    textDirection: textDirection,
    locale: locale,
  );

  /// The laid-out painter for one item string. Shared with the render object,
  /// which paints it — measuring and painting must agree exactly.
  TextPainter painterFor(String string) {
    assert(!_disposed, 'TextMeasurer used after dispose()');
    final key = _keyFor(string);
    final cached = _painters[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(text: string, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: 1,
      textHeightBehavior: textHeightBehavior,
      strutStyle: strutStyle,
    )..layout();
    _painters[key] = painter;
    return painter;
  }

  /// A painter over the whole value, used by the disabled plain-text path.
  /// `softWrap` is off, so the only line breaks are the value's own.
  TextPainter plainTextPainter(String value) {
    assert(!_disposed, 'TextMeasurer used after dispose()');
    final key = _keyFor('\u0000plain\u0000$value');
    final cached = _painters[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      textAlign: textAlign,
      textHeightBehavior: textHeightBehavior,
      strutStyle: strutStyle,
    )..layout();
    _painters[key] = painter;
    return painter;
  }

  /// One painter over a whole line's logical text, so the platform's own bidi
  /// resolution can be queried per item range.
  TextPainter linePainterFor(String line) {
    assert(!_disposed, 'TextMeasurer used after dispose()');
    final key = _keyFor('\u0000line$line');
    final cached = _painters[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(text: line, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: 1,
      textHeightBehavior: textHeightBehavior,
      strutStyle: strutStyle,
    )..layout();
    _painters[key] = painter;
    return painter;
  }

  static final RegExp _strongRtl = RegExp(
    '[\u0590-\u05ff\u0600-\u07bf\u0860-\u08ff\ufb1d-\ufdff\ufe70-\ufeff'
    '\u200f\u202b\u202e\u2067]',
  );

  static bool needsShaping(String text) => hasJoiningScript(text);

  /// Running-sum placement already is the algorithm's answer for an LTR
  /// paragraph with nothing strongly right-to-left in it.
  bool needsBidi(String line) =>
      bidi && (textDirection == TextDirection.rtl || _strongRtl.hasMatch(line));

  double _baselineOf(TextPainter painter) {
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    return baseline.isFinite ? baseline : painter.height;
  }

  /// A line's layout relative to its own left edge, computed once per
  /// distinct sequence of item strings and reused every later frame that
  /// line reappears with (a container-width transition remeasures every
  /// frame, but a line's own shaping never depends on the container).
  _LineGeometry _lineGeometryFor(List<MorphItem> line) {
    final strings = [for (final item in line) item.string];
    final key = _lineKey(strings);
    final cached = _lineCache[key];
    if (cached != null) return cached;

    final lineText = strings.join();
    final widths = List<double>.filled(line.length, 0);
    final heights = List<double>.filled(line.length, 0);
    final baselines = List<double>.filled(line.length, 0);
    var lineWidthSum = 0.0;
    var ascent = 0.0;
    var descent = 0.0;
    for (var i = 0; i < line.length; i++) {
      final painter = painterFor(line[i].string);
      final baseline = _baselineOf(painter);
      widths[i] = painter.width;
      heights[i] = painter.height;
      baselines[i] = baseline;
      lineWidthSum += painter.width;
      ascent = math.max(ascent, baseline);
      descent = math.max(descent, painter.height - baseline);
    }
    if (line.isEmpty) {
      // The strut: an empty line box is still one line tall.
      final strut = painterFor(emptyString);
      ascent = _baselineOf(strut);
      descent = strut.height - ascent;
    }

    final useBidi = line.isNotEmpty && needsBidi(lineText);
    final linePainter = useBidi ? linePainterFor(lineText) : null;
    final lineWidth = linePainter?.width ?? lineWidthSum;

    final itemX = List<double>.filled(line.length, 0);
    final itemY = List<double>.filled(line.length, 0);
    var advance = 0.0;
    var offset = 0;
    var lastEdge = 0.0;
    for (var i = 0; i < line.length; i++) {
      final w = widths[i];
      final start = offset;
      offset += line[i].string.length;
      final double x;
      if (linePainter != null) {
        final boxes = linePainter.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: offset),
        );
        var visualLeft = lastEdge;
        for (final box in boxes) {
          if (box.left < visualLeft || box == boxes.first) {
            visualLeft = box.left;
          }
        }
        if (boxes.isNotEmpty) lastEdge = visualLeft + w;
        x = visualLeft;
      } else if (textDirection == TextDirection.rtl) {
        // Items flow from the right in logical order — no bidi reordering of
        // items, which is what the browser does with inline-block spans.
        advance += w;
        x = lineWidth - advance;
      } else {
        x = advance;
        advance += w;
      }
      itemX[i] = x;
      itemY[i] = ascent - baselines[i];
    }

    final geo = _LineGeometry(
      itemX: itemX,
      itemY: itemY,
      itemWidth: widths,
      itemHeight: heights,
      lineWidth: lineWidth,
      lineHeight: ascent + descent,
    );
    _lineCache[key] = geo;
    _boundCache(_lineCache);
    return geo;
  }

  @override
  MeasureResult measure(List<MorphItem> items, {double? width}) {
    _boundPainters();
    if (items.isEmpty) {
      return const MeasureResult(
        offsets: {},
        sizes: {},
        naturalWidth: 0,
        naturalHeight: 0,
      );
    }

    // A trailing break makes an empty last line, exactly as `<br>` does.
    final lines = <List<MorphItem>>[[]];
    for (final item in items) {
      if (item.isBreak) {
        lines.add(<MorphItem>[]);
      } else {
        lines.last.add(item);
      }
    }

    final geometries = [for (final line in lines) _lineGeometryFor(line)];

    final offsets = <String, Point>{};
    final sizes = <String, Extent>{};

    final naturalWidth = geometries.fold(
      0.0,
      (w, g) => math.max(w, g.lineWidth),
    );
    final naturalHeight = geometries.fold(0.0, (h, g) => h + g.lineHeight);
    final containerWidth = width ?? naturalWidth;

    // Only the alignment offset depends on the container width.
    var lineTop = 0.0;
    for (var li = 0; li < lines.length; li++) {
      final geo = geometries[li];
      final free = containerWidth - geo.lineWidth;
      // text-align does nothing to overflowing content: it stays start-aligned.
      final double left;
      if (free <= 0) {
        left = textDirection == TextDirection.rtl
            ? containerWidth - geo.lineWidth
            : 0.0;
      } else {
        left = switch (align) {
          LineAlign.left => 0.0,
          LineAlign.center => free / 2,
          LineAlign.right => free,
        };
      }

      for (var i = 0; i < lines[li].length; i++) {
        final item = lines[li][i];
        offsets[item.id] = (x: left + geo.itemX[i], y: lineTop + geo.itemY[i]);
        sizes[item.id] = (width: geo.itemWidth[i], height: geo.itemHeight[i]);
      }
      lineTop += geo.lineHeight;
    }

    return MeasureResult(
      offsets: offsets,
      sizes: sizes,
      naturalWidth: naturalWidth,
      naturalHeight: naturalHeight,
    );
  }

  /// Per-item geometry for one line painted as a joining-script run
  /// (Arabic/Syriac/etc): the slice of the whole-line [TextPainter] each item
  /// paints out of. `null` for an item that doesn't need shaping, or when the
  /// line as a whole doesn't. Cached the same way as [_lineGeometryFor], so
  /// `RenderTextMorph._shapedSlices()` doesn't redo `getBoxesForSelection`
  /// every paint.
  List<ItemSlice?> shapedSlicesFor(List<String> lineItemStrings) {
    final text = lineItemStrings.join();
    if (!needsShaping(text)) {
      return List<ItemSlice?>.filled(lineItemStrings.length, null);
    }
    final key = _lineKey(lineItemStrings);
    final cached = _sliceCache[key];
    if (cached != null) return cached;

    final painter = linePainterFor(text);
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final result = List<ItemSlice?>.filled(lineItemStrings.length, null);
    if (baseline.isFinite) {
      var offset = 0;
      for (var i = 0; i < lineItemStrings.length; i++) {
        final s = lineItemStrings[i];
        final start = offset;
        offset += s.length;
        if (!needsShaping(s)) continue;
        final boxes = painter.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: offset),
        );
        if (boxes.isEmpty) continue;
        var left = boxes.first.left;
        for (final box in boxes) {
          if (box.left < left) left = box.left;
        }
        result[i] = (painter: painter, left: left, baseline: baseline);
      }
    }
    _sliceCache[key] = result;
    _boundCache(_sliceCache);
    return result;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
    _lineCache.clear();
    _sliceCache.clear();
  }
}
