// Where characters moving becomes one thing swapped for another. Past this,
// nothing that survived is near enough to animate from, and the run smears.
const int groupMin = 6;

// Deeper than a character's 0.95, so the run reads as receding, not as a glyph
// settling.
const double groupScale = 0.8;

/// Maximal stretches of `members` adjacent in `all`. A run broken by a
/// survivor is no replacement — that survivor is right there to move relative
/// to.
List<List<T>> replacedRuns<T>(List<T> all, Set<T> members) {
  final runs = <List<T>>[];
  var run = <T>[];

  void flush() {
    if (run.length >= groupMin) runs.add(run);
    run = <T>[];
  }

  for (final element in all) {
    if (members.contains(element)) {
      run.add(element);
    } else {
      flush();
    }
  }
  flush();
  return runs;
}
