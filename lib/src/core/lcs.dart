import 'package:characters/characters.dart';

/// Longest common subsequence as paired indices. Walked forwards so ties go to
/// the earliest match — backwards, a repeated word flies across the block.
(List<int>, List<int>) lcsIndices(List<String> a, List<String> b) {
  final m = a.length;
  final n = b.length;
  // dp[i][j] = length of the LCS of a[i..] and b[j..]
  final dp = List<List<int>>.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

  for (var i = m - 1; i >= 0; i--) {
    for (var j = n - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  final ai = <int>[];
  final bi = <int>[];
  var i = 0;
  var j = 0;
  while (i < m && j < n) {
    if (a[i] == b[j]) {
      ai.add(i);
      bi.add(j);
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  return (ai, bi);
}

/// JavaScript `string.split("")`: one element per UTF-16 code unit.
List<String> codeUnits(String s) =>
    List<String>.generate(s.length, (i) => s[i], growable: false);

/// Extended grapheme clusters: what a reader sees as one character.
List<String> graphemeClusters(String s) => s.characters.toList();
