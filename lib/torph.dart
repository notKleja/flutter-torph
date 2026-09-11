/// Torph: text that morphs from one value to the next. [TextMorph] is the
/// widget; inspection hooks live in `package:torph/testing.dart`.
library;

export 'src/core/diff.dart' show DiffOptions, DiffResult, diffSegments;
export 'src/core/number.dart'
    show NumberSegment, decimalSeparator, isNumericWord, segmentNumber;
export 'src/core/segment.dart' show Segment, SegmentKind;
export 'src/core/segmenter.dart' show segmentText;
export 'src/motion/spring.dart' show SpringParams, SpringResult, spring;
export 'src/widget/options.dart'
    show defaultBlur, defaultDuration, defaultEase, defaultLocaleTag;
export 'src/widget/text_morph.dart' show TextMorph, TextMorphState;
