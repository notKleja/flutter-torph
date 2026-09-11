import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  testWidgets('an Arabic morph never paints a lone letter', (tester) async {
    Widget app(String v) =>
        host(TextMorph(value: v), direction: TextDirection.rtl);
    await tester.pumpWidget(app('مرحبا بالعالم'));
    await tester.pumpWidget(app('أهلا بالعالمين'));
    await startClock(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      for (final item in snapshotOf(tester).items) {
        if (item.text.trim().isEmpty) continue;
        expect(item.text.characters.length, greaterThan(1), reason: item.text);
      }
    }
    expect(snapshotOf(tester).animating, isFalse);
    expect(find.bySemanticsLabel('أهلا بالعالمين'), findsOneWidget);
  });
}
