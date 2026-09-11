// ignore_for_file: avoid_print
// RTL/bidi morph audit (SONNET B); widgets built `bidi: false` so numbers stay comparable to the browser fixtures.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/testing.dart';
import 'package:torph/torph.dart';

import '../widget/harness.dart';
import 'rtl_corpus.dart';

const Duration _duration = defaultDuration; // 400ms

const List<double> _morphFractions = [0, .10, .25, .37, .50, .73, .90, 1.0];

const List<double> _interruptFractions = [
  .01,
  .05,
  .10,
  .25,
  .37,
  .50,
  .73,
  .90,
  .99,
];

Duration _at(double fraction) =>
    Duration(microseconds: (_duration.inMicroseconds * fraction).round());

Map<String, dynamic> _itemSnapshot(ItemFrame item) => {
  'id': item.id,
  'text': item.text,
  'kind': item.kind?.toString(),
  'exiting': item.exiting,
  'visualRect': {
    'left': item.visualRect.left,
    'top': item.visualRect.top,
    'right': item.visualRect.right,
    'bottom': item.visualRect.bottom,
  },
  'moverTransform': item.moverTransform == null
      ? null
      : {
          'tx': item.moverTransform!.tx,
          'ty': item.moverTransform!.ty,
          'sx': item.moverTransform!.sx,
          'sy': item.moverTransform!.sy,
        },
  'opacity': item.opacity,
};

String _numericSlotString(List<ItemFrame> visualSorted) =>
    visualSorted.where((i) => i.kind != null).map((i) => i.text).join();

List<ItemFrame> _visualSorted(TextMorphSnapshot snap) {
  final items = snap.items.where((i) => !i.isBreak).toList();
  items.sort((a, b) => a.visualRect.left.compareTo(b.visualRect.left));
  return items;
}

class _SampleAnomalies {
  final List<String> digitOrderChanges = [];
  final List<String> sideFlips = [];
  final List<String> overlaps = [];
  final List<String> snaps = [];
}

final List<Map<String, dynamic>> _caseReports = [];
final _SampleAnomalies _anomalies = _SampleAnomalies();

void _recordSample(
  String caseId,
  String phase,
  double now,
  TextMorphSnapshot snap,
  List<Map<String, dynamic>> samples,
  Map<String, ItemFrame>? previousById,
) {
  final visual = _visualSorted(snap);
  final byId = {for (final i in visual) i.id: i};
  final digitString = _numericSlotString(visual);

  samples.add({
    'phase': phase,
    'now': now,
    'items': visual.map(_itemSnapshot).toList(),
    'numericSlotString': digitString,
  });

  if (previousById != null) {
    final prevOrder = previousById.values.where((i) => i.kind != null).toList()
      ..sort((a, b) => a.visualRect.left.compareTo(b.visualRect.left));
    final curOrder = visual.where((i) => i.kind != null).toList();
    final prevIds = prevOrder.map((i) => i.id).where(byId.containsKey).toList();
    final curIds = curOrder
        .map((i) => i.id)
        .where(previousById.containsKey)
        .toList();
    if (prevIds.join(',') != curIds.join(',') &&
        prevIds.toSet().length == curIds.toSet().length &&
        prevIds.isNotEmpty) {
      _anomalies.digitOrderChanges.add(
        '$caseId @$phase/$now: numeric slot order $prevIds -> $curIds',
      );
    }

    String? sideOf(List<ItemFrame> order, String id) {
      final idx = order.indexWhere((i) => i.id == id);
      if (idx == -1) return null;
      final hasLeftDigit = idx > 0 && order[idx - 1].kind != null;
      final hasRightDigit =
          idx < order.length - 1 && order[idx + 1].kind != null;
      if (hasLeftDigit && !hasRightDigit) return 'right-of-digit';
      if (hasRightDigit && !hasLeftDigit) return 'left-of-digit';
      if (hasLeftDigit && hasRightDigit) return 'between-digits';
      return null;
    }

    for (final item in visual) {
      if (item.kind == null) continue;
      if (!previousById.containsKey(item.id)) continue;
      final before = sideOf(prevOrder, item.id);
      final after = sideOf(curOrder, item.id);
      if (before != null && after != null && before != after) {
        _anomalies.sideFlips.add(
          '$caseId @$phase/$now: "${item.text}" (${item.id}) $before -> $after',
        );
      }
    }

    for (final item in visual) {
      final prev = previousById[item.id];
      if (prev == null) continue;
      final delta = (item.visualRect.left - prev.visualRect.left).abs();
      if (item.width > 0 && delta > 0.5 * item.width) {
        _anomalies.snaps.add(
          '$caseId @$phase/$now: "${item.text}" '
          '(${item.id}) left ${prev.visualRect.left.toStringAsFixed(2)} '
          '-> ${item.visualRect.left.toStringAsFixed(2)} '
          '(Δ=${delta.toStringAsFixed(2)}, w=${item.width.toStringAsFixed(2)})',
        );
      }
    }
  }
}

