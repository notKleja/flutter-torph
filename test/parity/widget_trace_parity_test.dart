import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/testing.dart';
import 'package:torph/torph.dart';

import '../widget/harness.dart';

/// Widget-level parity against the browser oracle (`oracle/fixtures/runtime/*.json`).
/// Upstream Torph has no bidi reordering, so every widget is built with `bidi: false`.

/// Relative tolerance on a normalised translate or root size (2 %).
const double _rel = 0.02;

/// Absolute slack on a normalised length, in Flutter px. Chrome lays out in
/// 1/64 px LayoutUnits and the trace rounds to 4 dp; scaled by S ≈ 1.66 that is
const double _abs = 0.25;

/// Scales and opacities are unitless: compare them outright.
const double _unit = 2e-3;

/// The trace's normalised line-height ratio tolerance (mover slides are ±1
/// line box, so this is 0.2 % of a line).
const double _norm = 2e-3;

void main() {
  setUpAll(() => debugSplitJoiningWords = true);
  tearDownAll(() => debugSplitJoiningWords = false);

  final dir = Directory('oracle/fixtures/runtime');
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.json') &&
                !f.path.endsWith('probes.json') &&
                !f.path.contains('segmenter'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  var traces = 0;
  for (final file in files) {
    final trace = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    if (trace['samples'] == null || trace['steps'] == null) continue;
    traces++;
    testWidgets(
      '${trace['slug']}: ${trace['label']}',
      (tester) => _runWidgetTrace(tester, trace),
    );
  }
  test('every runtime trace is driven through the widget', () {
    expect(traces, 168);
  });
}

// ─── option plumbing ───

TextAlign _alignOf(String? css) => switch (css) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  'end' => TextAlign.end,
  'start' => TextAlign.start,
  'justify' => TextAlign.justify,
  _ => TextAlign.left,
};

Locale? _localeOf(String? tag) {
  if (tag == null) return null;
  final parts = tag.split('-');
  return parts.length == 1 ? Locale(parts[0]) : Locale(parts[0], parts[1]);
}

Duration _durOf(double ms) => Duration(microseconds: (ms * 1000).round());

String _ms(double t) =>
    t == t.roundToDouble() ? t.toInt().toString() : t.toString();

// ─── the driver ───

