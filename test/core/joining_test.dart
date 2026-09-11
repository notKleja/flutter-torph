import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

List<String> strings(List<Segment> s) => [for (final x in s) x.string];

void main() {
  test('a single Arabic word is one segment', () {
    expect(strings(segmentText('مرحبا', 'ar')), ['مرحبا']);
    expect(strings(segmentText('مرحبا!', 'ar')), ['مرحبا', '!']);
  });

  test('a changed Arabic word is swapped whole, never letter by letter', () {
    final old = segmentText('مرحبا بالعالم', 'ar');
    final next = diffSegments(old, 'مرحبا بالعالمين', 'ar');
    expect(strings(next.segments), ['مرحبا', '\u00a0', 'بالعالمين']);
    expect(next.splits, isEmpty);
    expect(next.segments.first.id, old.first.id);
  });

  test('a single Arabic word changing keeps no letters', () {
    final old = segmentText('مرحبا', 'ar');
    final next = diffSegments(old, 'مرحبة', 'ar');
    expect(strings(next.segments), ['مرحبة']);
    expect(next.segments.single.id, isNot(old.single.id));
  });

  test('digits next to Arabic still morph by place', () {
    final old = segmentText('السعر 1,234 ريال', 'ar');
    final next = diffSegments(old, 'السعر 1,250 ريال', 'ar');
    expect(strings(next.segments), [
      'السعر',
      '\u00a0',
      '1',
      ',',
      '2',
      '5',
      '0',
      '\u00a0',
      'ريال',
    ]);
  });

  test('Latin words still morph by character', () {
    final next = diffSegments(
      segmentText('hello world', 'en'),
      'hallo world',
      'en',
    );
    expect(strings(next.segments), [
      'h',
      'a',
      'l',
      'l',
      'o',
      '\u00a0',
      'world',
    ]);
  });
}
