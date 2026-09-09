import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../debug/morph_snapshot.dart';
import '../motion/morph_engine.dart';
import 'text_measurer.dart';

typedef _Slice = ({TextPainter painter, double left, double baseline});

/// Half the width of the open inline axis of a numeric slot's clip
/// (`clip-path: inset(0 -100vw)`): effectively unbounded.
const double _kSlotInlineOverflow = 1000000;

/// The fade band of the slot mask, as a share of the font size
/// (`--torph-fade: 0.15em`).
const double _kSlotFadeEm = 0.15;

/// Draws one [FrameState]. Owns nothing about time: the widget hands it a frame
/// and it decides whether that means layout or only paint.
class RenderTextMorph extends RenderBox {
  RenderTextMorph({
    required FrameState initialFrame,
    required TextMeasurer initialMeasurer,
    required TextStyle initialStyle,
    required TextDirection initialTextDirection,
    bool initialDebug = false,
  })  : _frame = initialFrame,
        _measurer = initialMeasurer,
        _style = initialStyle,
        _textDirection = initialTextDirection,
        _debug = initialDebug;

  FrameState _frame;
  FrameState get frame => _frame;

  set frame(FrameState value) {
    final old = _frame;
    if (identical(old, value)) return;
    _frame = value;
    if (old.value != value.value) markNeedsSemanticsUpdate();
    if (!hasSize || old.plainText != value.plainText) {
      markNeedsLayout();
      return;
    }
    if (value.plainText == null &&
        (value.width != _laidOutWidth || value.height != _laidOutHeight)) {
      markNeedsLayout();
      return;
    }
    markNeedsPaint();
  }

  double _laidOutWidth = double.nan;
  double _laidOutHeight = double.nan;

  TextMeasurer _measurer;
  TextMeasurer get measurer => _measurer;

  set measurer(TextMeasurer value) {
    if (identical(_measurer, value)) return;
    _measurer = value;
    markNeedsLayout();
  }

  TextStyle _style;
  TextStyle get style => _style;

  set style(TextStyle value) {
    if (_style == value) return;
    _style = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsSemanticsUpdate();
    markNeedsPaint();
  }

  bool _debug;
  bool get debug => _debug;

  set debug(bool value) {
    if (_debug == value) return;
    _debug = value;
    markNeedsPaint();
  }

  /// The scene as it stands, for tests and debugging.
  TextMorphSnapshot debugSnapshot() => TextMorphSnapshot(_frame);

  // ─── layout ───

