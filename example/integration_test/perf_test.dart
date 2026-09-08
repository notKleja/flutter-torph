import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:torph/torph.dart';

final ValueNotifier<Object> _value = ValueNotifier<Object>('');

const TextStyle _big = TextStyle(
  fontSize: 34,
  fontWeight: FontWeight.w600,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

const TextStyle _small = TextStyle(fontSize: 16);

Widget _host({TextStyle style = _big, int? decimals}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topLeft,
          child: DefaultTextStyle(
            style: style,
            child: ValueListenableBuilder<Object>(
              valueListenable: _value,
              builder: (BuildContext context, Object value, Widget? child) {
                return TextMorph(
                  value: value,
                  decimals: decimals,
                  locale: const Locale('en'),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

String _words(int chars) {
  const List<String> pool = <String>[
    'transaction',
    'safe',
    'processing',
    'hello',
    'world',
    'torph',
    'morph',
    'segment',
    'value',
    'number',
    'ledger',
    'balance',
    'pending',
    'settled',
    'account',
  ];
  final math.Random random = math.Random(chars);
  final StringBuffer buffer = StringBuffer();
  while (buffer.length < chars) {
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(pool[random.nextInt(pool.length)]);
  }
  return buffer.toString().substring(0, chars);
}

String _mutate(String source, int seed) {
  final math.Random random = math.Random(seed);
  final List<String> words = source.split(' ');
  for (int i = 0; i < words.length; i += 3) {
    words[i] = String.fromCharCodes(
      words[i].codeUnits.reversed,
    );
    if (random.nextBool() && words.length > 4) {
      words[i] = '${words[i]}s';
    }
  }
  return words.join(' ');
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> settle(WidgetTester tester, {int frames = 40}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> cycle(
    WidgetTester tester,
    List<Object> values, {
    int repeats = 4,
    int framesBetween = 40,
  }) async {
    for (int r = 0; r < repeats; r++) {
      for (final Object value in values) {
        _value.value = value;
        await settle(tester, frames: framesBetween);
      }
    }
  }

  testWidgets('tiny counter', (WidgetTester tester) async {
    _value.value = 100;
    await tester.pumpWidget(_host(decimals: 0));
    await settle(tester);
    await binding.watchPerformance(() async {
      for (int i = 0; i < 24; i++) {
        _value.value = 100 + i;
        await settle(tester, frames: 30);
      }
    }, reportKey: 'tiny_counter');
  });

  testWidgets('sentence', (WidgetTester tester) async {
    _value.value = 'Transaction Safe';
    await tester.pumpWidget(_host());
    await settle(tester);
    await binding.watchPerformance(() async {
      await cycle(tester, <Object>[
        'Processing Transaction',
        'Transaction Safe',
        'Copy Address',
        'Address Copied',
      ], repeats: 3);
    }, reportKey: 'sentence');
  });

  testWidgets('100 chars', (WidgetTester tester) async {
    final String a = _words(100);
    final String b = _mutate(a, 100);
    _value.value = a;
    await tester.pumpWidget(_host(style: _small));
    await settle(tester);
    await binding.watchPerformance(() async {
      await cycle(tester, <Object>[b, a], repeats: 4);
    }, reportKey: 'chars_100');
  });

  testWidgets('500 chars', (WidgetTester tester) async {
    final String a = _words(500);
    final String b = _mutate(a, 500);
    _value.value = a;
    await tester.pumpWidget(_host(style: _small));
    await settle(tester);
    await binding.watchPerformance(() async {
      await cycle(tester, <Object>[b, a], repeats: 3);
    }, reportKey: 'chars_500');
  });

  testWidgets('rapid number updates', (WidgetTester tester) async {
    _value.value = 1234.5;
    await tester.pumpWidget(_host(decimals: 2));
    await settle(tester);
    await binding.watchPerformance(() async {
      double total = 1234.5;
      for (int i = 0; i < 125; i++) {
        total += 1 + i * 0.07;
        _value.value = total;
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle(tester);
    }, reportKey: 'rapid_numbers');
  });

  testWidgets('rapid text updates', (WidgetTester tester) async {
    const List<String> pool = <String>[
      'Transaction Safe',
      'Processing Transaction',
      'hello world',
      'world hello',
      'npm i torph',
      'pnpm add torph',
    ];
    _value.value = pool.first;
    await tester.pumpWidget(_host());
    await settle(tester);
    await binding.watchPerformance(() async {
      for (int i = 0; i < 125; i++) {
        _value.value = pool[i % pool.length];
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle(tester);
    }, reportKey: 'rapid_text');
  });

  testWidgets('interruption storm', (WidgetTester tester) async {
    const List<Object> pool = <Object>[
      'Transaction Safe',
      r'$1,234.50',
      'hello world',
      r'$9,876.50',
      '2 of 10 done',
      '7 of 15 done',
      'world hello',
      r'$4,020.00',
    ];
    _value.value = pool.first;
    await tester.pumpWidget(_host());
    await settle(tester);
    await binding.watchPerformance(() async {
      for (int i = 0; i < 125; i++) {
        _value.value = pool[i % pool.length];
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle(tester);
    }, reportKey: 'interruption_storm');
  });

  testWidgets('multiline', (WidgetTester tester) async {
    _value.value = 'hello world\nfoo bar\ngoodbye moon';
    await tester.pumpWidget(_host(style: _small));
    await settle(tester);
    await binding.watchPerformance(() async {
      await cycle(tester, <Object>[
        'hello world\ngoodbye moon',
        'alpha bravo\ncharlie delta\nhello world',
        'charlie delta\nalpha bravo',
        'hello world\nfoo bar\ngoodbye moon',
      ], repeats: 3);
    }, reportKey: 'multiline');
  });
}
