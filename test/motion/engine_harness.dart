import 'package:torph/src/core/replacement.dart';
import 'package:torph/src/core/segment.dart';
import 'package:torph/src/motion/morph_engine.dart';
import 'package:torph/src/motion/track.dart';

import 'fake_measurer.dart';

/// Shared scaffolding for the ports of `text-morph/__tests__/engine.test.ts`
/// and `options.test.ts`.
FakeMeasurer happyDom({double lineHeight = 20}) =>
    FakeMeasurer(advance: 0, lineHeight: lineHeight);

/// `offsetHeight || 20` — happy-dom has no layout.
const double slide = 20;

/// One mounted engine plus the virtual clock its tracks are read against.
///
class Morph {
  Morph._(this.measurer, this.engine);

  factory Morph({FakeMeasurer? measurer, MorphConfig? config}) {
    final m = measurer ?? happyDom();
    return Morph._(
      m,
      MorphEngine(measurer: m, config: config ?? MorphConfig()),
    );
  }

  final FakeMeasurer measurer;
  final MorphEngine engine;

  double clock = 0;
  FrameState? _frame;

  FrameState get frame => _frame ?? engine.snapshot();

  void update(Object value, {int? cursorIndex}) {
    engine.update(value, cursorIndex: cursorIndex, disabled: false);
    _frame = engine.frame(clock);
  }

  void updateDisabled(Object value) {
    engine.update(value, disabled: true);
    _frame = engine.frame(clock);
  }

  /// Reconciles without letting a frame start the tracks, so the pending-start
  /// semantic is observable.
  void updateOnly(Object value) =>
      engine.update(value, disabled: false, cursorIndex: null);

  void at(double ms) {
    clock = ms;
    _frame = engine.frame(clock);
  }

  void advance(double ms) => at(clock + ms);

  void dispose() => engine.dispose();

  List<MorphItem> get children => List.of(engine.items);
  List<MorphItem> get live => children.where((c) => !c.exiting).toList();
  List<MorphItem> get leaving => children.where((c) => c.exiting).toList();

  /// What the root reads as, ignoring the characters on their way out.
  /// `<br>` carries the line break and holds no text of its own.
  String get rendered =>
      live.map((c) => c.isBreak ? '' : c.string.replaceAll(nbsp, ' ')).join();

  List<String> get shape =>
      live.map((c) => '${c.string}:${c.kind?.name ?? 'text'}').toList();

  MorphItem byText(String text) => live.firstWhere((c) => c.string == text);

  String idOf(String text) => byText(text).id;

  MorphItem byId(String id) => children.firstWhere((c) => c.id == id);

  List<String> get liveIds => live.map((c) => c.id).toList();

  String? get duplicateId {
    final seen = <String>{};
    for (final id in liveIds) {
      if (!seen.add(id)) return id;
    }
    return null;
  }
}

/// A transform track flattened to `[fromTx, fromTy, fromScale, toTx, toTy,
/// toScale]` — the two ends WAAPI was handed. Scale is uniform everywhere
List<double?> shapeOf(Track<Transform2> t) => [
  t.from?.tx,
  t.from?.ty,
  t.from?.sx,
  t.to?.tx,
  t.to?.ty,
  t.to?.sx,
];

/// What layout did to a character — the transform on the item itself.
/// Null where upstream recorded no `animate()` call for it.
List<double?>? motion(MorphItem item) {
  final tracks = item.box.transformTracks;
  return tracks.isEmpty ? null : shapeOf(tracks.last);
}

/// What the character did inside its slot — the block-axis slide.
List<double?>? slideOf(MorphItem item) {
  final mover = item.mover;
  if (mover == null || mover.transformTracks.isEmpty) return null;
  return shapeOf(mover.transformTracks.last);
}

/// `translate(0px, ${dy}px) @0` — one keyframe at the start, the other end
/// neutral.
List<double?> slideFrom(double dy) => [0, dy, 1, null, null, null];
const List<double?> slideOut = [null, null, null, 0, slide, 1];
// Enter and persist are the one pair upstream states with two keyframes, the
// second literally `transform: "none"` — not a neutral end.
const List<double?> textEnter = [0, 0, 0.95, 0, 0, 1];
const List<double?> textPersist = [0, 0, 1, 0, 0, 1];
const List<double?> textExit = [null, null, null, 0, 0, 0.95];
const List<double?> groupEnter = [0, 0, groupScale, null, null, null];
const List<double?> groupExit = [null, null, null, 0, 0, groupScale];

/// A group gesture states `scale(0.8)` at one end and nothing else.
bool isGrouped(MorphItem item) => item.box.transformTracks.any(
  (t) => t.from?.sx == groupScale || t.to?.sx == groupScale,
);

/// Every fade the morph started, on slots and movers both.
List<Track<double>> fadesOf(Morph morph) {
  final fades = <Track<double>>[];
  for (final item in morph.children) {
    fades.addAll(item.box.opacityTracks);
    final mover = item.mover;
    if (mover != null) fades.addAll(mover.opacityTracks);
  }
  return fades;
}

/// Every transform track the morph started.
List<Track<Transform2>> transformsOf(Morph morph) {
  final tracks = <Track<Transform2>>[];
  for (final item in morph.children) {
    tracks.addAll(item.box.transformTracks);
    final mover = item.mover;
    if (mover != null) tracks.addAll(mover.transformTracks);
  }
  return tracks;
}
