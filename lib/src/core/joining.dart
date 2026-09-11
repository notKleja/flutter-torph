final RegExp _joining = RegExp(
  '[\u0600-\u06ff\u0700-\u074f\u0750-\u077f\u07c0-\u07ff\u0840-\u085f'
  '\u0860-\u08ff\ufb50-\ufdff\ufe70-\ufeff]',
);

/// Scripts whose letters change shape by position: Arabic, Syriac, N'Ko and
/// their extensions. A word in one is never cut into letters (DEV-008).
bool hasJoiningScript(String text) => _joining.hasMatch(text);

/// Restores upstream's per-letter splitting of joining-script words, for the
/// parity suites only.
bool debugSplitJoiningWords = false;

bool isAtomicWord(String word) =>
    !debugSplitJoiningWords && hasJoiningScript(word);
