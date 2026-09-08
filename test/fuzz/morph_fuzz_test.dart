import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import '../widget/harness.dart';

/// Property tests over random value sequences with random interrupt times.
///
const int kSequences = 320;

/// The zero-width stand-in a rendered empty value uses (INV-2).
const String kZwsp = '\u200b';
const String kNbsp = '\u00a0';

/// Minted IDs are `U+0000 n<counter>` (INV-4).
const String kMintPrefix = '\u0000n';

/// Every settled line whose alignment offset says the items were last measured
/// at a container width the root no longer has — finding F-1, reported once at
final List<String> _staleAlignment = <String>[];

void main() {
  for (var seed = 0; seed < kSequences; seed++) {
    testWidgets('seed $seed', (tester) async {
      await _runSequence(tester, seed);
    });
  }

  testWidgets('a 16 ms storm of 1000 updates leaks no exiting items',
      (tester) async {
    final random = Random(9001);
    await tester.pumpWidget(host(TextMorph(value: 'start')));
    await startClock(tester);
    var worst = 0;
    for (var i = 0; i < 1000; i++) {
      await tester.pumpWidget(host(TextMorph(value: 'v$i ${random.nextInt(999)}')));
      await tester.pump(const Duration(milliseconds: 16));
      final snapshot = snapshotOf(tester);
      worst = max(worst, snapshot.exitingItems.length);
      // Every 16 ms morph leaves at most the previous value's boxes behind, and
      // their text exit fade is over in 100 ms: the set cannot accumulate.
      expect(snapshot.exitingItems.length, lessThan(64),
          reason: 'exiting items accumulated at update $i');
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(snapshotOf(tester).exitingItems, isEmpty);
    expect(snapshotOf(tester).animating, isFalse);
    printOnFailure('worst exiting-item count during the storm: $worst');
  });

  // Declared last, so every sequence above has already run.
  // Evidence accumulated by the sequences above, so this only means anything in
  // a full run of the file — with `--plain-name "F-1"` it passes vacuously. The
  // self-contained repro is
  // `test/parity/widget_adversarial_test.dart --plain-name "F-1"`.
  test('F-1: a settled line is aligned to the width the root actually has', () {
    if (_staleAlignment.isEmpty) return;
    fail('${_staleAlignment.length} settled lines are laid out for a container '
        'width the root no longer has (finding F-1: `MorphEngine.frame` clears '
        '`_container` and only re-measures `if (pinned != null)`, so the frame '
        'that completes a container transition never re-measures at the natural '
        'width — morph_engine.dart:906-916). Invisible under LTR + left, '
        'visible under center/right/RTL.\n${_staleAlignment.take(12).join('\n')}');
  });
}

// ─── the corpus ───

const List<String> _words = <String>[
  'hello',
  'world',
  'foo',
  'bar',
  'the',
  'cat',
  'dog',
  'Copy',
  'Address',
  'Transaction',
];

String _pick(Random r, List<String> from) => from[r.nextInt(from.length)];

/// One value from the corpus the challenge report and the invariants care
/// about: words, numbers, currency, newlines, emoji, RTL and the empty string.
Object _value(Random r) {
  switch (r.nextInt(12)) {
    case 0:
      return _pick(r, _words);
    case 1:
      return '${_pick(r, _words)} ${_pick(r, _words)}';
    case 2:
      return '${_pick(r, _words)} ${_pick(r, _words)} ${_pick(r, _words)}';
    case 3:
      return r.nextInt(2000).toString();
    case 4:
      // Grouped and fractional currency, as a String so the digits are exact.
      final cents = r.nextInt(100).toString().padLeft(2, '0');
      final units = r.nextInt(2000000);
      final grouped = units
          .toString()
          .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
      return '\$$grouped.$cents';
    case 5:
      // A num value: the widget formats it (locale `en`, no decimals option).
      return r.nextBool() ? r.nextInt(1000000) : r.nextInt(100000) / 100;
    case 6:
      return '${_pick(r, _words)}\n${r.nextInt(9999)}';
    case 7:
      return '${_pick(r, _words)}\n${_pick(r, _words)}\n${_pick(r, _words)}';
    case 8:
      return '';
    case 9:
      return _pick(r, const ['😀', '😀 hi', 'hi 😀', '🎉🎉', 'a😀b']);
    case 10:
      return _pick(r, const ['مرحبا', 'مرحبا بالعالم', 'بالعالم مرحبا']);
    case 11:
      return _pick(r,
          const ['1 of 10', '2 of 10', 'café', 'cafe', 'a\n1,234\nb', '  ', '9.99']);
  }
  throw StateError('unreachable');
}

/// A gap between two updates: a 16 ms storm frame, a few frames, or a random
/// interrupt point of the 400 ms morph (1–99 %).
Duration _gap(Random r) {
  switch (r.nextInt(4)) {
    case 0:
      return const Duration(milliseconds: 16);
    case 1:
      return Duration(milliseconds: 16 * (1 + r.nextInt(3)));
    case 2:
      return Duration(milliseconds: 4 * (1 + r.nextInt(99)));
    default:
      return Duration(milliseconds: (400 * (1 + r.nextInt(99)) / 100).round());
  }
}

// ─── the driver ───

Future<void> _runSequence(WidgetTester tester, int seed) async {
  final random = Random(seed);
  final direction = random.nextInt(4) == 0 ? TextDirection.rtl : TextDirection.ltr;
  final align = switch (random.nextInt(5)) {
    0 => TextAlign.center,
    1 => TextAlign.right,
    2 => TextAlign.start,
    _ => TextAlign.left,
  };

  var starts = 0;
  var completes = 0;
  var cancels = 0;
  final problems = <String>[];

  Widget build(Object value) => host(
        TextMorph(
          value: value,
          onAnimationStart: () => starts++,
          onAnimationComplete: () => completes++,
          onAnimationCancel: () => cancels++,
        ),
        direction: direction,
        textAlign: align,
      );

  final values = <Object>[
    for (var i = 0; i < 4 + random.nextInt(6); i++) _value(random)
  ];

  final limits = _Limits();
  var morphs = 0;
  var rendered = false;
  var first = true;

  for (final value in values) {
    final before = first ? null : snapshotOf(tester);
    final beforeValue = before?.value ?? '';
    final beforeWidth = before?.size.width ?? 0.0;

    await tester.pumpWidget(build(value));
    final after = snapshotOf(tester);
    if (first) {
      first = false;
      await startClock(tester);
    }

    // The engine no-ops when the *formatted* value is unchanged, and an initial
    // `''` leaves it in the initial-render state (Q-018), so the first update
    if (after.value != beforeValue) {
      if (!rendered) {
        rendered = true;
      } else {
        morphs++;
        // INV-13: the container starts from the layout size that was on screen,
        // unless that was zero — then there is no container animation at all.
        if (beforeWidth > 0 && (after.size.width - beforeWidth).abs() > 0.6) {
          problems.add('INV-13 ${_q(value)}: the container jumped from '
              '$beforeWidth to ${after.size.width} instead of animating from it');
        }
      }
    }

    _check(tester, value, problems, 'after ${_q(value)}', limits);
    _balance(problems, starts, completes, cancels, 'after ${_q(value)}');

    final gap = _gap(random);
    for (var elapsed = Duration.zero;
        elapsed < gap;
        elapsed += const Duration(milliseconds: 16)) {
      await tester.pump(const Duration(milliseconds: 16));
      _check(tester, value, problems, 'during ${_q(value)}', limits);
      _balance(problems, starts, completes, cancels, 'during ${_q(value)}');
    }
  }

  // Settled: pump frame by frame to the end, as a real app does.
  for (var i = 0; i < 60 && snapshotOf(tester).animating; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    _check(tester, values.last, problems, 'settling', limits);
  }
  await tester.pump(const Duration(milliseconds: 401));
  final settled = snapshotOf(tester);
  if (settled.animating) problems.add('still animating 1.3 s after the last update');
  if (stateOf(tester).debugTickerActive) {
    problems.add('the ticker is still active 1.3 s after the last update');
  }
  if ((settled.size.width - settled.naturalSize.width).abs() > 0.001 ||
      (settled.size.height - settled.naturalSize.height).abs() > 0.001) {
    problems.add('settled size ${settled.size} != natural ${settled.naturalSize}');
  }
  if (settled.exitingItems.isNotEmpty) {
    problems.add('${settled.exitingItems.length} exiting items survived the morph');
  }
  _check(tester, values.last, problems, 'settled', limits);
  _restingLayout(tester, settled, direction, align, problems,
      'seed $seed ($direction, $align, last ${_q(values.last)})');

  if (starts != morphs) {
    problems.add('CALLBACK-001: $morphs morphs fired $starts onAnimationStart');
  }
  if (completes + cancels != starts) {
    problems.add('INV-11: $starts starts but ${completes + cancels} terminal '
        'callbacks ($completes complete, $cancels cancel)');
  }

  // Semantics: one node, labelled with the whole value (INV-15, ACCESS-001).
  final handle = tester.ensureSemantics();
  expect(tester.getSemantics(find.byType(TextMorph)).label, settled.value,
      reason: 'the semantics label is the value');
  handle.dispose();

  if (problems.isNotEmpty) {
    fail('FUZZ FAILURE seed $seed '
        '(direction: $direction, align: $align, values: ${values.map(_q).join(' → ')})\n'
        '${problems.take(10).join('\n')}');
  }
}

String _q(Object value) => '"${value.toString().replaceAll('\n', r'\n')}"'
    '${value is num ? ' (num)' : ''}';

/// `starts - (completes + cancels)` is the number of morphs in flight: 0 or 1,
/// never more, never negative (INV-11).
void _balance(List<String> problems, int starts, int completes, int cancels, String tag) {
  final inFlight = starts - completes - cancels;
  if (inFlight < 0 || inFlight > 1) {
    problems.add('INV-11 $tag: $starts starts, $completes complete, $cancels '
        'cancel — $inFlight morphs in flight');
  }
}

// ─── invariants ───

/// The tallest root the sequence has produced, so a mover's slide can be
/// bounded without re-deriving the engine's `slideDistance`.
class _Limits {
  double maxHeight = 0;
}

void _check(WidgetTester tester, Object value, List<String> problems, String tag,
    _Limits limits) {
  final snapshot = snapshotOf(tester);
  limits.maxHeight =
      max(limits.maxHeight, max(snapshot.size.height, snapshot.naturalSize.height));
  final render = renderOf(tester);
  final live = snapshot.liveItems;

  // The render box is always laid out at the frame it was handed.
  if ((render.size.width - snapshot.size.width).abs() > 0.001 ||
      (render.size.height - snapshot.size.height).abs() > 0.001) {
    problems.add('$tag: render box ${render.size} != frame ${snapshot.size}');
  }

  // INV-1: live IDs are unique (exiting copies may duplicate them — Q-022).
  final ids = <String>{};
  for (final item in live) {
    if (!ids.add(item.id)) {
      problems.add('$tag INV-1: duplicate live id ${_j(item.id)}');
    }
  }

  // INV-2: the live strings are the value.
  final rendered =
      live.where((i) => !i.isBreak).map((i) => i.text == kNbsp ? ' ' : i.text).join();
  final expected = snapshot.value.replaceAll('\n', '');
  // An empty value renders the zero-width stand-in — except an *initial* render
  // of `''`, which upstream leaves as an empty root
  final wanted = expected.isEmpty ? <String>[kZwsp, ''] : <String>[expected];
  if (!wanted.contains(rendered)) {
    problems.add('$tag INV-2: rendered ${_j(rendered)} != value '
        '${wanted.map(_j).join(' or ')}');
  }
  if (value is String && snapshot.value != value) {
    problems.add('$tag: the frame value is ${_j(snapshot.value)}, expected ${_j(value)}');
  }
  if (value is num && !snapshot.value.contains(RegExp(r'[0-9]'))) {
    problems.add('$tag: the frame value ${_j(snapshot.value)} holds no digits of $value');
  }

  for (final item in snapshot.items) {
    // INV-3: no empty strings but the placeholder.
    if (item.text.isEmpty) {
      problems.add('$tag INV-3: an item with an empty string (id ${_j(item.id)})');
    }
    // INV-4: the two ID namespaces are disjoint.
    if (item.id.contains('\u0000') && !item.id.startsWith(kMintPrefix)) {
      problems.add('$tag INV-4: id ${_j(item.id)} holds U+0000 but is not minted');
    }
    // INV-5 (proxy): a kind is a per-character number kind.
    if (item.kind != null) {
      final isDigit = item.text.length == 1 && RegExp(r'[0-9]').hasMatch(item.text);
      if (isDigit != (item.kind == SegmentKind.digit)) {
        problems.add('$tag INV-5: ${_j(item.text)} has kind ${item.kind}');
      }
    }
    // INV-6: separators are position-keyed.
    if (item.isBreak && !item.id.startsWith('newline-')) {
      problems.add('$tag INV-6: a break with id ${_j(item.id)}');
    }
    if (item.text == kNbsp &&
        !item.id.startsWith('space-') &&
        !item.id.startsWith(kNbsp)) {
      problems.add('$tag INV-6: an NBSP item with id ${_j(item.id)}');
    }
    // INV-14: a mover slides one line box of the root it was created in, so it
    // can never exceed the tallest root the sequence has had (plus the pixel
    final mover = item.moverTransform;
    if (mover != null && mover.ty.abs() > limits.maxHeight + 1.001) {
      problems.add('$tag INV-14: mover ty ${mover.ty} exceeds every line box the '
          'sequence has had (${limits.maxHeight + 1.001})');
    }
    if (item.opacity < 0 || item.opacity > 1) {
      problems.add('$tag: opacity ${item.opacity} out of range');
    }
    if (!item.transform.tx.isFinite ||
        !item.transform.ty.isFinite ||
        !item.transform.sx.isFinite ||
        !item.transform.sy.isFinite) {
      problems.add('$tag: a non-finite transform on ${_j(item.text)}');
    }
  }

  if (!snapshot.size.width.isFinite || !snapshot.size.height.isFinite) {
    problems.add('$tag: a non-finite root size ${snapshot.size}');
  }
  if (snapshot.size.width < 0 || snapshot.size.height < 0) {
    problems.add('$tag: a negative root size ${snapshot.size}');
  }
}

/// INV-9 at rest: the live items sit at their measured layout positions, so the
/// animated coordinates never leaked into the layout.
void _restingLayout(WidgetTester tester, TextMorphSnapshot snapshot,
    TextDirection direction, TextAlign align, List<String> problems, String seedTag) {
  final lines = <List<ItemFrame>>[<ItemFrame>[]];
  for (final item in snapshot.liveItems) {
    if (item.isBreak) {
      lines.add(<ItemFrame>[]);
    } else {
      lines.last.add(item);
    }
  }
  final resolved = switch (align) {
    TextAlign.center => 'center',
    TextAlign.right => 'right',
    TextAlign.end => direction == TextDirection.rtl ? 'left' : 'right',
    TextAlign.start => direction == TextDirection.rtl ? 'right' : 'left',
    _ => 'left',
  };
  // Under LTR + left the line always starts at 0, so no container width can
  // shift it: a mismatch there can only be a per-item coordinate error.
  final alignmentCanShift = resolved != 'left' || direction == TextDirection.rtl;
  final width = snapshot.size.width;

  for (final line in lines) {
    if (line.isEmpty) continue;
    final lineWidth = line.fold(0.0, (w, i) => w + i.width);
    final free = width - lineWidth;
    final double left = free <= 0
        ? (direction == TextDirection.rtl ? free : 0.0)
        : switch (resolved) {
            'center' => free / 2,
            'right' => free,
            _ => 0.0,
          };
    final deltas = <double>[];
    var run = 0.0;
    for (final item in line) {
      final expected = direction == TextDirection.rtl
          ? left + lineWidth - run - item.width
          : left + run;
      deltas.add(item.x - expected);
      if (item.transform.tx != 0 || item.transform.ty != 0) {
        problems.add('INV-9: ${_j(item.text)} rests with a translate '
            '(${item.transform.tx}, ${item.transform.ty})');
      }
      run += item.width;
    }
    final uniform = deltas.every((d) => (d - deltas.first).abs() <= 0.01);
    if (uniform && deltas.first.abs() <= 0.01) continue;
    if (uniform && alignmentCanShift) {
      final implied = width - deltas.first * (resolved == 'center' ? 2 : 1);
      _staleAlignment.add('$seedTag: the line ${_j(line.map((i) => i.text).join())} '
          'rests ${deltas.first.toStringAsFixed(3)} px from where the root width '
          '${width.toStringAsFixed(3)} puts it (as if the root were still '
          '${implied.toStringAsFixed(3)} wide)');
      continue;
    }
    for (var i = 0; i < line.length; i++) {
      if (deltas[i].abs() > 0.01) {
        problems.add('INV-9: ${_j(line[i].text)} rests at x ${line[i].x}, '
            'measured layout says ${line[i].x - deltas[i]}');
      }
    }
  }
}

String _j(String s) {
  final buffer = StringBuffer('"');
  for (final unit in s.codeUnits) {
    if (unit < 0x20 || unit == 0x7f || unit > 0x7e) {
      buffer.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return (buffer..write('"')).toString();
}
