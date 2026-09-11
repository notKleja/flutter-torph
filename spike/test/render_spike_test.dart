// RENDER-SPIKE-001 (M4). Experimental evidence only — nothing here is production.
//
// Compares three ways to paint independently movable text fragments:
//   A. one TextPainter per Torph segment, positioned by accumulating advances
//      on a common alphabetic baseline (mirrors upstream's inline-block-per-
//      segment DOM exactly).
//   B. one TextPainter over the whole joined line; per-fragment geometry from
//      getBoxesForSelection over the fragment's UTF-16 range; each fragment
//      painted by clipping the whole paragraph to those boxes.
//   C. one TextPainter over the whole joined line, painted once (this is what a
//      plain Flutter Text widget does — reference only).
//
// Results are appended to spike/out/results.json and PNGs to spike/out/.
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/segmenter.dart';

const double kFontSize = 32;
const int kFrames = 60;
const int kTimingReps = 30;

final Directory outDir = Directory('${Directory.current.path}/out');

// ---------------------------------------------------------------- font setup

Future<void> _load(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('MISSING FONT $path');
    return;
  }
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(
      Future<ByteData>.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  await loader.load();
}

// ---------------------------------------------------------------- strategies

class Frag {
  Frag(this.text, this.x, this.width, this.baselineShift);
  final String text;
  final double x;
  final double width;
  final double baselineShift;
}

TextPainter _painter(String text, TextStyle style, TextDirection dir) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: dir,
    textScaler: TextScaler.noScaling,
    locale: const Locale('en'),
    maxLines: 1,
  )..layout();
  return tp;
}

/// Strategy A geometry: independent painters, advances accumulated, aligned on
/// a shared alphabetic baseline.
class StratA {
  StratA(this.painters, this.xs, this.baseline, this.advance, this.height);
  final List<TextPainter> painters;
  final List<double> xs;
  final double baseline; // shared baseline y
  final double advance; // sum of fragment widths
  final double height;

  static StratA build(List<String> parts, TextStyle style, TextDirection dir) {
    final painters = <TextPainter>[];
    for (final p in parts) {
      painters.add(_painter(p, style, dir));
    }
    var maxAscent = 0.0;
    var maxDescent = 0.0;
    for (final tp in painters) {
      final b = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      maxAscent = math.max(maxAscent, b);
      maxDescent = math.max(maxDescent, tp.height - b);
    }
    final xs = <double>[];
    var x = 0.0;
    for (final tp in painters) {
      xs.add(x);
      x += tp.width;
    }
    return StratA(painters, xs, maxAscent, x, maxAscent + maxDescent);
  }

  void paint(Canvas canvas, Offset origin, double Function(int) dx) {
    for (var i = 0; i < painters.length; i++) {
      final tp = painters[i];
      final b = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      tp.paint(canvas, origin + Offset(xs[i] + dx(i), baseline - b));
    }
  }
}

/// Strategy B geometry: one paragraph, fragment boxes from selection ranges.
class StratB {
  StratB(this.tp, this.boxes);
  final TextPainter tp;
  final List<List<TextBox>> boxes;

  static StratB build(List<String> parts, TextStyle style, TextDirection dir) {
    final joined = parts.join();
    final tp = _painter(joined, style, dir);
    final boxes = <List<TextBox>>[];
    var off = 0;
    for (final p in parts) {
      final sel = TextSelection(baseOffset: off, extentOffset: off + p.length);
      List<TextBox> b;
      try {
        b = tp.getBoxesForSelection(
          sel,
          boxHeightStyle: ui.BoxHeightStyle.max,
          boxWidthStyle: ui.BoxWidthStyle.tight,
        );
      } catch (e) {
        b = const <TextBox>[];
      }
      boxes.add(b);
      off += p.length;
    }
    return StratB(tp, boxes);
  }

  double? leftOf(int i) {
    final b = boxes[i];
    if (b.isEmpty) return null;
    return b.map((e) => e.left).reduce(math.min);
  }

  double widthOf(int i) {
    final b = boxes[i];
    if (b.isEmpty) return 0;
    final l = b.map((e) => e.left).reduce(math.min);
    final r = b.map((e) => e.right).reduce(math.max);
    return r - l;
  }

  /// Paints every fragment through its own clip, offset by dx(i).
  void paint(Canvas canvas, Offset origin, double Function(int) dx) {
    for (var i = 0; i < boxes.length; i++) {
      final b = boxes[i];
      if (b.isEmpty) continue;
      final d = dx(i);
      canvas.save();
      // Union clip of the fragment's boxes, translated by the fragment offset.
      final path = Path();
      for (final box in b) {
        path.addRect(box.toRect().translate(origin.dx + d, origin.dy));
      }
      canvas.clipPath(path);
      tp.paint(canvas, origin + Offset(d, 0));
      canvas.restore();
    }
  }
}

