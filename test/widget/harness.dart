import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

/// The default `flutter_test` font: every glyph is [fontSize] wide and one
/// [fontSize] tall, which makes every expectation an exact integer.
const double fontSize = 20;
const TextStyle testStyle = TextStyle(fontSize: fontSize, color: Color(0xFF000000));

/// One line of the test font.
const double lineHeight = fontSize;

/// A minimal host: no Material, so nothing else can move the geometry.
Widget host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  TextAlign? textAlign,
  bool disableAnimations = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: disableAnimations,
      textScaler: textScaler,
    ),
    child: Directionality(
      textDirection: direction,
      child: DefaultTextStyle(
        style: testStyle,
        textAlign: textAlign,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

RenderTextMorph renderOf(WidgetTester tester) =>
    tester.renderObject<RenderTextMorph>(find.byType(TextMorph));

TextMorphSnapshot snapshotOf(WidgetTester tester) => renderOf(tester).debugSnapshot();

TextMorphState stateOf(WidgetTester tester) =>
    tester.state<TextMorphState>(find.byType(TextMorph));

/// Consumes the ticker's zero-elapsed first tick, so a following
/// `pump(Duration)` lands on exactly that engine time.
Future<void> startClock(WidgetTester tester) => tester.pump();
