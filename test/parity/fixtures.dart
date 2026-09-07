import 'dart:convert';
import 'dart:io';

import 'package:torph/src/core/segment.dart';

/// Oracle fixtures live at the package root; `flutter test` runs there.
dynamic loadFixture(String name) {
  final file = File('oracle/fixtures/$name.json');
  if (!file.existsSync()) {
    throw StateError('missing oracle fixture $name — run `npm run gen` in oracle/');
  }
  return jsonDecode(file.readAsStringSync());
}

/// Minted IDs (`\u0000n<counter>`) come from a process-global counter upstream
/// and here; both sides are compared after renaming them in order of first
/// appearance within one chain: `\u0000n#0`, `\u0000n#1`, ...
class MintNormalizer {
  final Map<String, String> _map = {};

  String call(String id) {
    if (!id.startsWith('\u0000n')) return id;
    return _map.putIfAbsent(id, () => '\u0000n#${_map.length}');
  }

  List<Map<String, Object?>> segments(List<Segment> segs) => segs
      .map((s) => {
            'id': call(s.id),
            'string': s.string,
            if (s.kind != null) 'kind': s.kind!.name,
          })
      .toList();
}

/// Fixture segments already carry normalised IDs.
List<Map<String, Object?>> fixtureSegments(List<dynamic> raw) => raw
    .map((s) => {
          'id': s['id'] as String,
          'string': s['string'] as String,
          if (s['kind'] != null) 'kind': s['kind'] as String,
        })
    .toList();

String show(String s) => jsonEncode(s);
