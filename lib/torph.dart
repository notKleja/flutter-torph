/// Torph: text that morphs from one value to the next.
///
/// A 1:1 port of the JS library (see `spec/UPSTREAM.md` for the pinned commit).
/// [TextMorph] is the widget; the pure pieces below mirror upstream's exports.
library;

export 'src/core/diff.dart' show DiffOptions, DiffResult, diffSegments;
export 'src/core/number.dart'
    show NumberSegment, decimalSeparator, isNumericWord, segmentNumber;
export 'src/core/segment.dart' show Segment, SegmentKind;
export 'src/core/segmenter.dart' show segmentText;
export 'src/debug/morph_snapshot.dart' show TextMorphSnapshot;
export 'src/motion/morph_engine.dart' show FrameState, ItemFrame, Lifecycle;
export 'src/motion/spring.dart' show SpringParams, SpringResult, spring;
export 'src/rendering/render_text_morph.dart' show RenderTextMorph;
export 'src/rendering/text_measurer.dart' show TextMeasurer;
export 'src/widget/options.dart'
    show
        TextMorphOptions,
        defaultBlur,
        defaultDuration,
        defaultEase,
        defaultLocaleTag,
        defaultTextMorphOptions;
export 'src/widget/text_morph.dart' show TextMorph, TextMorphState;
