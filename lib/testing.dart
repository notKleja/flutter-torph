/// Inspection hooks for tests and tooling (render object, measurer, frames).
/// Not needed to use [TextMorph]; not covered by the compatibility promise.
library;

import 'src/widget/text_morph.dart' show TextMorph;

export 'src/debug/morph_snapshot.dart' show TextMorphSnapshot;
export 'src/motion/morph_engine.dart' show FrameState, ItemFrame, Lifecycle;
export 'src/rendering/render_text_morph.dart' show RenderTextMorph;
export 'src/rendering/text_measurer.dart' show TextMeasurer;