void _checkRestOverlaps(String caseId, TextMorphSnapshot snap) {
  final live = snap.liveItems.where((i) => !i.isBreak).toList();
  for (var i = 0; i < live.length; i++) {
    for (var j = i + 1; j < live.length; j++) {
      final a = live[i].visualRect;
      final b = live[j].visualRect;
      final sameLine = a.top < b.bottom && b.top < a.bottom;
      if (!sameLine) continue;
      final overlapsX = a.left < b.right - 0.01 && b.left < a.right - 0.01;
      if (overlapsX) {
        _anomalies.overlaps.add(
          '$caseId (rest): "${live[i].text}" '
          '(${live[i].id}) overlaps "${live[j].text}" (${live[j].id})',
        );
      }
    }
  }
}

Future<void> _driveMorph(WidgetTester tester, RtlCase c) async {
  final dir = TextDirection.rtl; // brief: "drive TextMorph in RTL"
  final locale = Locale(c.locale);
  final samples = <Map<String, dynamic>>[];

  await tester.pumpWidget(
    host(
      TextMorph(value: c.text, locale: locale, bidi: false),
      direction: dir,
    ),
  );
  await tester.pumpWidget(
    host(
      TextMorph(value: c.morph!['to'] as String, locale: locale, bidi: false),
      direction: dir,
    ),
  );
  await startClock(tester);

  Map<String, ItemFrame>? previousById;
  var previousElapsed = Duration.zero;
  for (final f in _morphFractions) {
    final target = _at(f);
    final delta = target - previousElapsed;
    if (delta > Duration.zero) await tester.pump(delta);
    previousElapsed = target;
    final snap = snapshotOf(tester);
    _recordSample(c.id, 'morph', f, snap, samples, previousById);
    previousById = {for (final i in snap.items) i.id: i};
  }
  await tester.pump(_duration);
  _checkRestOverlaps(c.id, snapshotOf(tester));

  _caseReports.add({
    'id': c.id,
    'category': c.category,
    'kind': 'morph',
    'from': c.text,
    'to': c.morph!['to'],
    'samples': samples,
  });
}

Future<void> _driveInterrupt(WidgetTester tester, RtlCase c) async {
  final dir = TextDirection.rtl;
  final locale = Locale(c.locale);
  final samples = <Map<String, dynamic>>[];

  await tester.pumpWidget(
    host(
      TextMorph(value: c.text, locale: locale, bidi: false),
      direction: dir,
    ),
  );
  await tester.pumpWidget(
    host(
      TextMorph(
        value: c.interrupt!['to'] as String,
        locale: locale,
        bidi: false,
      ),
      direction: dir,
    ),
  );
  await startClock(tester);

  Map<String, ItemFrame>? previousById;
  var previousElapsed = Duration.zero;
  var interrupted = false;
  for (final f in _interruptFractions) {
    final target = _at(f);
    final delta = target - previousElapsed;
    if (delta > Duration.zero) await tester.pump(delta);
    previousElapsed = target;

    if (!interrupted && f >= .37) {
      await tester.pumpWidget(
        host(
          TextMorph(
            value: c.interrupt!['then'] as String,
            locale: locale,
            bidi: false,
          ),
          direction: dir,
        ),
      );
      interrupted = true;
      previousById = null;
    }

    final snap = snapshotOf(tester);
    _recordSample(
      c.id,
      interrupted ? 'interrupt-then' : 'interrupt-to',
      f,
      snap,
      samples,
      previousById,
    );
    previousById = {for (final i in snap.items) i.id: i};
  }
  await tester.pump(_duration);
  final settled = snapshotOf(tester);
  _recordSample(c.id, 'interrupt-settled', 1.0, settled, samples, null);
  _checkRestOverlaps(c.id, settled);

  _caseReports.add({
    'id': c.id,
    'category': c.category,
    'kind': 'interrupt',
    'from': c.text,
    'to': c.interrupt!['to'],
    'then': c.interrupt!['then'],
    'samples': samples,
  });
}