// ---------------------------------------------------------------- image diff

Future<ui.Image> _render(Size size, void Function(Canvas) body) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  body(canvas);
  final picture = recorder.endRecording();
  return picture.toImage(size.width.ceil(), size.height.ceil());
}

class Diff {
  Diff(this.differing, this.total, this.inked);
  final int differing;
  final int total;
  final int inked; // pixels inked in either image
  double get pctTotal => total == 0 ? 0 : 100 * differing / total;
  double get pctInked => inked == 0 ? 0 : 100 * differing / inked;
}

Future<Diff> _diff(ui.Image a, ui.Image b, {int tolerance = 12}) async {
  final da = (await a.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final db = (await b.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final n = math.min(da.lengthInBytes, db.lengthInBytes);
  var differing = 0;
  var inked = 0;
  for (var i = 0; i + 3 < n; i += 4) {
    var d = 0;
    for (var c = 0; c < 4; c++) {
      d = math.max(d, (da.getUint8(i + c) - db.getUint8(i + c)).abs());
    }
    if (d > tolerance) differing++;
    final aInk =
        da.getUint8(i) < 250 ||
        da.getUint8(i + 1) < 250 ||
        da.getUint8(i + 2) < 250;
    final bInk =
        db.getUint8(i) < 250 ||
        db.getUint8(i + 1) < 250 ||
        db.getUint8(i + 2) < 250;
    if (aInk || bInk) inked++;
  }
  return Diff(differing, n ~/ 4, inked);
}

Future<void> _save(ui.Image img, String name) async {
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('${outDir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

// ---------------------------------------------------------------- test cases

class Case {
  const Case(
    this.name,
    this.value,
    this.family, {
    this.dir = TextDirection.ltr,
  });
  final String name;
  final String value;
  final String? family; // null = default flutter_test font
  final TextDirection dir;
}

const List<Case> latinCases = [
  Case('AVAWAY To', 'AVAWAY To', null),
  Case('office fine(lig)', 'office ﬁne', null),
  Case('hello world', 'hello world', null),
  Case('cafe combining', 'café café', null),
  Case('digits', '\$1,234.56', null),
];

const List<Case> realFontCases = [
  Case('AVAWAY To', 'AVAWAY To', 'Roboto'),
  Case('office fine(lig)', 'office ﬁne', 'Roboto'),
  Case('office fi(2char)', 'office fine', 'Roboto'),
  Case('hello world', 'hello world', 'Roboto'),
  Case('arabic', 'مرحبا بالعالم', 'NotoSansArabic', dir: TextDirection.rtl),
  Case('persian', 'سلام دنیا', 'NotoSansArabic', dir: TextDirection.rtl),
  Case('devanagari', 'नमस्ते दुनिया', 'NotoSansDevanagari'),
  Case('cafe combining', 'café café', 'Roboto'),
  Case('emoji zwj', '👨‍👩‍👧‍👦 family 🏳️‍🌈', 'NotoColorEmoji'),
  Case('bidi mix', 'abc مرحبا 123', 'NotoSansArabic'),
  Case('cjk fallback', '日本語 text', 'NotoSansJP'),
  Case('digits', '\$1,234.56', 'Roboto'),
];

final List<Map<String, Object?>> results = [];

TextStyle _style(String? family) => TextStyle(
  fontSize: kFontSize,
  color: const Color(0xFF000000),
  fontFamily: family,
  height: null,
);

Future<void> _runCase(Case c, String bucket) async {
  final segs = segmentText(c.value, 'en');
  final parts = segs.map((s) => s.string).toList();
  final style = _style(c.family);
  final dir = c.dir;

  final a = StratA.build(parts, style, dir);
  final b = StratB.build(parts, style, dir);
  final cPainter = _painter(parts.join(), style, dir);

  // (2) per-fragment x deltas.
  var maxXDelta = 0.0;
  var missingBoxes = 0;
  final xPairs = <List<double?>>[];
  for (var i = 0; i < parts.length; i++) {
    final bl = b.leftOf(i);
    if (bl == null) {
      missingBoxes++;
      xPairs.add([a.xs[i], null]);
      continue;
    }
    xPairs.add([a.xs[i], bl]);
    maxXDelta = math.max(maxXDelta, (a.xs[i] - bl).abs());
  }

  // (1) advances.
  final advanceA = a.advance;
  final widthB = b.tp.width;
  final widthC = cPainter.width;

  // (3) images.
  final canvasW = math.max(advanceA, math.max(widthB, widthC)) + 8;
  final canvasH =
      math.max(a.height, math.max(b.tp.height, cPainter.height)) + 8;
  final size = Size(canvasW, canvasH);
  const origin = Offset(4, 4);
  final imgA = await _render(size, (cv) => a.paint(cv, origin, (_) => 0));
  final imgB = await _render(size, (cv) => b.paint(cv, origin, (_) => 0));
  final imgC = await _render(size, (cv) => cPainter.paint(cv, origin));
  final safe = '${bucket}_${c.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}';
  await _save(imgA, '${safe}_A');
  await _save(imgB, '${safe}_B');
  await _save(imgC, '${safe}_C');
  final dAC = await _diff(imgA, imgC);
  final dBC = await _diff(imgB, imgC);

  // (4) timing — layout.
  final swA = Stopwatch()..start();
  for (var r = 0; r < kTimingReps; r++) {
    StratA.build(parts, style, dir);
  }
  swA.stop();
  final swB = Stopwatch()..start();
  for (var r = 0; r < kTimingReps; r++) {
    StratB.build(parts, style, dir);
  }
  swB.stop();

  // (4) timing — paint, 60 frames, every fragment translated by a changing dx.
  double frameDx(int frame, int i) => (frame % 10) * 0.7 + i * 0.13;
  final pA = Stopwatch()..start();
  for (var f = 0; f < kFrames; f++) {
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
    a.paint(cv, origin, (i) => frameDx(f, i));
    rec.endRecording().dispose();
  }
  pA.stop();
  final pB = Stopwatch()..start();
  for (var f = 0; f < kFrames; f++) {
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
    b.paint(cv, origin, (i) => frameDx(f, i));
    rec.endRecording().dispose();
  }
  pB.stop();

  // (4b) timing — record + rasterize (toImageSync), 20 frames.
  const rasterFrames = 20;
  final rA = Stopwatch()..start();
  for (var f = 0; f < rasterFrames; f++) {
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
    a.paint(cv, origin, (i) => frameDx(f, i));
    final pic = rec.endRecording();
    pic.toImageSync(size.width.ceil(), size.height.ceil()).dispose();
    pic.dispose();
  }
  rA.stop();
  final rB = Stopwatch()..start();
  for (var f = 0; f < rasterFrames; f++) {
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
    b.paint(cv, origin, (i) => frameDx(f, i));
    final pic = rec.endRecording();
    pic.toImageSync(size.width.ceil(), size.height.ceil()).dispose();
    pic.dispose();
  }
  rB.stop();

  results.add({
    'bucket': bucket,
    'case': c.name,
    'value': c.value,
    'family': c.family ?? 'FlutterTest(default)',
    'dir': dir.name,
    'segments': parts.length,
    'segStrings': parts,
    'advanceA': advanceA,
    'widthB': widthB,
    'widthC': widthC,
    'advanceDelta': advanceA - widthB,
    'maxXDelta': maxXDelta,
    'missingBoxes': missingBoxes,
    'xPairs': xPairs,
    'diffAC_pctTotal': dAC.pctTotal,
    'diffAC_pctInked': dAC.pctInked,
    'diffBC_pctTotal': dBC.pctTotal,
    'diffBC_pctInked': dBC.pctInked,
    'layoutA_us': swA.elapsedMicroseconds / kTimingReps,
    'layoutB_us': swB.elapsedMicroseconds / kTimingReps,
    'paintA_us': pA.elapsedMicroseconds / kFrames,
    'paintB_us': pB.elapsedMicroseconds / kFrames,
    'rasterA_us': rA.elapsedMicroseconds / rasterFrames,
    'rasterB_us': rB.elapsedMicroseconds / rasterFrames,
    'canvas': [canvasW, canvasH],
  });
  imgA.dispose();
  imgB.dispose();
  imgC.dispose();
}

// ------------------------------------------------------------- failure modes

final List<Map<String, Object?>> failures = [];

void _failureMode(
  String label,
  List<String> parts,
  String? family, {
  TextDirection dir = TextDirection.ltr,
}) {
  final style = _style(family);
  final joined = parts.join();
  final b = StratB.build(parts, style, dir);
  final rows = <Map<String, Object?>>[];
  StratA? a;
  Object? aError;
  try {
    a = StratA.build(parts, style, dir);
  } catch (e) {
    aError = e;
  }
  for (var i = 0; i < parts.length; i++) {
    rows.add({
      'i': i,
      'part': parts[i].codeUnits
          .map((u) => 'U+${u.toRadixString(16).toUpperCase().padLeft(4, '0')}')
          .join(' '),
      'aWidth': a == null ? null : a.painters[i].width,
      'aX': a == null ? null : a.xs[i],
      'bBoxCount': b.boxes[i].length,
      'bLeft': b.leftOf(i),
      'bWidth': b.widthOf(i),
    });
  }
  failures.add({
    'label': label,
    'joined': joined,
    'family': family ?? 'FlutterTest(default)',
    'aError': aError?.toString(),
    'paragraphWidth': b.tp.width,
    'sumAWidths': a?.painters.fold<double>(0, (s, p) => s + p.width),
    'rows': rows,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    const f = 'fonts';
    await _load('Roboto', '${Directory.current.path}/$f/Roboto-Regular.ttf');
    await _load(
      'NotoSansArabic',
      '${Directory.current.path}/$f/NotoSansArabic-Regular.ttf',
    );
    await _load(
      'NotoSansDevanagari',
      '${Directory.current.path}/$f/NotoSansDevanagari-Regular.ttf',
    );
    await _load(
      'NotoColorEmoji',
      '${Directory.current.path}/$f/NotoColorEmoji.ttf',
    );
    await _load(
      'NotoSansJP',
      '${Directory.current.path}/$f/NotoSansJP-Regular.otf',
    );
  });

  test('A vs B vs C across strings', () async {
    for (final c in latinCases) {
      await _runCase(c, 'testfont');
    }
    for (final c in realFontCases) {
      await _runCase(c, 'realfont');
    }
    // (5) memory: RSS around 500 live TextPainters.
    final before = ProcessInfo.currentRss;
    final keep = <TextPainter>[];
    for (var i = 0; i < 500; i++) {
      keep.add(_painter('word$i', _style('Roboto'), TextDirection.ltr));
    }
    final after = ProcessInfo.currentRss;
    // One paragraph painter of comparable total text, for contrast.
    final before1 = ProcessInfo.currentRss;
    final one = _painter(
      List.generate(500, (i) => 'word$i').join(' '),
      _style('Roboto'),
      TextDirection.ltr,
    );
    final after1 = ProcessInfo.currentRss;

    results.add({
      'bucket': 'memory',
      'case': '500 painters',
      'rssBefore': before,
      'rssAfter': after,
      'rssDelta': after - before,
      'perPainter': (after - before) / 500,
      'oneParagraphRssDelta': after1 - before1,
      'keepAlive': keep.length + one.width.toInt(),
    });

    // ---- scaling: does B's per-fragment clip+replay cost O(n^2)?
    final scaling = <Map<String, Object?>>[];
    for (final n in [4, 8, 16, 32, 64]) {
      final words = List<String>.generate(n, (i) => 'w\$i').join(' ');
      final parts = segmentText(words, 'en').map((e) => e.string).toList();
      final st = _style('Roboto');
      final sa = StratA.build(parts, st, TextDirection.ltr);
      final sb = StratB.build(parts, st, TextDirection.ltr);
      final la = Stopwatch()..start();
      for (var r = 0; r < kTimingReps; r++) {
        StratA.build(parts, st, TextDirection.ltr);
      }
      la.stop();
      final lb = Stopwatch()..start();
      for (var r = 0; r < kTimingReps; r++) {
        StratB.build(parts, st, TextDirection.ltr);
      }
      lb.stop();
      final pa = Stopwatch()..start();
      for (var f = 0; f < kFrames; f++) {
        final rec = ui.PictureRecorder();
        sa.paint(Canvas(rec), Offset.zero, (i) => (f % 8) * 0.5);
        rec.endRecording().dispose();
      }
      pa.stop();
      final pb = Stopwatch()..start();
      for (var f = 0; f < kFrames; f++) {
        final rec = ui.PictureRecorder();
        sb.paint(Canvas(rec), Offset.zero, (i) => (f % 8) * 0.5);
        rec.endRecording().dispose();
      }
      pb.stop();
      // Rasterize too: B records n copies of the whole-paragraph draw op, so
      // the real cost shows up at raster, not at record time.
      const rf = 10;
      final w = math.max(sa.advance, sb.tp.width).ceil() + 8;
      final h = math.max(sa.height, sb.tp.height).ceil() + 8;
      final ra = Stopwatch()..start();
      for (var f = 0; f < rf; f++) {
        final rec = ui.PictureRecorder();
        sa.paint(Canvas(rec), const Offset(4, 4), (i) => (f % 8) * 0.5);
        final pic = rec.endRecording();
        pic.toImageSync(w, h).dispose();
        pic.dispose();
      }
      ra.stop();
      final rb = Stopwatch()..start();
      for (var f = 0; f < rf; f++) {
        final rec = ui.PictureRecorder();
        sb.paint(Canvas(rec), const Offset(4, 4), (i) => (f % 8) * 0.5);
        final pic = rec.endRecording();
        pic.toImageSync(w, h).dispose();
        pic.dispose();
      }
      rb.stop();
      scaling.add({
        'rasterA_us': ra.elapsedMicroseconds / rf,
        'rasterB_us': rb.elapsedMicroseconds / rf,
        'fragments': parts.length,
        'layoutA_us': la.elapsedMicroseconds / kTimingReps,
        'layoutB_us': lb.elapsedMicroseconds / kTimingReps,
        'paintA_us': pa.elapsedMicroseconds / kFrames,
        'paintB_us': pb.elapsedMicroseconds / kFrames,
      });
    }
    results.add({'bucket': 'scaling', 'case': 'n words', 'rows': scaling});

    // ---- failure modes.
    // 1. char-morph of "office" -> per-character fragments.
    _failureMode('char-split "office" (Roboto)', 'office'.split(''), 'Roboto');
    _failureMode(
      'char-split "ﬁne" precomposed (Roboto)',
      'ﬁne'.split(''),
      'Roboto',
    );
    // 2. char-morph of an Arabic word.
    _failureMode(
      'char-split "مرحبا" (NotoSansArabic)',
      'مرحبا'.split(''),
      'NotoSansArabic',
      dir: TextDirection.rtl,
    );
    _failureMode(
      'char-split "مرحبة" (NotoSansArabic)',
      'مرحبة'.split(''),
      'NotoSansArabic',
      dir: TextDirection.rtl,
    );
    // 3. Devanagari conjunct split per code unit.
    _failureMode(
      'char-split "नमस्ते" (NotoSansDevanagari)',
      'नमस्ते'.split(''),
      'NotoSansDevanagari',
    );
    // 4. UTF-16 code-unit split of an astral emoji: lone surrogates.
    _failureMode(
      'code-unit split "a😀b" (NotoColorEmoji)',
      'a😀b'.codeUnits.map((u) => String.fromCharCode(u)).toList(),
      'NotoColorEmoji',
    );
    // 5. ZWJ family sequence split per code unit.
    _failureMode(
      'code-unit split "👨‍👩‍👧‍👦" (NotoColorEmoji)',
      '👨‍👩‍👧‍👦'.codeUnits.map((u) => String.fromCharCode(u)).toList(),
      'NotoColorEmoji',
    );
    // 6. grapheme-cluster split of the same family sequence (Torph's own
    //    grapheme segmenter for a single-word value).
    _failureMode(
      'segmentText grapheme split "👨‍👩‍👧‍👦"',
      segmentText('👨‍👩‍👧‍👦', 'en').map((s) => s.string).toList(),
      'NotoColorEmoji',
    );
    // 7. combining mark separated from its base.
    _failureMode('char-split "café" NFD (Roboto)', 'café'.split(''), 'Roboto');

    // 8. What segmentText ACTUALLY produces for a single-word value (no space
    //    => grapheme segmentation): the real Torph char-morph fragment set.
    void graphemeMode(
      String word,
      String? family, {
      TextDirection dir = TextDirection.ltr,
    }) {
      final parts = segmentText(word, 'en').map((s) => s.string).toList();
      _failureMode(
        'segmentText graphemes ($word) n=${parts.length}',
        parts,
        family,
        dir: dir,
      );
    }

    graphemeMode('office', 'Roboto');
    graphemeMode('\uFB01ne', 'Roboto');
    graphemeMode(
      '\u0645\u0631\u062D\u0628\u0627',
      'NotoSansArabic',
      dir: TextDirection.rtl,
    );
    graphemeMode(
      '\u0645\u0631\u062D\u0628\u0629',
      'NotoSansArabic',
      dir: TextDirection.rtl,
    );
    graphemeMode('\u0928\u092E\u0938\u094D\u0924\u0947', 'NotoSansDevanagari');
    graphemeMode('cafe\u0301', 'Roboto');
    graphemeMode('a\u{1F600}b', 'NotoColorEmoji');
    graphemeMode('\u{1F3F3}\uFE0F\u200D\u{1F308}', 'NotoColorEmoji');

    File('${outDir.path}/results.json').writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'results': results, 'failures': failures}),
    );
    // Console dump, so the numbers land in the test log too.
    // ignore: avoid_print
    print(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'results': results, 'failures': failures}),
    );
  });
}
