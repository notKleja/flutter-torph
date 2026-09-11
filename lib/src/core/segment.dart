/// Numeric segments slide instead of fading, and digits and symbols slide
/// opposite ways.
enum SegmentKind { digit, symbol }

/// One animated unit of a value. `id` is the only identity used for FLIP
/// tracking and reconciliation; see [IdAllocator].
class Segment {
  const Segment(this.id, this.string, {this.kind});

  /// Stable identity used for FLIP tracking and reconciliation.
  final String id;

  /// The text this segment renders.
  final String string;

  /// Absent for ordinary text.
  final SegmentKind? kind;

  Segment copyWith({String? id, String? string, SegmentKind? kind}) =>
      Segment(id ?? this.id, string ?? this.string, kind: kind ?? this.kind);

  @override
  bool operator ==(Object other) =>
      other is Segment &&
      other.id == id &&
      other.string == string &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, string, kind);

  @override
  String toString() =>
      'Segment(${_show(id)}, ${_show(string)}${kind == null ? '' : ', ${kind!.name}'})';

  static String _show(String s) => s
      .replaceAll('\u0000', r'\0')
      .replaceAll('\n', r'\n')
      .replaceAll(' ', '␣');
}

/// The stand-in a value of `""` renders as, so the line box survives exits.
const String emptyId = 'empty';

/// Zero-width space carried by the [emptyId] segment.
const String emptyString = '​';

const String nbsp = ' ';

/// A collision makes two segments fight over one element and one silently
/// loses its text, so uniqueness has to hold across the whole value, not per
/// line.
class IdAllocator {
  final Set<String> _used = <String>{};

  void reserve(String id) => _used.add(id);

  bool has(String id) => _used.contains(id);

  String take(String base) {
    if (!_used.contains(base)) {
      _used.add(base);
      return base;
    }
    var i = 1;
    while (_used.contains('$base~$i')) {
      i++;
    }
    final id = '$base~$i';
    _used.add(id);
    return id;
  }
}

class WordGroup {
  const WordGroup(this.word, this.segments);

  final String word;
  final List<Segment> segments;
}

/// Whitespace-delimited words — the unit the diff aligns on, and so a number's
/// bounds.
List<WordGroup> groupIntoWords(List<Segment> segments) {
  final groups = <WordGroup>[];
  var current = <Segment>[];

  void flush() {
    if (current.isEmpty) return;
    groups.add(WordGroup(current.map((s) => s.string).join(), current));
    current = <Segment>[];
  }

  for (final seg in segments) {
    if (seg.string == nbsp || seg.string == '\n') {
      flush();
    } else {
      current.add(seg);
    }
  }
  flush();
  return groups;
}
