import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/replacement.dart';
import 'package:torph/src/motion/carry.dart';
import 'package:torph/src/motion/easing.dart';
import 'package:torph/src/motion/flip.dart';
import 'package:torph/src/motion/spring.dart';

import 'fixtures.dart';

const _tol = 1e-9;

void _expectClose(List<dynamic> expected, List<double> actual, String reason) {
  expect(actual.length, expected.length, reason: '$reason length');
  for (var i = 0; i < expected.length; i++) {
    final e = (expected[i] as num).toDouble();
    expect(actual[i], closeTo(e, _tol), reason: '$reason [$i]');
  }
}

void main() {
  group('easing (oracle:easing)', () {
    final ts = List<double>.generate(101, (i) => i / 100);
    for (final c in loadFixture('easing') as List) {
      final ease = c['ease'] as String;
      test(ease.length > 40 ? '${ease.substring(0, 40)}…' : ease, () {
        final fn = parseEasing(ease);
        expect(fn != null, c['valid'], reason: 'validity of ${show(ease)}');
        if (fn == null) return;
        _expectClose(c['values'] as List, ts.map(fn).toList(), 'value');
        _expectClose(c['slopes'] as List, ts.map((t) => slopeAt(fn, t)).toList(), 'slope');
      });
    }
  });

  group('spring (oracle:spring)', () {
    for (final c in loadFixture('spring') as List) {
      final p = c['params'] as Map;
      test(p.toString(), () {
        final params = SpringParams(
          stiffness: (p['stiffness'] as num?)?.toDouble() ?? 100,
          damping: (p['damping'] as num?)?.toDouble() ?? 10,
          mass: (p['mass'] as num?)?.toDouble() ?? 1,
          precision: (p['precision'] as num?)?.toDouble() ?? 0.001,
        );
        final r = spring(params);
        expect(r.duration, c['duration']);
        expect(r.easing, c['easing']);
        final resolved = resolveEase(params, 400);
        expect(resolved.duration, c['resolved']['duration']);
        expect(resolved.ease, c['resolved']['ease']);
      });
    }
    test('string ease keeps the fallback duration', () {
      expect(resolveEase('ease', 123).duration, 123);
    });
  });

  group('carry (oracle:carry)', () {
    final ts = List<double>.generate(101, (i) => i / 100);
    for (final c in loadFixture('carry') as List) {
      final base = c['base'] as String;
      final v = c['velocity'];
      final velocity = v == null
          ? double.nan
          : v is String
              ? (v == 'Infinity' ? double.infinity : double.nan)
              : (v as num).toDouble();
      test('${base.length > 20 ? base.substring(0, 20) : base} v=$v', () {
        final fn = parseEasing(base)!;
        final carried = carry(fn, velocity);
        expect(carried.k, closeTo((c['k'] as num).toDouble(), _tol));
        _expectClose(c['values'] as List, ts.map(carried.curve).toList(), 'curve');
        expect(sampleEasing(carried.curve, 400), c['sampled400']);
        expect(sampleEasing(carried.curve, 1000), c['sampled1000']);
        expect(sampleEasing(carried.curve, 100), c['sampled100']);
      });
    }
  });

  group('anchors (oracle:anchors, oracle:exit-anchors)', () {
    test('findNearestAnchor', () {
      for (final c in loadFixture('anchors') as List) {
        final ids = (c['ids'] as List).cast<String>();
        final persistent = (c['persistent'] as List).cast<String>().toSet();
        final target = c['target'] as int;
        expect(findNearestAnchor(target, ids, persistent), c['backwardFirst']);
        expect(findNearestAnchor(target, ids, persistent, AnchorDirection.forwardFirst),
            c['forwardFirst']);
      }
    });
    test('resolveExitingAnchors', () {
      for (final c in loadFixture('exit-anchors') as List) {
        final oldIds = (c['oldIds'] as List).cast<String>();
        final newIds = (c['newIds'] as List).cast<String>().toSet();
        final exitingIds = (c['exiting'] as List).cast<String>().toSet();
        final exiting = {for (var i = 0; i < oldIds.length; i++) if (exitingIds.contains(oldIds[i])) i};
        final res = resolveExitingAnchors(oldIds, exiting, newIds);
        final expected = (c['anchors'] as List).map((e) => [e[0], e[1]]).toList();
        final actual = [
          for (var i = 0; i < oldIds.length; i++)
            if (exiting.contains(i)) [oldIds[i], res[i]]
        ];
        expect(actual, expected);
      }
    });
  });

  group('replacedRuns (oracle:replaced-runs)', () {
    test('runs of at least $groupMin', () {
      for (final c in loadFixture('replaced-runs') as List) {
        final all = (c['all'] as List).cast<String>();
        final members = (c['members'] as List).cast<String>().toSet();
        expect(replacedRuns(all, members), c['runs']);
      }
    });
  });

  group('JS number semantics', () {
    test('jsRound halves go up', () {
      expect(jsRound(-2.5), -2);
      expect(jsRound(2.5), 3);
      expect(jsRound(-0.4), -0.0);
    });
    test('jsNumberToString', () {
      expect(jsNumberToString(1), '1');
      expect(jsNumberToString(0.5), '0.5');
      expect(jsNumberToString(-0.0), '0');
      expect(jsNumberToString(1e-7), '1e-7');
    });
    test('jsNumber', () {
      expect(jsNumber(''), 0);
      expect(jsNumber(' 1e3 '), 1000);
      expect(jsNumber('.5'), 0.5);
      expect(jsNumber('0x10'), 16);
      expect(jsNumber('abc').isNaN, true);
      expect(jsNumber('Infinity').isFinite, false);
    });
  });
}
