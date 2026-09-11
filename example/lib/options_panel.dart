import 'package:flutter/material.dart';
import 'package:torph/torph.dart';

class DemoOptions {
  const DemoOptions({
    this.language = 'en',
    this.textAlign = TextAlign.start,
    this.textDirection = TextDirection.ltr,
    this.scale = true,
    this.numbers = true,
    this.easeLabel = 'cubic-bezier(0.19, 1, 0.22, 1)',
    this.blur = defaultBlur,
    this.duration = defaultDuration,
    this.bidi = true,
    this.disabled = false,
  });

  final String language;
  final TextAlign textAlign;
  final TextDirection textDirection;

  Locale get locale => Locale(language);
  bool get arabic => language == 'ar';
  final bool scale;
  final bool numbers;
  final String easeLabel;
  final double blur;
  final Duration duration;
  final bool bidi;
  final bool disabled;

  Object get ease => easeChoices[easeLabel]!;

  DemoOptions copyWith({
    String? language,
    TextAlign? textAlign,
    TextDirection? textDirection,
    bool? scale,
    bool? numbers,
    String? easeLabel,
    double? blur,
    Duration? duration,
    bool? bidi,
    bool? disabled,
  }) {
    return DemoOptions(
      language: language ?? this.language,
      textAlign: textAlign ?? this.textAlign,
      textDirection: textDirection ?? this.textDirection,
      scale: scale ?? this.scale,
      numbers: numbers ?? this.numbers,
      easeLabel: easeLabel ?? this.easeLabel,
      blur: blur ?? this.blur,
      duration: duration ?? this.duration,
      bidi: bidi ?? this.bidi,
      disabled: disabled ?? this.disabled,
    );
  }
}

const Map<String, Object> easeChoices = <String, Object>{
  'cubic-bezier(0.19, 1, 0.22, 1)': 'cubic-bezier(0.19, 1, 0.22, 1)',
  'ease': 'ease',
  'ease-in-out': 'ease-in-out',
  'linear': 'linear',
  'spring(200, 20)': SpringParams(stiffness: 200, damping: 20),
  'spring(100, 10)': SpringParams(),
  'spring(400, 12)': SpringParams(stiffness: 400, damping: 12),
};

class OptionsPanel extends StatelessWidget {
  const OptionsPanel({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final DemoOptions options;
  final ValueChanged<DemoOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Options', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _Dropdown<String>(
                  label: 'language',
                  value: options.language,
                  items: const <String>['en', 'ar'],
                  nameOf: (String v) => v == 'ar' ? 'العربية (RTL)' : 'English',
                  onChanged: (String v) => onChanged(
                    options.copyWith(
                      language: v,
                      textDirection: v == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                  ),
                ),
                _Dropdown<TextAlign>(
                  label: 'align',
                  value: options.textAlign,
                  items: const <TextAlign>[
                    TextAlign.start,
                    TextAlign.center,
                    TextAlign.end,
                  ],
                  nameOf: (TextAlign v) => v.name,
                  onChanged: (TextAlign v) =>
                      onChanged(options.copyWith(textAlign: v)),
                ),
                _Dropdown<TextDirection>(
                  label: 'direction',
                  value: options.textDirection,
                  items: TextDirection.values,
                  nameOf: (TextDirection v) => v.name,
                  onChanged: (TextDirection v) =>
                      onChanged(options.copyWith(textDirection: v)),
                ),
                _Dropdown<String>(
                  label: 'ease',
                  value: options.easeLabel,
                  items: easeChoices.keys.toList(),
                  nameOf: (String v) => v,
                  onChanged: (String v) =>
                      onChanged(options.copyWith(easeLabel: v)),
                ),
                _Toggle(
                  label: 'scale',
                  value: options.scale,
                  onChanged: (bool v) => onChanged(options.copyWith(scale: v)),
                ),
                _Toggle(
                  label: 'numbers',
                  value: options.numbers,
                  onChanged: (bool v) =>
                      onChanged(options.copyWith(numbers: v)),
                ),
                SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      Text('blur ${options.blur.toStringAsFixed(1)}'),
                      Expanded(
                        child: Slider(
                          value: options.blur,
                          max: 6,
                          divisions: 24,
                          onChanged: (double v) =>
                              onChanged(options.copyWith(blur: v)),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      Text('duration ${options.duration.inMilliseconds}ms'),
                      Expanded(
                        child: Slider(
                          value: options.duration.inMilliseconds.toDouble(),
                          min: 100,
                          max: 2000,
                          divisions: 38,
                          onChanged: (double v) => onChanged(
                            options.copyWith(
                              duration: Duration(milliseconds: v.round()),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Toggle(
                  label: 'bidi',
                  value: options.bidi,
                  onChanged: (bool v) => onChanged(options.copyWith(bidi: v)),
                ),
                _Toggle(
                  label: 'disabled',
                  value: options.disabled,
                  onChanged: (bool v) =>
                      onChanged(options.copyWith(disabled: v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reducedMotion
                  ? 'Reduced motion is on: respectReducedMotion defaults to '
                        'true, so values swap without motion.'
                  : 'Reduced motion is off. Turn on Reduce Motion in the OS '
                        'accessibility settings and values swap without '
                        'motion, unless respectReducedMotion is false.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.nameOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) nameOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$label '),
        DropdownButton<T>(
          value: value,
          onChanged: (T? v) {
            if (v != null) onChanged(v);
          },
          items: items
              .map(
                (T v) => DropdownMenuItem<T>(value: v, child: Text(nameOf(v))),
              )
              .toList(),
        ),
      ],
    );
  }
}
