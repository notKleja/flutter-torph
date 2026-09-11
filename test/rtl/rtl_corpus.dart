import 'dart:convert';
import 'dart:io';

/// One case from `oracle/fixtures/rtl/corpus.json`, or from the built-in
/// fallback list used when that shared corpus hasn't been generated yet.
class RtlCase {
  RtlCase({
    required this.id,
    required this.category,
    required this.text,
    required this.direction,
    required this.locale,
    this.morph,
    this.interrupt,
    this.storm,
  });

  factory RtlCase.fromJson(Map<String, dynamic> j) => RtlCase(
    id: j['id'] as String,
    category: (j['category'] as String?) ?? 'unknown',
    text: j['text'] as String,
    direction: (j['direction'] as String?) ?? 'rtl',
    locale: (j['locale'] as String?) ?? 'ar',
    morph: (j['morph'] as Map?)?.cast<String, dynamic>(),
    interrupt: (j['interrupt'] as Map?)?.cast<String, dynamic>(),
    storm: j['storm'] as List<dynamic>?,
  );

  final String id;
  final String category;
  final String text;
  final String direction; // 'rtl' | 'ltr'
  final String locale;

  final Map<String, dynamic>? morph;

  final Map<String, dynamic>? interrupt;

  final List<dynamic>? storm;
}

const String rtlCorpusPath = 'oracle/fixtures/rtl/corpus.json';

bool rtlCorpusIsFallback = false;

List<RtlCase> loadRtlCorpus() {
  final file = File(rtlCorpusPath);
  if (file.existsSync()) {
    try {
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final rawCases = decoded['cases'] as List;
      if (rawCases.isNotEmpty) {
        rtlCorpusIsFallback = false;
        return rawCases
            .map((c) => RtlCase.fromJson((c as Map).cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
  }
  rtlCorpusIsFallback = true;
  return _fallback;
}

final List<RtlCase> _fallback = [
  RtlCase(
    id: 'f01',
    category: 'digits',
    text: 'السعر 1234 ريال',
    direction: 'rtl',
    locale: 'ar',
    morph: {'to': 'السعر 1235 ريال'},
  ),
  RtlCase(
    id: 'f02',
    category: 'currency',
    text: 'السعر \$1,234.56 اليوم',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f03',
    category: 'count',
    text: 'لدي 123 تفاحة',
    direction: 'rtl',
    locale: 'ar',
    morph: {'to': 'لدي 124 تفاحة'},
  ),
  RtlCase(
    id: 'f04',
    category: 'time',
    text: 'الوقت 10:45 مساءً',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f05',
    category: 'digits-fa',
    text: 'قیمت 1234 تومان',
    direction: 'rtl',
    locale: 'fa',
    morph: {'to': 'قیمت 1235 تومان'},
  ),
  RtlCase(
    id: 'f06',
    category: 'arabic-indic-digits',
    text: 'السعر ١٢٣٤ ريال',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f07',
    category: 'extended-arabic-indic-digits',
    text: 'قیمت ۱۲۳۴ تومان',
    direction: 'rtl',
    locale: 'fa',
  ),
  RtlCase(
    id: 'f08',
    category: 'digits-he',
    text: 'מחיר 1234 ₪',
    direction: 'rtl',
    locale: 'he',
    morph: {'to': 'מחיר 1235 ₪'},
  ),
  RtlCase(
    id: 'f09',
    category: 'currency-he',
    text: 'מחיר \$1,234.56 היום',
    direction: 'rtl',
    locale: 'he',
  ),
  RtlCase(
    id: 'f10',
    category: 'mixed-latin',
    text: 'مرحبا ABC 123 DEF',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f11',
    category: 'mixed-latin',
    text: 'ABC مرحبا 123 عالم DEF',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f12',
    category: 'number-first',
    text: '123 مرحبا',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f13',
    category: 'number-last',
    text: 'مرحبا 123',
    direction: 'rtl',
    locale: 'ar',
    morph: {'to': 'مرحبا 999'},
    interrupt: {'to': 'مرحبا 456', 'then': 'مرحبا 789'},
  ),
  RtlCase(
    id: 'f14',
    category: 'parens',
    text: 'مرحبا (123)',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f15',
    category: 'sign-minus',
    text: 'مرحبا -123',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f16',
    category: 'sign-plus',
    text: 'مرحبا +123',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f17',
    category: 'currency-symbol',
    text: 'مرحبا \$123',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f18',
    category: 'percent',
    text: 'مرحبا 123%',
    direction: 'rtl',
    locale: 'ar',
    morph: {'to': 'مرحبا 99%'},
  ),
  RtlCase(
    id: 'f19',
    category: 'fraction',
    text: 'مرحبا 1/2',
    direction: 'rtl',
    locale: 'ar',
  ),
  RtlCase(
    id: 'f20',
    category: 'time',
    text: 'مرحبا 12:34',
    direction: 'rtl',
    locale: 'ar',
    storm: [
      'مرحبا 12:35',
      'مرحبا 12:36',
      'مرحبا 12:37',
      'مرحبا 12:38',
      'مرحبا 12:39',
      'مرحبا 12:40',
    ],
  ),
];
