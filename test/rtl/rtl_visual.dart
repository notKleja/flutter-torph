import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';

/// One grapheme cluster's visual box, from `TextPainter.getBoxesForSelection`.
class GraphemeBox {
  GraphemeBox(this.grapheme, this.left, this.right, this.direction);

  final String grapheme;
  final double left;
  final double right;
  final TextDirection direction;
}

/// Lays out [text] with a single `TextPainter` and returns each grapheme
List<GraphemeBox> graphemeBoxesOf(
  String text, {
  required TextDirection direction,
  required TextStyle style,
  Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    locale: locale,
    maxLines: 1,
  )..layout();
  final result = <GraphemeBox>[];
  var offset = 0;
  for (final g in text.characters) {
    final start = offset;
    final end = offset + g.length;
    offset = end;
    if (start == end) continue;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    if (boxes.isEmpty) continue;
    var left = boxes.first.left;
    var right = boxes.first.right;
    for (final b in boxes) {
      if (b.left < left) left = b.left;
      if (b.right > right) right = b.right;
    }
    result.add(GraphemeBox(g, left, right, boxes.first.direction));
  }
  painter.dispose();
  return result;
}

String visualOrderString(List<GraphemeBox> boxes) {
  final sorted = [...boxes]..sort((a, b) => a.left.compareTo(b.left));
  return sorted.map((b) => b.grapheme).join();
}

List<String> visualOrderList(List<GraphemeBox> boxes) {
  final sorted = [...boxes]..sort((a, b) => a.left.compareTo(b.left));
  return sorted.map((b) => b.grapheme).toList();
}

List<int> divergingIndices(List<String> a, List<String> b) {
  final out = <int>[];
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) out.add(i);
  }
  if (a.length != b.length) {
    out.addAll([for (var i = n; i < a.length || i < b.length; i++) i]);
  }
  return out.toSet().toList()..sort();
}
