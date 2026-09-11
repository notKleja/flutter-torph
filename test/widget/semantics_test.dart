import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  testWidgets('one node labelled with the value, during a morph too', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    expect(find.bySemanticsLabel('hello'), findsOneWidget);

    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 200));

    // Mid-morph the label is already the new value, as upstream's SR node is.
    expect(find.bySemanticsLabel('hello world'), findsOneWidget);
    expect(find.bySemanticsLabel('hello'), findsNothing);

    final node = tester.getSemantics(find.byType(TextMorph));
    expect(node.label, 'hello world');
    expect(node.textDirection, TextDirection.ltr);

    handle.dispose();
  });

  testWidgets('the label follows the direction', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(TextMorph(value: 'مرحبا'), direction: TextDirection.rtl),
    );
    final node = tester.getSemantics(find.byType(TextMorph));
    expect(node.label, 'مرحبا');
    expect(node.textDirection, TextDirection.rtl);
    handle.dispose();
  });

  testWidgets('an RTL value renders, settles, and keeps its rtl label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(TextMorph(value: 'مرحبا'), direction: TextDirection.rtl),
    );
    await tester.pumpWidget(
      host(TextMorph(value: 'مرحبا بالعالم'), direction: TextDirection.rtl),
    );
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(snapshotOf(tester).animating, isFalse);
    expect(tester.takeException(), isNull);
    final node = tester.getSemantics(find.byType(TextMorph));
    expect(node.label, 'مرحبا بالعالم');
    expect(node.textDirection, TextDirection.rtl);
    handle.dispose();
  });

  testWidgets('a numeric value is labelled with the formatted string', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(TextMorph(value: 1234)));
    expect(find.bySemanticsLabel('1,234'), findsOneWidget);
    handle.dispose();
  });
}
