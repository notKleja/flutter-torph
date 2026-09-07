# Segmenter known gaps

`lib/src/core/text_segmenter.dart` ports ICU 78's `word.txt` **rule** engine and
`package:characters`' grapheme clusters. ICU runs a second, dictionary-driven
pass over runs of Han, Hiragana, Katakana, Hangul, Thai, Lao, Khmer and Myanmar:
the rules deliberately chain such a run into one lump (`$KanaKanji $KanaKanji`,
and `$ComplexContext` folded into `$ALetterPlus`) and the dictionary then cuts it
into words. That dictionary (ICU's `cjdict.dict`, `thaidict.dict`, ...) is not
reproduced here, so a run in one of those scripts comes out as a single segment.

Against `oracle/fixtures/segmenter.json` (352 inputs, Node 26 / ICU 78.3):

- grapheme: 352 / 352 exact.
- word: 348 / 352 exact. The 4 below are the complete list of failures, and all
  4 are dictionary cuts inside a single script run. They are the test's
  allowlist.

## Allowlisted fixture entries

### 1. `你好世界`

- expected: `你好`\*, `世界`\*
- actual: `你好世界`\*

One Han run. The rule engine has no reason to break inside it; ICU's Chinese
dictionary knows `你好` and `世界`.

### 2. `สวัสดี ชาวโลก`

- expected: `สวัสดี`\*, `" "`, `ชาว`\*, `โลก`\*
- actual: `สวัสดี`\*, `" "`, `ชาวโลก`\*

Thai is `LineBreak=SA`, which `word.txt` folds into `$ALetterPlus`, so each run
chains as one word and ICU's Thai dictionary splits `ชาวโลก` into `ชาว` + `โลก`.
`สวัสดี` happens to be one dictionary word, which is why it already matches.

### 3. `日本語テキスト 中文文本 한국어 텍스트`

- expected: `日本語`\*, `テキスト`\*, `" "`, `中文`\*, `文本`\*, `" "`, `한국어`\*,
  `" "`, `텍스트`\*
- actual: `日本語テキスト`\*, `" "`, `中文文本`\*, `" "`, `한국어`\*, `" "`,
  `텍스트`\*

Two dictionary effects: `$KanaKanji $KanaKanji` chains Han and Katakana together
across the script change (`日本語` + `テキスト`), and `中文文本` is two dictionary
words with no script change at all. The two Hangul runs match, because
`$HangulSyllable $HangulSyllable` chains them and no dictionary cut applies.

### 4. `ひらがな カタカナ 漢字`

- expected: `ひ`\*, `ら`\*, `が`\*, `な`\*, `" "`, `カタカナ`\*, `" "`, `漢字`\*
- actual: `ひらがな`\*, `" "`, `カタカナ`\*, `" "`, `漢字`\*

`ひらがな` is not in ICU's CJ dictionary, and the dictionary breaker falls back to
one segment per code point for the unmatched run. `カタカナ` and `漢字` are
dictionary words, so they already match.

Nothing outside dictionary scripts is allowlisted. A cross-check against 83k
additional strings generated straight from Node 26 (`Intl.Segmenter`, ICU 78.3),
built from ~130 representative code points across every Word_Break class plus
random 2-11 code point combinations, produced zero word-boundary mismatches
except for strings containing Han, Hiragana, Katakana, Thai, Khmer or Lao
characters.

## Grapheme: Unicode data version

`package:characters` 1.4.1 is generated from Unicode 16.0.0, ICU 78 from Unicode
17.0.0. Unicode 17 grew `Indic_Conjunct_Break=Consonant` from 26 to 76 ranges
(Javanese, among others), so GB9c joins a conjunct that `package:characters`
splits when a linker sits between consonants of the newly covered scripts, e.g.
`"ꦗ्ꦗ्"` (Javanese JA + Devanagari virama) is one cluster in
ICU 78 and two in `package:characters`. No fixture entry is affected, and neither
is any single-script text in a script Unicode 16 already covered (Devanagari,
Bengali, Gujarati, Oriya, Telugu, Malayalam), which is why `हिन्दी` matches.

## ICU / V8 deviations from stock UAX #29 that the port reproduces

- `$ALetterPlus` drops Han, Hiragana, Katakana and U+AC00..U+D7A3 out of
  `ALetter` and pulls `LineBreak=SA` in, so Thai/Lao/Khmer/Myanmar runs chain as
  words and CJK is left to the extra `$KanaKanji`/`$HangulSyllable` rules.
- `$Extend` is `Word_Break=Extend` minus `Script=Han`.
- `$HangulSyllable $HangulSyllable` and `$KanaKanji $KanaKanji` carry no
  `$ExFm*`, so unlike every other rule they need literal adjacency: ICU breaks
  `"가́각"` and `"一́一"` while joining
  `"カ́カ"` through rule 13.
- `isWordLike` is ICU's rule status, taken from the *last* rule that matched,
  not from "the segment contains a letter". Consequences the fixture and the
  probe both confirm:
  - `"x‍\u{1F600}"` (letter, ZWJ, emoji) is one segment and **not**
    word-like: the last match is `$ZWJ $Extended_Pict`, which has no status.
  - `"__"` and `"_́_"` are word-like (rule 13a `{200}`), a lone `"_"` is
    not, and `"__́"` is not either, because `$ExtendNumLet` has no
    single-character status rule with a trailing `$ExFm*`; the same applies to
    `$HangulSyllable {200}` (`"가"` word-like, `"가́"` not) and to
    rule 7a (`"א'"` word-like, `"א'́"` not).
  - A letter, number, kana or ideograph keeps its status through attached
    Extend/Format/ZWJ, so `"1️⃣"` is word-like while `"#️⃣"`
    is not.
- Regional indicators pair up (`^$Regional_Indicator $ExFm*
  $Regional_Indicator`) and a pair is never word-like.
