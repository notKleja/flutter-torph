import 'package:flutter_test/flutter_test.dart';
import 'package:torph/testing.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

/// True for a lone UTF-16 surrogate or a bare combining mark: fragments a
/// grapheme cluster must never be split into.
bool _isBrokenFragment(String text) {
  if (text.length != 1) return false;
  final code = text.codeUnitAt(0);
  final isSurrogate = code >= 0xD800 && code <= 0xDFFF;
  final isCombiningMark = code >= 0x0300 && code <= 0x036F;
  return isSurrogate || isCombiningMark;
}

void _expectNoBrokenFragments(TextMorphSnapshot snapshot) {
  for (final item in snapshot.items) {
    expect(
      _isBrokenFragment(item.text),
      isFalse,
      reason: 'item "${item.text}" (id ${item.id}) is a broken fragment',
    );
  }
}

void main() {
  testWidgets(
    'a single-word emoji grapheme cluster morph splits no surrogate',
    (tester) async {
      await tester.pumpWidget(host(TextMorph(value: '👋🏽')));
      await tester.pumpWidget(host(TextMorph(value: '👋')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 500));

      final snapshot = snapshotOf(tester);
      expect(snapshot.animating, isFalse);
      _expectNoBrokenFragments(snapshot);
    },
  );

  testWidgets('a multi-word emoji grapheme cluster morph splits no surrogate', (
    tester,
  ) async {
    await tester.pumpWidget(host(TextMorph(value: 'hi 👋🏽')));
    await tester.pumpWidget(host(TextMorph(value: 'hi 👋')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 500));

    final snapshot = snapshotOf(tester);
    expect(snapshot.animating, isFalse);
    _expectNoBrokenFragments(snapshot);
  });
}
