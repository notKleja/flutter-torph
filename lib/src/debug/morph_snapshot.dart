import 'dart:ui' show Size;

import '../motion/morph_engine.dart';

/// A read-only view of one painted frame, for tests and debugging.
///
/// Wraps the engine's [FrameState] and adds what only the renderer knows how
/// to summarise: the line count, the natural size as a [Size] and whether the
/// scene is still moving.
class TextMorphSnapshot {
  const TextMorphSnapshot(this.frame);

  final FrameState frame;

  /// The engine time this frame was produced at, in milliseconds.
  double get now => frame.now;

  /// The root's layout size this frame (animated while a transition runs).
  Size get size => Size(frame.width, frame.height);

  /// The size the current content would take with no transition running.
  Size get naturalSize => Size(frame.naturalWidth, frame.naturalHeight);

  bool get animating => frame.animating;

  /// The accessible value (the semantics label).
  String get value => frame.value;

  /// Non-null while disabled: the value is drawn as plain text.
  String? get plainText => frame.plainText;

  /// Items in paint order: exiting first, then live in value order.
  List<ItemFrame> get items => frame.items;

  /// Live (non-exiting) items, breaks included.
  List<ItemFrame> get liveItems => frame.items.where((i) => !i.exiting).toList();

  /// Exiting items, pinned where they were when they left the flow.
  List<ItemFrame> get exitingItems => frame.items.where((i) => i.exiting).toList();

  /// Lines the live items occupy: one, plus one per break. Zero when the root
  /// has no items at all (an initial render of `""`).
  int get lineCount {
    if (frame.items.isEmpty) return 0;
    var breaks = 0;
    for (final item in frame.items) {
      if (!item.exiting && item.isBreak) breaks++;
    }
    return breaks + 1;
  }

  /// The first item whose text is [text], for terse test assertions.
  ItemFrame item(String text, {bool exiting = false}) =>
      frame.items.firstWhere((i) => i.text == text && i.exiting == exiting);

  ItemFrame? itemById(String id) {
    for (final item in frame.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  String toString() => 'TextMorphSnapshot(now: ${frame.now}, size: $size, '
      'natural: $naturalSize, items: ${frame.items.length}, '
      'animating: $animating, value: "${frame.value}"'
      '${frame.plainText != null ? ', plainText' : ''})';
}
