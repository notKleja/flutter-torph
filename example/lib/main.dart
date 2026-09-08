import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:torph/torph.dart';

import 'corpus.dart';
import 'options_panel.dart';

void main() => runApp(const TorphExampleApp());

const TextStyle _tabular = TextStyle(
  fontSize: 40,
  fontWeight: FontWeight.w600,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

class TorphExampleApp extends StatelessWidget {
  const TorphExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'torph',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3B5BDB), useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DemoOptions _options = const DemoOptions();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('torph')),
      body: Directionality(
        textDirection: _options.textDirection,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: <Widget>[
            OptionsPanel(
              options: _options,
              onChanged: (DemoOptions o) => setState(() => _options = o),
            ),
            CounterDemo(options: _options),
            CorpusDemo(
              key: Key('sentence-demo-${_options.language}'),
              title: 'Sentence',
              cases: _options.arabic ? arabicSentenceCases : sentenceCases,
              options: _options,
            ),
            CorpusDemo(
              key: Key('number-demo-${_options.language}'),
              title: 'Numbers',
              cases: _options.arabic ? arabicNumberCases : numberCases,
              options: _options,
              tabular: true,
            ),
            CorpusDemo(
              key: Key('multiline-demo-${_options.language}'),
              title: 'Multi-line',
              cases: _options.arabic ? arabicMultilineCases : multilineCases,
              options: _options,
            ),
            EditableDemo(options: _options),
            StormDemo(options: _options),
          ],
        ),
      ),
    );
  }
}

class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.title,
    required this.body,
    this.controls = const <Widget>[],
  });

  final String title;
  final Widget body;
  final List<Widget> controls;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            body,
            if (controls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: controls),
            ],
          ],
        ),
      ),
    );
  }
}

class CounterDemo extends StatefulWidget {
  const CounterDemo({super.key, required this.options});

  final DemoOptions options;

  @override
  State<CounterDemo> createState() => _CounterDemoState();
}

class _CounterDemoState extends State<CounterDemo> {
  final math.Random _random = math.Random(7);
  double _total = 1234.5;

  void _add(double delta) => setState(() => _total += delta);

  @override
  Widget build(BuildContext context) {
    return DemoCard(
      title: 'Counter',
      body: DefaultTextStyle.merge(
        style: _tabular,
        child: Row(
          children: <Widget>[
            const Text(r'$'),
            TextMorph(
              key: const Key('counter'),
              value: _total,
              decimals: 2,
              locale: widget.options.locale,
              textAlign: widget.options.textAlign,
              scale: widget.options.scale,
              numbers: widget.options.numbers,
              blur: widget.options.blur,
              duration: widget.options.duration,
              bidi: widget.options.bidi,
              ease: widget.options.ease,
              disabled: widget.options.disabled,
            ),
          ],
        ),
      ),
      controls: <Widget>[
        FilledButton.tonal(
          key: const Key('counter-inc'),
          onPressed: () => _add(1),
          child: const Text('+1'),
        ),
        FilledButton.tonal(onPressed: () => _add(0.05), child: const Text('+0.05')),
        FilledButton.tonal(onPressed: () => _add(9999), child: const Text('+9,999')),
        FilledButton.tonal(
          onPressed: () => setState(() => _total = -_total),
          child: const Text('negate'),
        ),
        FilledButton.tonal(
          onPressed: () => setState(() => _total = _random.nextDouble() * 1000000),
          child: const Text('random'),
        ),
      ],
    );
  }
}

class CorpusDemo extends StatefulWidget {
  const CorpusDemo({
    super.key,
    required this.title,
    required this.cases,
    required this.options,
    this.tabular = false,
  });

  final String title;
  final List<CorpusCase> cases;
  final DemoOptions options;
  final bool tabular;

  @override
  State<CorpusDemo> createState() => _CorpusDemoState();
}

class _CorpusDemoState extends State<CorpusDemo> {
  int _caseIndex = 0;
  int _valueIndex = 0;
  Timer? _timer;

  CorpusCase get _case => widget.cases[_caseIndex];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() => setState(() => _valueIndex = (_valueIndex + 1) % _case.values.length);

  void _select(int index) => setState(() {
    _caseIndex = index;
    _valueIndex = 0;
  });

