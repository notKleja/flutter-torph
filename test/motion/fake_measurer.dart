import 'dart:math' as math;

import 'package:torph/src/core/segment.dart';
import 'package:torph/src/motion/morph_engine.dart';

/// Deterministic stand-in for the DOM/TextPainter: every UTF-16 code unit is
/// [advance] wide (a zero-width space is 0), every line is [lineHeight] tall,
/// items flow left-to-right as inline-blocks, `\n` starts a new line, and
/// `text-align` shifts each line within the container width — but never an
/// overflowing line (upstream: "text-align does nothing to overflowing content").
class FakeMeasurer implements Measurer {
  FakeMeasurer({this.advance = 10, this.lineHeight = 20, this.align = 'left'});

  final double advance;
  final double lineHeight;

  /// 'left' | 'center' | 'right'.
  String align;

  int calls = 0;

  double widthOf(String s) => s == emptyString ? 0 : s.length * advance;

  @override
  MeasureResult measure(List<MorphItem> items, {double? width}) {
    calls++;
    final lines = <List<MorphItem>>[[]];
    for (final item in items) {
      if (item.isBreak) {
        lines.add([]);
      } else {
        lines.last.add(item);
      }
    }
    final lineWidths = [
      for (final line in lines) line.fold(0.0, (w, i) => w + widthOf(i.string)),
    ];
    final naturalWidth = lineWidths.fold(0.0, math.max);
    // An empty root has no line box; any content, even a break, makes one per line.
    final naturalHeight = items.isEmpty ? 0.0 : lines.length * lineHeight;
    final containerWidth = width ?? naturalWidth;

    final offsets = <String, Point>{};
    final sizes = <String, Extent>{};
    for (var li = 0; li < lines.length; li++) {
      final free = containerWidth - lineWidths[li];
      final shift = free <= 0
          ? 0.0
          : align == 'center'
          ? free / 2
          : align == 'right'
          ? free
          : 0.0;
      var x = shift;
      for (final item in lines[li]) {
        final w = widthOf(item.string);
        offsets[item.id] = (x: x, y: li * lineHeight);
        sizes[item.id] = (width: w, height: lineHeight);
        x += w;
      }
    }
    return MeasureResult(
      offsets: offsets,
      sizes: sizes,
      naturalWidth: naturalWidth,
      naturalHeight: naturalHeight,
    );
  }
}
