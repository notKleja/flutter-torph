import 'dart:convert';
import 'dart:io';
import '../lib/src/core/text_segmenter.dart';

void main(List<String> args) {
  final path = args.isNotEmpty && args.first != '-v' ? args.first : 'oracle/fixtures/segmenter.json';
  final data = jsonDecode(File(path).readAsStringSync()) as List;
  var wOk = 0, gOk = 0;
  final wBad = <int>[], gBad = <int>[];
  for (var i = 0; i < data.length; i++) {
    final e = data[i] as Map<String, dynamic>;
    final value = e['value'] as String;
    final expW = (e['word'] as List)
        .map((m) => TextSegment(m['index'] as int, m['segment'] as String,
            isWordLike: m['isWordLike'] as bool))
        .toList();
    final expG = (e['grapheme'] as List)
        .map((m) => TextSegment(m['index'] as int, m['segment'] as String))
        .toList();
    final gotW = segmentWords(value);
    final gotG = segmentGraphemes(value);
    if (_eq(expW, gotW)) { wOk++; } else { wBad.add(i); }
    if (_eq(expG, gotG)) { gOk++; } else { gBad.add(i); }
  }
  print('word  \$wOk/\${data.length}  bad=\${wBad.length > 40 ? wBad.sublist(0,40) : wBad}');
  print('graph \$gOk/\${data.length}  bad=\${gBad.length > 40 ? gBad.sublist(0,40) : gBad}');
  final show = args.contains('-v');
  if (show) {
    for (final i in wBad.take(30)) {
      final e = data[i] as Map<String, dynamic>;
      final value = e['value'] as String;
      print('--- [$i] ${jsonEncode(value)}');
      print('  exp: ${(e['word'] as List).map((m) => '${jsonEncode(m['segment'])}${m['isWordLike'] as bool ? '*' : ''}').join(' | ')}');
      print('  got: ${segmentWords(value).map((s) => '${jsonEncode(s.segment)}${s.isWordLike ? '*' : ''}').join(' | ')}');
    }
    for (final i in gBad.take(30)) {
      final e = data[i] as Map<String, dynamic>;
      final value = e['value'] as String;
      print('=G= [$i] ${jsonEncode(value)}');
      print('  exp: ${(e['grapheme'] as List).map((m) => jsonEncode(m['segment'])).join(' | ')}');
      print('  got: ${segmentGraphemes(value).map((s) => jsonEncode(s.segment)).join(' | ')}');
    }
  }
}

bool _eq(List<TextSegment> a, List<TextSegment> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
