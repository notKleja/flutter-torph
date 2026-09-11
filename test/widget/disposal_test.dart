import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  testWidgets('popping a route with a morphing TextMorph disposes cleanly', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const SizedBox(),
          ),
        ),
      ),
    );

    navigatorKey.currentState!.push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _MorphingPage(),
      ),
    );
    await tester.pump();
    await tester.pump(); // flushes the microtask that changes the value
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 50)); // mid-morph

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('TickerMode(enabled: false) freezes the morph and resumes when '
      're-enabled', (tester) async {
    var muted = false;
    var value = 'a';
    late StateSetter rebuild;

    Widget app() => StatefulBuilder(
      builder: (context, setter) {
        rebuild = setter;
        return TickerMode(
          enabled: !muted,
          child: host(TextMorph(value: value)),
        );
      },
    );

    await tester.pumpWidget(app());
    rebuild(() => value = 'ab');
    await tester.pump();
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final timeBeforeMute = snapshotOf(tester).now;
    expect(snapshotOf(tester).animating, isTrue);

    rebuild(() => muted = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(snapshotOf(tester).now, timeBeforeMute);

    rebuild(() => muted = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(snapshotOf(tester).animating, isFalse);
  });

  testWidgets(
    'disposing while an animation-start callback is queued for the same '
    'frame fires nothing',
    (tester) async {
      final log = <String>[];
      Widget app(String value) => host(
        TextMorph(value: value, onAnimationStart: () => log.add('start')),
      );

      await tester.pumpWidget(app('a'));

      // Unmount from an earlier post-frame callback than the deferred
      // onAnimationStart (DEV-003), without scheduling a new frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        tester.binding.attachRootWidget(
          tester.binding.wrapWithDefaultView(host(const SizedBox())),
        );
        tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
        tester.binding.buildOwner!.finalizeTree();
      });
      await tester.pumpWidget(app('ab'));

      expect(log, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MorphingPage extends StatefulWidget {
  const _MorphingPage();

  @override
  State<_MorphingPage> createState() => _MorphingPageState();
}

class _MorphingPageState extends State<_MorphingPage> {
  String _value = 'a';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) setState(() => _value = 'ab');
    });
  }

  @override
  Widget build(BuildContext context) => host(TextMorph(value: _value));
}
