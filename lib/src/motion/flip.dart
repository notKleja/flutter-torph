/// Layout offsets of live items keyed by ID, measured with the current
/// translate subtracted (upstream `measure`).
typedef Measures = Map<String, ({double x, double y})>;

({double dx, double dy}) computeDelta(
  Measures prev,
  Measures current,
  String key,
) {
  final p = prev[key];
  final c = current[key];
  if (p == null || c == null) return (dx: 0, dy: 0);
  return (dx: p.x - c.x, dy: p.y - c.y);
}

enum AnchorDirection { backwardFirst, forwardFirst }

/// Nearest persisting neighbour by ID, searching backward first, then forward.
String? findNearestAnchor(
  int targetIndex,
  List<String> ids,
  Set<String> persistentIds, [
  AnchorDirection direction = AnchorDirection.backwardFirst,
]) {
  String? backward() {
    for (var j = targetIndex - 1; j >= 0; j--) {
      if (persistentIds.contains(ids[j])) return ids[j];
    }
    return null;
  }

  String? forward() {
    for (var j = targetIndex + 1; j < ids.length; j++) {
      if (persistentIds.contains(ids[j])) return ids[j];
    }
    return null;
  }

  return direction == AnchorDirection.backwardFirst
      ? (backward() ?? forward())
      : (forward() ?? backward());
}

/// For each exiting old child (by index), the nearest old neighbour that
/// persists into the new value, forward first.
Map<int, String?> resolveExitingAnchors(
  List<String> oldIds,
  Set<int> exiting,
  Set<String> newIds,
) {
  final persistentOldIds = <String>{
    for (var i = 0; i < oldIds.length; i++)
      if (newIds.contains(oldIds[i]) && !exiting.contains(i)) oldIds[i],
  };

  final anchors = <int, String?>{};
  for (var i = 0; i < oldIds.length; i++) {
    if (!exiting.contains(i)) continue;
    anchors[i] = findNearestAnchor(
      i,
      oldIds,
      persistentOldIds,
      AnchorDirection.forwardFirst,
    );
  }
  return anchors;
}