Future<void> _runWidgetTrace(
  WidgetTester tester,
  Map<String, dynamic> trace,
) async {
  final page = (trace['page'] as Map).cast<String, dynamic>();
  final options =
      (trace['options'] as Map?)?.cast<String, dynamic>() ?? const {};
  final samples = (trace['samples'] as List).cast<Map<String, dynamic>>();
  final steps = (trace['steps'] as List).cast<Map<String, dynamic>>();
  final expectedCallbacks = (trace['callbacks'] as List)
      .cast<Map<String, dynamic>>();

  final direction = page['direction'] == 'rtl'
      ? TextDirection.rtl
      : TextDirection.ltr;
  final align = _alignOf(page['textAlign'] as String?);

  Object ease = defaultEase;
  final rawEase = options['ease'];
  if (rawEase is Map) {
    ease = SpringParams(
      stiffness: (rawEase['stiffness'] as num?)?.toDouble() ?? 100,
      damping: (rawEase['damping'] as num?)?.toDouble() ?? 10,
      mass: (rawEase['mass'] as num?)?.toDouble() ?? 1,
      precision: (rawEase['precision'] as num?)?.toDouble() ?? 0.001,
    );
  } else if (rawEase is String) {
    ease = rawEase;
  }
  final duration = Duration(
    milliseconds: ((options['duration'] as num?) ?? 400).toInt(),
  );
  final locale = _localeOf(options['locale'] as String?);

  // ─── metric scales, from the trace's resting boxes ───
  final measurer = TextMeasurer(
    style: testStyle,
    textScaler: TextScaler.noScaling,
    textDirection: direction,
    textAlign: align,
    locale: locale ?? const Locale(defaultLocaleTag),
  );
  final browserWidths = <String, double>{};
  final browserHeights = <String, double>{};
  for (final sample in [
    trace['initialSample'] as Map<String, dynamic>,
    ...samples,
  ]) {
    for (final it in (sample['items'] as List).cast<Map<String, dynamic>>()) {
      if (it['tag'] == 'br' || it['exiting'] == true) continue;
      final sc = it['scale'] as Map;
      final tr = it['translate'] as Map;
      if (sc['sx'] != 1 || sc['sy'] != 1 || tr['tx'] != 0 || tr['ty'] != 0) {
        continue;
      }
      final rect = it['rect'] as Map;
      browserWidths[it['text'] as String] = (rect['w'] as num).toDouble();
      browserHeights[it['text'] as String] = (rect['h'] as num).toDouble();
    }
  }
  final ratios = <double>[];
  for (final entry in browserWidths.entries) {
    if (entry.value == 0) continue;
    ratios.add(measurer.painterFor(entry.key).width / entry.value);
  }
  ratios.sort();
  final uniformWidths =
      ratios.isNotEmpty && ratios.last / ratios.first - 1 <= 0.02;
  final double? sx = uniformWidths ? ratios[ratios.length ~/ 2] : null;

  final heights = browserHeights.values
      .toSet()
      .map((h) => (h * 10).round())
      .toSet();
  final uniformHeights = heights.length == 1;
  final browserLine = browserHeights.values.isEmpty
      ? 24.0
      : browserHeights.values.reduce(math.max);
  final flutterLine = measurer.painterFor('​').height;
  final sy = flutterLine / browserLine;
  measurer.dispose();

  // ─── the widget under test ───
  final log = <String>[];
  final logAt = <double>[];
  var clock = 0.0;
  void record(String name) {
    log.add(name);
    logAt.add(clock);
  }

  Widget build(Object value, int? cursorIndex) => host(
    TextMorph(
      value: value,
      cursorIndex: cursorIndex,
      ease: ease,
      duration: duration,
      locale: locale,
      scale: (options['scale'] as bool?) ?? true,
      numbers: (options['numbers'] as bool?) ?? true,
      decimals: (options['decimals'] as num?)?.toInt(),
      bidi: false,
      onAnimationStart: () => record('start'),
      onAnimationComplete: () => record('complete'),
      onAnimationCancel: () => record('cancel'),
    ),
    direction: direction,
    textAlign: align,
  );

  final problems = <String>[];
  final skips = <String>[];
  if (!uniformWidths) {
    skips.add(
      'horizontal geometry (tx, x, root width): the browser font is '
      'not metrically proportional to the test font '
      '(width ratios ${ratios.first.toStringAsFixed(3)}..${ratios.last.toStringAsFixed(3)})',
    );
  }
  if (!uniformHeights) {
    skips.add(
      'vertical geometry (ty, y, root height): the browser line boxes '
      'are not all one height (${browserHeights.values.toSet().toList()..sort()})',
    );
  }

  final traceNorm = _Norm();
  final engineNorm = _Norm();

  void compare(Map<String, dynamic> sample, double t) {
    final snapshot = stateOf(tester).debugSnapshot();
    if (snapshot == null) {
      problems.add('t=$t no frame delivered to the widget');
      return;
    }
    final render = renderOf(tester);
    final root = (sample['root'] as Map).cast<String, dynamic>();

    // The render box is laid out at exactly the frame's animated size.
    if ((render.size.width - snapshot.size.width).abs() > 0.001 ||
        (render.size.height - snapshot.size.height).abs() > 0.001) {
      problems.add(
        't=$t render box ${render.size} != frame size ${snapshot.size}',
      );
    }

    if (sx != null) {
      _near(
        problems,
        't=$t root.width',
        (root['computedWidth'] as num).toDouble() * sx,
        snapshot.size.width,
      );
    }
    if (uniformHeights) {
      _near(
        problems,
        't=$t root.height',
        (root['computedHeight'] as num).toDouble() * sy,
        snapshot.size.height,
      );
    }

    final expectedItems = (sample['items'] as List)
        .cast<Map<String, dynamic>>()
        .where((it) => it['tag'] != 'br')
        .toList();
    final actualItems = snapshot.items.where((i) => !i.isBreak).toList();
    final expectedKeys = [
      for (final it in expectedItems)
        '${traceNorm(it['id'] as String)}${it['exiting'] == true ? '!' : ''}',
    ];
    final actualKeys = [
      for (final it in actualItems)
        '${engineNorm(it.id)}${it.exiting ? '!' : ''}',
    ];
    final expectedTexts = [
      for (final it in expectedItems) it['text'] as String,
    ];
    final actualTexts = [for (final it in actualItems) it.text];
    if (expectedKeys.join('|') != actualKeys.join('|') ||
        expectedTexts.join('|') != actualTexts.join('|')) {
      problems.add(
        't=$t items differ\n'
        '  expected ${expectedKeys.map(jsonEncode).join(' ')}\n'
        '  actual   ${actualKeys.map(jsonEncode).join(' ')}\n'
        '  expected text ${expectedTexts.map(jsonEncode).join(' ')}\n'
        '  actual   text ${actualTexts.map(jsonEncode).join(' ')}',
      );
      return;
    }

    for (var i = 0; i < expectedItems.length; i++) {
      final e = expectedItems[i];
      final a = actualItems[i];
      final tag = 't=$t ${jsonEncode(e['text'])}(${expectedKeys[i]})';
      final tr = e['translate'] as Map;
      final sc = e['scale'] as Map;
      _near(
        problems,
        '$tag sx',
        (sc['sx'] as num).toDouble(),
        a.transform.sx,
        tol: _unit,
      );
      _near(
        problems,
        '$tag sy',
        (sc['sy'] as num).toDouble(),
        a.transform.sy,
        tol: _unit,
      );
      _near(
        problems,
        '$tag opacity',
        (e['opacity'] as num).toDouble(),
        a.opacity,
        tol: _unit,
      );

      // `detachFromFlow` pins a departing box at `offsetLeft`/`offsetTop`,
      // which the browser rounds to whole CSS pixels — and the port rounds the
      final pinSlack = a.exiting ? 0.5 * (sx ?? 1) + 0.5 : 0.0;
      final txBrowser = (tr['tx'] as num).toDouble();
      if (sx != null) {
        _near(problems, '$tag tx', txBrowser * sx, a.transform.tx);
        _near(
          problems,
          '$tag x',
          ((e['rect'] as Map)['x'] as num).toDouble() * sx,
          a.visualRect.left,
          tol: _abs + pinSlack,
        );
      }
      final tyBrowser = (tr['ty'] as num).toDouble();
      if (uniformHeights) {
        _near(problems, '$tag ty', tyBrowser * sy, a.transform.ty);
        _near(
          problems,
          '$tag y',
          ((e['rect'] as Map)['y'] as num).toDouble() * sy,
          a.visualRect.top,
          tol: _abs + pinSlack,
        );
      }

      final mover = e['mover'] as Map?;
      if (mover != null) {
        // A mover slides exactly one line box, so its normalised travel is
        // font-independent: compare ty / lineHeight on both sides.
        final mt = mover['translate'] as Map;
        final expectedNorm = (mt['ty'] as num).toDouble() / browserLine;
        final actualNorm = (a.moverTransform?.ty ?? double.nan) / flutterLine;
        _near(
          problems,
          '$tag mover.ty/line',
          expectedNorm,
          actualNorm,
          tol: _norm,
          rel: 0,
        );
        _near(
          problems,
          '$tag mover.opacity',
          (mover['opacity'] as num).toDouble(),
          a.moverOpacity ?? double.nan,
          tol: _unit,
        );
        if ((mt['tx'] as num) != 0) {
          problems.add(
            '$tag mover.tx is ${mt['tx']} in the browser (expected 0)',
          );
        }
      } else if (a.moverTransform != null) {
        problems.add('$tag has a mover in the widget but not in the browser');
      }
    }
  }

  // ─── clock discipline ───
  //
  var lastTick = 0.0;

  final initial = trace['initial'];
  clock = 0;
  await tester.pumpWidget(
    build(
      initial is num ? initial : initial as String,
      trace['initialCursorIndex'] as int?,
    ),
  );
  compare(trace['initialSample'] as Map<String, dynamic>, -1);

  final events = <double>{
    for (final s in steps) (s['at'] as num).toDouble(),
    for (final s in samples) (s['t'] as num).toDouble(),
    for (final c in expectedCallbacks) (c['at'] as num).toDouble(),
  }.toList()..sort();

  var nextStep = 0;
  var nextSample = 0;
  for (final t in events) {
    // Set the clock before the pump: a callback fired by the tick that lands on
    // `t` must be timestamped `t`.
    clock = t;
    if (stateOf(tester).debugTickerActive && t > lastTick) {
      await tester.pump(_durOf(t - lastTick));
    }
    lastTick = t;
    while (nextStep < steps.length && (steps[nextStep]['at'] as num) <= t) {
      final step = steps[nextStep++];
      final wasActive = stateOf(tester).debugTickerActive;
      final value = step['value'];
      await tester.pumpWidget(
        build(
          value is num ? value : value as String,
          step['cursorIndex'] as int?,
        ),
      );
      if (!wasActive && stateOf(tester).debugTickerActive) {
        // Consume the zero-elapsed first tick of the fresh ticker run.
        await tester.pump();
      }
      lastTick = t;
    }
    while (nextSample < samples.length &&
        (samples[nextSample]['t'] as num).toDouble() == t) {
      compare(samples[nextSample++], t);
    }
  }
  expect(nextSample, samples.length, reason: 'every sample was compared');

  final expected = [
    for (final c in expectedCallbacks) '${c['name']}@${c['at']}',
  ];
  final actual = [
    for (var i = 0; i < log.length; i++) '${log[i]}@${_ms(logAt[i])}',
  ];
  if (expected.join(',') != actual.join(',')) {
    problems.add('callbacks: expected $expected, actual $actual');
  }

  if (problems.isNotEmpty) {
    fail(
      'PARITY FAILURE ${trace['slug']} — ${problems.length} mismatches'
      '${skips.isEmpty ? '' : '\nskipped: ${skips.join('; ')}'}'
      '\n${problems.take(12).join('\n')}',
    );
  }
  if (skips.isNotEmpty) {
    printOnFailure('skipped: ${skips.join('; ')}');
  }
}

/// Minted IDs (` n<counter>`) differ between runs; both streams are renamed by
/// first appearance so only their *pattern* is compared.
class _Norm {
  final Map<String, String> map = {};
  String call(String id) => id.startsWith('\u0000n')
      ? map.putIfAbsent(id, () => '#${map.length}')
      : id;
}

void _near(
  List<String> problems,
  String what,
  double expected,
  double actual, {
  double tol = _abs,
  double rel = _rel,
}) {
  if (actual.isNaN) {
    problems.add('$what: browser $expected, widget NaN');
    return;
  }
  final slack = math.max(tol, expected.abs() * rel);
  if ((expected - actual).abs() > slack) {
    problems.add(
      '$what: browser-normalised ${_r(expected)}, '
      'widget ${_r(actual)} (slack ${_r(slack)})',
    );
  }
}

String _r(double v) => v.toStringAsFixed(4);
