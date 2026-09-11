import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

/// `TextAlign` inside a box wider than the content, as `Text` behaves.
void main() {
  group('block alignment inside a wider box', () {
    testWidgets('centre in a 300-wide SizedBox centres the block', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: TextMorph(value: 'hi', textAlign: TextAlign.center),
          ),
        ),
      );
      final render = renderOf(tester);
      expect(render.size.width, 300);
      // "hi" is 2 * fontSize = 40 wide.
      expect(render.debugBlockOffsetX, closeTo((300 - 40) / 2, 0.01));
    });

    testWidgets('right in a 300-wide SizedBox pushes to the far edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: TextMorph(value: 'hi', textAlign: TextAlign.right),
          ),
        ),
      );
      final render = renderOf(tester);
      expect(render.debugBlockOffsetX, closeTo(300 - 40, 0.01));
    });

    testWidgets('RTL + TextAlign.start in a wide box sits at the right edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: TextMorph(value: 'hi', textAlign: TextAlign.start),
          ),
          direction: TextDirection.rtl,
        ),
      );
      final render = renderOf(tester);
      expect(render.debugBlockOffsetX, closeTo(300 - 40, 0.01));
    });

    testWidgets('loose constraints (content-sized box) are unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(TextMorph(value: 'hi', textAlign: TextAlign.center)),
      );
      final render = renderOf(tester);
      expect(render.size.width, 40);
      expect(render.debugBlockOffsetX, 0);
    });

    testWidgets('the disabled plain-text path aligns identically', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: TextMorph(
              value: 'hi',
              textAlign: TextAlign.center,
              disabled: true,
            ),
          ),
        ),
      );
      final render = renderOf(tester);
      expect(render.size.width, 300);
      expect(render.debugBlockOffsetX, closeTo((300 - 40) / 2, 0.01));
    });

    testWidgets('equal-width box never shifts', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 40,
            child: TextMorph(value: 'hi', textAlign: TextAlign.right),
          ),
        ),
      );
      final render = renderOf(tester);
      expect(render.debugBlockOffsetX, 0);
    });
  });
}