  Size _sizeFor(BoxConstraints constraints) {
    final plain = _frame.plainText;
    if (plain != null) {
      return constraints.constrain(_measurer.plainTextPainter(plain).size);
    }
    return constraints.constrain(Size(_frame.width, _frame.height));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _frame.naturalWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _frame.naturalWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _frame.naturalHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _frame.naturalHeight;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  void performLayout() {
    _laidOutWidth = _frame.width;
    _laidOutHeight = _frame.height;
    size = _sizeFor(constraints);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final plain = _frame.plainText;
    if (plain != null) {
      return _measurer.plainTextPainter(plain).computeDistanceToActualBaseline(baseline);
    }
    // The alphabetic baseline of the first line, as an inline-block's is.
    for (final item in _frame.items) {
      if (item.exiting || item.isBreak) continue;
      final painter = _measurer.painterFor(item.text);
      return item.y + painter.computeDistanceToActualBaseline(baseline);
    }
    return null;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  // ─── paint ───

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    final plain = _frame.plainText;
    if (plain != null) {
      final painter = _measurer.plainTextPainter(plain);
      painter.paint(canvas, offset);
      if (_debug) _paintDebugRoot(canvas, offset);
      return;
    }

    final slices = _shapedSlices();
    for (final item in _frame.items) {
      if (item.isBreak) continue;
      if (item.opacity == 0) continue;
      _paintItem(canvas, offset, item, slices[item.id]);
    }

    if (_debug) _paintDebugRoot(canvas, offset);
  }

  /// Where each live item's characters sit inside the painter for its whole
  /// line. Only for scripts that join, and only while the line has more than
  /// one item — otherwise the item's own painter already shapes correctly.
  Map<String, _Slice> _shapedSlices() {
    final lines = <List<ItemFrame>>[[]];
    for (final item in _frame.items) {
      if (item.exiting) continue;
      if (item.isBreak) {
        lines.add(<ItemFrame>[]);
      } else {
        lines.last.add(item);
      }
    }

    final slices = <String, _Slice>{};
    for (final line in lines) {
      if (line.length < 2) continue;
      final text = line.map((i) => i.text).join();
      if (!TextMeasurer.needsShaping(text)) continue;
      final painter = _measurer.linePainterFor(text);
      final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      if (!baseline.isFinite) continue;
      var offset = 0;
      for (final item in line) {
        final start = offset;
        offset += item.text.length;
        if (!TextMeasurer.needsShaping(item.text)) continue;
        final boxes = painter.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: offset),
        );
        if (boxes.isEmpty) continue;
        var left = boxes.first.left;
        for (final box in boxes) {
          if (box.left < left) left = box.left;
        }
        slices[item.id] = (painter: painter, left: left, baseline: baseline);
      }
    }
    return slices;
  }

  void _paintItem(Canvas canvas, Offset offset, ItemFrame item, _Slice? slice) {
    final t = item.transform;
    final ox = item.originX;
    final oy = item.originY;

    // CSS `transform-origin: o; transform: translate(t) scale(s)`.
    canvas.save();
    canvas.translate(offset.dx + item.x + ox + t.tx, offset.dy + item.y + oy + t.ty);
    canvas.scale(t.sx, t.sy);
    canvas.translate(-ox, -oy);

    final bounds = Rect.fromLTWH(0, 0, item.width, item.height);
    final opacity = item.opacity;
    final grouped = opacity < 1 || item.blur > 0;
    if (grouped) {
      // Glyphs of one item can overlap; a layer is the CSS group-opacity
      // semantic, not per-glyph alpha.
      canvas.saveLayer(bounds.inflate(item.height), _layerPaint(opacity, item.blur));
    }

    if (item.kind != null) {
      _paintSlot(canvas, item);
    } else if (slice != null) {
      final own = _measurer.painterFor(item.text);
      final ownBaseline = own.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, -item.height, item.width, item.height * 3));
      canvas.translate(-slice.left, (ownBaseline.isFinite ? ownBaseline : own.height) - slice.baseline);
      slice.painter.paint(canvas, Offset.zero);
      canvas.restore();
    } else {
      _measurer.painterFor(item.text).paint(canvas, Offset.zero);
    }

    if (grouped) canvas.restore();

    if (_debug) {
      canvas.drawRect(
        bounds.deflate(4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF00FFFF),
      );
    }

    canvas.restore();
  }

  /// The numeric slot: a block-axis clip with an open inline axis, softened at
  /// both edges by the `--torph-fade` gradient, and the character sliding
  /// inside it.
  void _paintSlot(Canvas canvas, ItemFrame item) {
    final maskRect = Rect.fromLTWH(
      -_kSlotInlineOverflow,
      0,
      2 * _kSlotInlineOverflow,
      item.height,
    );

    canvas.save();
    canvas.clipRect(maskRect);
    canvas.saveLayer(maskRect, Paint());

    final moverTy = item.moverTransform?.ty ?? 0;
    final moverOpacity = item.moverOpacity ?? 1;
    final moverBlur = item.moverBlur ?? 0;
    canvas.save();
    // The slide is block-axis only: tx is always 0 upstream.
    canvas.translate(item.moverTransform?.tx ?? 0, moverTy);
    final bounds = Rect.fromLTWH(0, 0, item.width, item.height);
    final fade = moverOpacity < 1 || moverBlur > 0;
    if (fade) {
      canvas.saveLayer(bounds.inflate(item.height), _layerPaint(moverOpacity, moverBlur));
    }
    _measurer.painterFor(item.text).paint(canvas, Offset.zero);
    if (fade) canvas.restore();
    canvas.restore();

    canvas.drawRect(
      maskRect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _fadeShader(maskRect, item.height),
    );

    canvas.restore(); // saveLayer
    canvas.restore(); // clip
  }

  Shader _fadeShader(Rect rect, double height) {
    final fontSize = _style.fontSize ?? 14.0;
    final band = _kSlotFadeEm * fontSize * _measurer.textScaler.scale(1);
    // A band wider than half the box would cross over itself; the ramps meet.
    final ratio = height <= 0 ? 0.0 : (band / height).clamp(0.0, 0.5);
    const transparent = Color(0x00000000);
    const black = Color(0xFF000000);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [transparent, black, black, transparent],
      stops: [0, ratio, 1 - ratio, 1],
    ).createShader(rect);
  }

  static Paint _layerPaint(double opacity, double blur) {
    final paint = Paint()..color = Color.fromRGBO(0, 0, 0, opacity);
    if (blur > 0) {
      paint.imageFilter = ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal);
    }
    return paint;
  }

  void _paintDebugRoot(Canvas canvas, Offset offset) {
    canvas.drawRect(
      offset & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF00FF),
    );
  }

  // ─── semantics ───

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.label = _frame.value;
    config.textDirection = _textDirection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('value', _frame.value));
    properties.add(DiagnosticsProperty<bool>('animating', _frame.animating));
    properties.add(IntProperty('items', _frame.items.length));
    properties.add(FlagProperty('debugOutlines', value: _debug, ifTrue: 'debug'));
  }
}

/// The leaf that owns [RenderTextMorph]. Configuration only; the frame arrives
/// through it on rebuilds and directly from the ticker in between.
class TextMorphRenderWidget extends LeafRenderObjectWidget {
  const TextMorphRenderWidget({
    super.key,
    required this.frame,
    required this.measurer,
    required this.style,
    required this.textDirection,
    required this.debug,
    this.onRenderObject,
  });

  final FrameState frame;
  final TextMeasurer measurer;
  final TextStyle style;
  final TextDirection textDirection;
  final bool debug;

  /// Lets the owning `State` push per-frame updates straight to the render
  /// object instead of rebuilding for every tick.
  final ValueChanged<RenderTextMorph?>? onRenderObject;

  @override
  RenderTextMorph createRenderObject(BuildContext context) {
    final render = RenderTextMorph(
      initialFrame: frame,
      initialMeasurer: measurer,
      initialStyle: style,
      initialTextDirection: textDirection,
      initialDebug: debug,
    );
    onRenderObject?.call(render);
    return render;
  }

  @override
  void updateRenderObject(BuildContext context, RenderTextMorph renderObject) {
    onRenderObject?.call(renderObject);
    renderObject
      ..measurer = measurer
      ..style = style
      ..textDirection = textDirection
      ..debug = debug
      ..frame = frame;
  }

  @override
  void didUnmountRenderObject(RenderTextMorph renderObject) {
    onRenderObject?.call(null);
  }
}