  void _toggleAuto() => setState(() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    } else {
      _timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _next());
    }
  });

  @override
  Widget build(BuildContext context) {
    return DemoCard(
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButton<int>(
            isExpanded: true,
            value: _caseIndex,
            onChanged: (int? i) {
              if (i != null) _select(i);
            },
            items: <DropdownMenuItem<int>>[
              for (int i = 0; i < widget.cases.length; i++)
                DropdownMenuItem<int>(value: i, child: Text(widget.cases[i].label)),
            ],
          ),
          const SizedBox(height: 12),
          DefaultTextStyle.merge(
            style: widget.tabular
                ? _tabular
                : const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            child: TextMorph(
              value: _case.values[_valueIndex],
              locale: widget.options.locale,
              textAlign: widget.options.textAlign,
              scale: widget.options.scale,
              numbers: widget.options.numbers,
              blur: widget.options.blur,
              duration: widget.options.duration,
              bidi: widget.options.bidi,
              ease: widget.options.ease,
              disabled: widget.options.disabled,
            ),
          ),
        ],
      ),
      controls: <Widget>[
        FilledButton.tonal(onPressed: _next, child: const Text('next')),
        FilledButton.tonal(
          onPressed: _toggleAuto,
          child: Text(_timer == null ? 'auto-cycle' : 'stop'),
        ),
      ],
    );
  }
}

class EditableDemo extends StatefulWidget {
  const EditableDemo({super.key, required this.options});

  final DemoOptions options;

  @override
  State<EditableDemo> createState() => _EditableDemoState();
}

class _EditableDemoState extends State<EditableDemo> {
  final TextEditingController _controller = TextEditingController(text: r'$4.20');
  String _value = r'$4.20';
  int? _cursorIndex;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final TextSelection selection = _controller.selection;
      setState(() {
        _value = _controller.text;
        _cursorIndex = selection.isValid ? selection.baseOffset : null;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoCard(
      title: 'Editable field (cursorIndex)',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const Key('editable-field'),
            controller: _controller,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'amount'),
          ),
          const SizedBox(height: 12),
          DefaultTextStyle.merge(
            style: _tabular,
            child: TextMorph(
              value: _value,
              cursorIndex: _cursorIndex,
              locale: widget.options.locale,
              textAlign: widget.options.textAlign,
              scale: widget.options.scale,
              numbers: widget.options.numbers,
              blur: widget.options.blur,
              duration: widget.options.duration,
              bidi: widget.options.bidi,
              ease: widget.options.ease,
              disabled: widget.options.disabled,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'cursorIndex: ${_cursorIndex ?? "none"} — caret matching instead of '
            'place matching, so typing inserts a digit rather than renumbering '
            'the column.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class StormDemo extends StatefulWidget {
  const StormDemo({super.key, required this.options});

  final DemoOptions options;

  @override
  State<StormDemo> createState() => _StormDemoState();
}

class _StormDemoState extends State<StormDemo> {
  static const List<String> _arabicStorm = <String>[
    'المعاملة آمنة',
    'جارٍ معالجة المعاملة',
    r'$1,234.50',
    r'$9,876.50',
    'مرحبا بالعالم',
    'بالعالم مرحبا',
    '2 من 10 مكتملة',
    '7 من 15 مكتملة',
  ];

  static const List<String> _storm = <String>[
    'Transaction Safe',
    'Processing Transaction',
    r'$1,234.50',
    r'$9,876.50',
    'hello world',
    'world hello',
    '2 of 10 done',
    '7 of 15 done',
  ];

  Timer? _timer;
  int _tick = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    final Stopwatch clock = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (Timer t) {
      if (clock.elapsedMilliseconds > 2000) {
        t.cancel();
        setState(() => _timer = null);
        return;
      }
      setState(() => _tick++);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DemoCard(
      title: 'Interruption storm',
      body: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
        child: TextMorph(
          value: (widget.options.arabic ? _arabicStorm : _storm)[_tick % _storm.length],
          locale: widget.options.locale,
          textAlign: widget.options.textAlign,
          scale: widget.options.scale,
          numbers: widget.options.numbers,
          blur: widget.options.blur,
          duration: widget.options.duration,
          bidi: widget.options.bidi,
          ease: widget.options.ease,
          disabled: widget.options.disabled,
        ),
      ),
      controls: <Widget>[
        FilledButton.tonal(
          key: const Key('storm'),
          onPressed: _timer == null ? _start : null,
          child: Text(_timer == null ? 'storm (16 ms for 2 s)' : 'running…'),
        ),
      ],
    );
  }
}