Future<void> _driveStorm(WidgetTester tester, RtlCase c) async {
  final dir = TextDirection.rtl;
  final locale = Locale(c.locale);
  final samples = <Map<String, dynamic>>[];
  final values = [c.text, ...c.storm!.cast<String>()];

  await tester.pumpWidget(
    host(
      TextMorph(value: values.first, locale: locale, bidi: false),
      direction: dir,
    ),
  );
  await startClock(tester);

  Map<String, ItemFrame>? previousById;
  for (var i = 1; i < values.length; i++) {
    await tester.pumpWidget(
      host(
        TextMorph(value: values[i], locale: locale, bidi: false),
        direction: dir,
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final snap = snapshotOf(tester);
    _recordSample(c.id, 'storm', i.toDouble(), snap, samples, previousById);
    previousById = {for (final i2 in snap.items) i2.id: i2};
  }
  await tester.pump(_duration);
  _checkRestOverlaps(c.id, snapshotOf(tester));

  _caseReports.add({
    'id': c.id,
    'category': c.category,
    'kind': 'storm',
    'values': values,
    'samples': samples,
  });
}

void main() {
  final cases = loadRtlCorpus();
  final morphCases = cases.where((c) => c.morph != null).toList();
  final interruptCases = cases.where((c) => c.interrupt != null).toList();
  final stormCases = cases.where((c) => c.storm != null).toList();

  tearDownAll(() {
    Directory('reports/rtl').createSync(recursive: true);
    File('reports/rtl/flutter_morph.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'corpusSource': rtlCorpusIsFallback ? 'fallback' : 'generated',
        'morphCaseCount': morphCases.length,
        'interruptCaseCount': interruptCases.length,
        'stormCaseCount': stormCases.length,
        'anomalies': {
          'digitOrderChanges': _anomalies.digitOrderChanges,
          'sideFlips': _anomalies.sideFlips,
          'overlaps': _anomalies.overlaps,
          'snaps': _anomalies.snaps,
        },
        'cases': _caseReports,
      }),
    );

    final md = StringBuffer()
      ..writeln('# RTL morph audit report')
      ..writeln()
      ..writeln(
        'Corpus source: ${rtlCorpusIsFallback ? "fallback" : "generated"}. '
        '${morphCases.length} morph cases, ${interruptCases.length} interrupt '
        'cases, ${stormCases.length} storm cases driven in an RTL root.',
      )
      ..writeln()
      ..writeln(
        '## Digit / numeric-slot order changes between samples '
        '(${_anomalies.digitOrderChanges.length})',
      )
      ..writeln();
    if (_anomalies.digitOrderChanges.isEmpty) {
      md.writeln('None observed.');
    } else {
      for (final a in _anomalies.digitOrderChanges.take(50)) {
        md.writeln('- $a');
      }
    }
    md
      ..writeln()
      ..writeln(
        '## Separator/sign side flips relative to digits '
        '(${_anomalies.sideFlips.length})',
      )
      ..writeln();
    if (_anomalies.sideFlips.isEmpty) {
      md.writeln('None observed.');
    } else {
      for (final a in _anomalies.sideFlips.take(50)) {
        md.writeln('- $a');
      }
    }
    md
      ..writeln()
      ..writeln('## Same-line overlaps at rest (${_anomalies.overlaps.length})')
      ..writeln();
    if (_anomalies.overlaps.isEmpty) {
      md.writeln('None observed.');
    } else {
      for (final a in _anomalies.overlaps.take(50)) {
        md.writeln('- $a');
      }
    }
    md
      ..writeln()
      ..writeln(
        '## Visual snaps (Δleft > 0.5·width, same phase) '
        '(${_anomalies.snaps.length})',
      )
      ..writeln();
    if (_anomalies.snaps.isEmpty) {
      md.writeln('None observed.');
    } else {
      for (final a in _anomalies.snaps.take(50)) {
        md.writeln('- $a');
      }
    }
    File(
      'reports/rtl/flutter_morph_report.md',
    ).writeAsStringSync(md.toString());

    print(
      'rtl_morph_audit: ${morphCases.length} morph + '
      '${interruptCases.length} interrupt + ${stormCases.length} storm cases; '
      '${_anomalies.digitOrderChanges.length} order-changes, '
      '${_anomalies.sideFlips.length} side-flips, '
      '${_anomalies.overlaps.length} overlaps, '
      '${_anomalies.snaps.length} snaps -> reports/rtl/flutter_morph.json, '
      'reports/rtl/flutter_morph_report.md',
    );
  });

  for (final c in morphCases) {
    testWidgets('${c.id} morph "${c.text}" -> "${c.morph!['to']}"', (
      tester,
    ) async {
      await _driveMorph(tester, c);
      expect(true, isTrue); // audit only
    });
  }
  for (final c in interruptCases) {
    testWidgets(
      '${c.id} interrupt "${c.text}" -> "${c.interrupt!['to']}" -> "${c.interrupt!['then']}"',
      (tester) async {
        await _driveInterrupt(tester, c);
        expect(true, isTrue);
      },
    );
  }
  for (final c in stormCases) {
    testWidgets('${c.id} storm "${c.text}"', (tester) async {
      await _driveStorm(tester, c);
      expect(true, isTrue);
    });
  }

  test('at least one case exercised', () {
    expect(
      morphCases.length + interruptCases.length + stormCases.length,
      greaterThan(0),
    );
  });
}
