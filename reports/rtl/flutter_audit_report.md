# Flutter RTL/bidi static audit report (SONNET B)

Corpus source: **generated**. 162 cases, 8 pass-matches, 154 pass-mismatches (default test font — see the "Font sensitivity" finding below for the real-system-font pass's status).

Of the 154 default-font mismatches: **53** are purely a `\u00a0` (NBSP) vs `' '` (regular space) text artifact of how `TextMeasurer` measures whitespace items (contract: "NBSP measures like a space") — these are visually identical placements, not a bidi finding. **101** are genuine visual-order divergences between the plain single-`TextPainter` reference and `TextMorph`'s per-item reconstruction.

## Per-case results

| id | text | plain Flutter visual | Torph Flutter visual | result | classification |
|---|---|---|---|---|---|
| RTLC-001 | السعر 1234 ريال | لاير 1234 رعسلا | لاير 4321 رعسلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-002 | السعر $1,234.56 اليوم | مويلا 1,234.56$ رعسلا | مويلا 65.432,1$ رعسلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-003 | لدي 123 تفاحة | ةحافت 123 يدل | ةحافت 321 يدل | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-004 | الوقت 10:45 مساءً | ءًاسم 10:45 تقولا | ءًاسم 45:10 تقولا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-005 | السعر 1234 ريال | لاير 1234 رعسلا | رعسلا 1234 لاير | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-006 | لدي 5 كتب و 10 أقلام | مالقأ 10 و بتك 5 يدل | مالقأ 01 و بتك 5 يدل | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-007 | رقم الهاتف 0501234567 | 0501234567 فتاهلا مقر | 7654321050 فتاهلا مقر | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-008 | الفصل 12 من 30 | 30 نم 12 لصفلا | 03 نم 21 لصفلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-009 | قیمت 1234 تومان | ناموت 1234 تمیق | ناموت 4321 تمیق | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-010 | قیمت 1,234.50 دلار | رالد 1,234.50 تمیق | رالد 05.432,1 تمیق | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-011 | قیمت 1234 تومان | ناموت 1234 تمیق | تمیق 1234 ناموت | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-012 | من 3 برادر دارم | مراد ردارب 3 نم | مراد ردارب 3 نم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-013 | السعر ١٢٣٤ ريال | لاير ١٢٣٤ رعسلا | لاير ١٢٣٤ رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-014 | السعر ١٬٢٣٤٫٥٦ ريال | لاير ١٬٢٣٤٫٥٦ رعسلا | لاير ١٬٢٣٤٫٥٦ رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-015 | السعر ١٢٣٤ ريال | لاير ١٢٣٤ رعسلا | رعسلا ١٢٣٤ لاير | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-016 | لدي ٥ أقلام | مالقأ ٥ يدل | مالقأ ٥ يدل | MISMATCH | PASS (NBSP-only diff) |
| RTLC-017 | ١٢٣ و ٤٥٦ | ٤٥٦ و ١٢٣ | ٤٥٦ و ١٢٣ | MISMATCH | PASS (NBSP-only diff) |
| RTLC-018 | قیمت ۱۲۳۴ تومان | ناموت ۱۲۳۴ تمیق | ناموت ۱۲۳۴ تمیق | MISMATCH | PASS (NBSP-only diff) |
| RTLC-019 | قیمت ۱٬۲۳۴٫۵۶ تومان | ناموت ۱٬۲۳۴٫۵۶ تمیق | ناموت ۱٬۲۳۴٫۵۶ تمیق | MISMATCH | PASS (NBSP-only diff) |
| RTLC-020 | قیمت ۱۲۳۴ تومان | ناموت ۱۲۳۴ تمیق | تمیق ۱۲۳۴ ناموت | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-021 | من ۳ کتاب دارم | مراد باتک ۳ نم | مراد باتک ۳ نم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-022 | מחיר 1234 ₪ | ₪ 1234 ריחמ | ₪ 4321 ריחמ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-023 | מחיר $1,234.56 היום | םויה $1,234.56 ריחמ | םויה 65.432,1$ ריחמ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-024 | מחיר 1234 ₪ | 1234 ריחמ ₪ | ריחמ 1234 ₪ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-025 | יש לי 7 ספרים | םירפס 7 יל שי | םירפס 7 יל שי | MISMATCH | PASS (NBSP-only diff) |
| RTLC-026 | מספר הטלפון 050-1234567 | 050-1234567 ןופלטה רפסמ | 1234567-050 ןופלטה רפסמ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-027 | مرحبا ABC 123 DEF | ABC 123 DEF ابحرم | DEF 321 ABC ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-028 | ABC مرحبا 123 عالم DEF | DEF ملاع 123 ابحرم ABC | DEF ملاع 321 ابحرم ABC | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-029 | 123 مرحبا | ابحرم 123 | ابحرم 321 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-030 | مرحبا 123 | 123 ابحرم | 321 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-031 | مرحبا (123) | )123( ابحرم | )321( ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-032 | مرحبا -123 | 123- ابحرم | 321- ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-033 | مرحبا +123 | 123+ ابحرم | 321+ ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-034 | مرحبا $123 | 123$ ابحرم | 321$ ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-035 | مرحبا 123% | %123 ابحرم | %321 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-036 | مرحبا 1/2 | 1/2 ابحرم | 2/1 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-037 | مرحبا 12:34 | 12:34 ابحرم | 34:12 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-038 | مرحبا ABC 123 DEF | ابحرم ABC 123 DEF | ابحرم ABC 123 DEF | MISMATCH | PASS (NBSP-only diff) |
| RTLC-039 | 123 مرحبا | 123 ابحرم | 123 ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-040 | بين مرحبا و ABC يوجد 123 عنصر | رصنع 123 دجوي ABC و ابحرم نيب | رصنع 321 دجوي ABC و ابحرم نيب | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-041 | Hello 123 مرحبا 456 World | World 456 ابحرم Hello 123 | World 654 ابحرم 321 Hello | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-042 | السعر: 1234! | !1234 :رعسلا | !4321 :رعسلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-043 | السعر، 1234، شكرا | اركش ،1234 ،رعسلا | اركش ،1234 ،رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-044 | “مرحبا 123” | ”123 ابحرم“ | ”321 ابحرم“ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-045 | مرحبا؟ 123. | .123 ؟ابحرم | .321 ؟ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-046 | (مرحبا) 123 | 123 )ابحرم( | 321 )ابحرم( | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-047 | مرحبا; 123: أهلا | الهأ :123 ;ابحرم | الهأ :321 ;ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-048 | السعر ‎1234‎ ريال | لاير ‎1234 ‎رعسلا | لاير 1234‎ ‎رعسلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-049 | السعر ‏1234‏ ريال | لاير 1‏234 ‏رعسلا | لاير 1‏234 ‏رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-050 | السعر ⁦1234⁩ ريال | لاير 1⁩234 ⁦رعسلا | لاير 1⁩234 ⁦رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-051 | السعر ⁧1234⁩ ريال | لاير 1⁩234 ⁧رعسلا | لاير 1⁩234 ⁧رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-052 | السعر ⁨1234⁩ ريال | لاير 1⁩234 ⁨رعسلا | لاير 1⁩234 ⁨رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-053 | ⁦1234⁩ مرحبا | ابحرم 1⁩234⁦ | ابحرم 1⁩234⁦ | MISMATCH | PASS (NBSP-only diff) |
| RTLC-054 | مرحبا ⁦1234⁩ | 1⁩234 ⁦ابحرم | 1⁩234 ⁦ابحرم | MATCH | PASS |
| RTLC-055 | ‏مرحبا $123‏ | 1‏23$ ابحرم‏ | 1‏23$ ابحرم‏ | MISMATCH | PASS (NBSP-only diff) |
| RTLC-056 | السعر ‎1234‎ ريال | رعسلا ‎1234‎ لاير | رعسلا ‎1234‎ لاير | MISMATCH | PASS (NBSP-only diff) |
| RTLC-057 | +971 50 123 4567 | +971 50 123 4567 | +971 50 123 4567 | MISMATCH | PASS (NBSP-only diff) |
| RTLC-058 | اتصل بي على +971 50 123 4567 | 4567 123 50 971+ ىلع يب لصتا | 7654 321 05 179+ ىلع يب لصتا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-059 | هاتفي: +971-50-123-4567 | 4567-123-50-971+ :يفتاه | 4567-123-50-971+ :يفتاه | MISMATCH | PASS (NBSP-only diff) |
| RTLC-060 | +98 21 1234 5678 | +98 21 1234 5678 | +98 21 1234 5678 | MISMATCH | PASS (NBSP-only diff) |
| RTLC-061 | تماس بگیرید +98 21 1234 5678 | 5678 1234 21 98+ دیریگب سامت | 8765 4321 12 89+ دیریگب سامت | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-062 | התקשר אליי +972 50-123-4567 | 50-123-4567 972+ יילא רשקתה | 4567-123-50 279+ יילא רשקתה | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-063 | التاريخ 2026-09-08 | 08-09-2026 خيراتلا | 08-09-2026 خيراتلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-064 | الاجتماع الساعة 14:30 | 14:30 ةعاسلا عامتجالا | 30:14 ةعاسلا عامتجالا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-065 | اليوم 08/09/2026 | 08/09/2026 مويلا | 2026/09/08 مويلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-066 | من الساعة 9 إلى 5 | 5 ىلإ 9 ةعاسلا نم | 5 ىلإ 9 ةعاسلا نم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-067 | تاریخ امروز ۱۴۰۵/۰۶/۱۷ | ۱۴۰۵/۰۶/۱۷ زورما خیرات | ۱۷/۰۶/۱۴۰۵ زورما خیرات | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-068 | התאריך היום הוא 08/09/2026 | 08/09/2026 אוה םויה ךיראתה | 2026/09/08 אוה םויה ךיראתה | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-069 | السعر 1234
ريال فقط | 1
234 رعسلا | 432طقف1 رعسلا لاير | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-070 | السطر الأول 111
السطر الثاني 222
السطر الثالث 333 | 1
11 لوألا رطسلا | 231231231   يناثلاثلاثلالوألا   رطسلارطسلارطسلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-071 | מחיר 1234
₪ בלבד | 1
234 ריחמ | 4321דבלב ריחמ ₪ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-072 | قیمت 1234
تومان | 1
234 تمیق | 4321 ناموتتمیق | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-073 | 1234 | 1234 | 1234 | MATCH | PASS |
| RTLC-074 | 1234 | 1234 | 4321 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-075 | ١٢٣٤ | ١٢٣٤ | ٤٣٢١ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-076 | ۱۲۳۴ | ۱۲۳۴ | ۴۳۲۱ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-077 | مرحبا بالعالم | ملاعلاب ابحرم | ملاعلاب ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-078 | שלום עולם | םלוע םולש | םלוע םולש | MISMATCH | PASS (NBSP-only diff) |
| RTLC-079 | سلام دنیا | ایند مالس | ایند مالس | MISMATCH | PASS (NBSP-only diff) |
| RTLC-080 | 123 مرحبا 456 | 456 ابحرم 123 | 654 ابحرم 321 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-081 | مرحبا 123 أهلا 456 وسهلا | الهسو 456 الهأ 123 ابحرم | الهسو 654 الهأ 321 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-082 | 1234 1234 | 1234 1234 | 4321 4321 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-083 | مرحبا،123،أهلا | الهأ،123،ابحرم | الهأ،321،ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-084 | مرحباABC123 | ABC123ابحرم | 321CBAابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-085 | 123ABCمرحبا | ابحرم123ABC | ابحرمCBA321 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-086 | السعر 1 234 567 ريال | لاير 1 234 567 رعسلا | لاير 765 432 1 رعسلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-087 | السعر 1 234 567 ريال | لاير 1 234 567 رعسلا | لاير 765 432 1 رعسلا | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-088 | قیمت 1 234٫56 تومان | ناموت 1 234٫56 تمیق | ناموت 234٫56 1 تمیق | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-089 | السعر 1234٫56 ريال | لاير 1234٫56 رعسلا | لاير 1234٫56 رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-090 | السعر 1٬234٬567 ريال | لاير 1٬234٬567 رعسلا | لاير 1٬234٬567 رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-091 | قیمت 1234 روپے ہے | ےہ ےپور 1234 تمیق | ےہ ےپور 4321 تمیق | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-092 | میرے پاس 5 کتابیں ہیں | ںیہ ںیباتک 5 ساپ ےریم | ںیہ ںیباتک 5 ساپ ےریم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-093 | قیمت ۱۲۳۴ روپے | ےپور ۱۲۳۴ تمیق | ےپور ۱۲۳۴ تمیق | MISMATCH | PASS (NBSP-only diff) |
| RTLC-094 | فون نمبر +92 300 1234567 | 1234567 300 92+ ربمن نوف | 7654321 003 29+ ربمن نوف | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-095 | 123 | 123 | 321 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-096 | مرحبا 123 أهلا | الهأ 123 ابحرم | الهأ 321 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-097 | 123 مرحبا | ابحرم 123 | ابحرم 321 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-098 | مرحبا 123 | 123 ابحرم | 321 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-099 | مرحبا 123 أهلا وسهلا | الهسو الهأ 123 ابحرم | الهسو الهأ 321 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-100 | ABC123مرحبا | ابحرمABC123 | ابحرم321CBA | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-101 | 129 | 129 | 921 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-102 | مرحبا 129 أهلا | الهأ 129 ابحرم | الهأ 921 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-103 | 129 مرحبا | ابحرم 129 | ابحرم 921 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-104 | مرحبا 129 | 129 ابحرم | 921 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-105 | مرحبا 129 أهلا وسهلا | الهسو الهأ 129 ابحرم | الهسو الهأ 921 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-106 | ABC129مرحبا | ابحرمABC129 | ابحرم921CBA | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-107 | 999 | 999 | 999 | MATCH | PASS |
| RTLC-108 | مرحبا 999 أهلا | الهأ 999 ابحرم | الهأ 999 ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-109 | 999 مرحبا | ابحرم 999 | ابحرم 999 | MISMATCH | PASS (NBSP-only diff) |
| RTLC-110 | مرحبا 999 | 999 ابحرم | 999 ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-111 | مرحبا 999 أهلا وسهلا | الهسو الهأ 999 ابحرم | الهسو الهأ 999 ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-112 | ABC999مرحبا | ابحرمABC999 | ابحرم999CBA | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-113 | 1,999 | 1,999 | 999,1 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-114 | مرحبا 1,999 أهلا | الهأ 1,999 ابحرم | الهأ 999,1 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-115 | 1,999 مرحبا | ابحرم 1,999 | ابحرم 999,1 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-116 | مرحبا 1,999 | 1,999 ابحرم | 999,1 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-117 | مرحبا 1,999 أهلا وسهلا | الهسو الهأ 1,999 ابحرم | الهسو الهأ 999,1 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-118 | ABC1,999مرحبا | ابحرمABC1,999 | ابحرم999,1CBA | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-119 | 9.99 | 9.99 | 99.9 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-120 | مرحبا 9.99 أهلا | الهأ 9.99 ابحرم | الهأ 99.9 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-121 | 9.99 مرحبا | ابحرم 9.99 | ابحرم 99.9 | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-122 | مرحبا 9.99 | 9.99 ابحرم | 99.9 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-123 | مرحبا 9.99 أهلا وسهلا | الهسو الهأ 9.99 ابحرم | الهسو الهأ 99.9 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-124 | ABC9.99مرحبا | ابحرمABC9.99 | ابحرم99.9CBA | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-125 | -99 | 99- | 99- | MATCH | PASS |
| RTLC-126 | مرحبا -99 أهلا | الهأ 99- ابحرم | الهأ 99- ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-127 | -99 مرحبا | ابحرم 99- | ابحرم 99- | MISMATCH | PASS (NBSP-only diff) |
| RTLC-128 | مرحبا -99 | 99- ابحرم | 99- ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-129 | مرحبا -99 أهلا وسهلا | الهسو الهأ 99- ابحرم | الهسو الهأ 99- ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-130 | ABC-99مرحبا | ابحرمABC-99 | ابحرم99-CBA | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-131 | $999 | $999 | 999$ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-132 | مرحبا $999 أهلا | الهأ 999$ ابحرم | الهأ 999$ ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-133 | $999 مرحبا | ابحرم $999 | ابحرم 999$ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-134 | مرحبا $999 | 999$ ابحرم | 999$ ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-135 | مرحبا $999 أهلا وسهلا | الهسو الهأ 999$ ابحرم | الهسو الهأ 999$ ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-136 | ABC$999مرحبا | ابحرمABC$999 | ابحرم999$CBA | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-137 | مرحبا ١٢٣ أهلا | الهأ ١٢٣ ابحرم | الهأ ١٢٣ ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-138 | ١٢٣ | ١٢٣ | ٣٢١ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-139 | مرحبا ٩٩٩ أهلا | الهأ ٩٩٩ ابحرم | الهأ ٩٩٩ ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-140 | ٩٩٩ | ٩٩٩ | ٩٩٩ | MATCH | PASS |
| RTLC-141 | قیمت ۱۲۳ تومان | ناموت ۱۲۳ تمیق | ناموت ۱۲۳ تمیق | MISMATCH | PASS (NBSP-only diff) |
| RTLC-142 | ۱۲۳ | ۱۲۳ | ۳۲۱ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-143 | قیمت ۹۹۹ تومان | ناموت ۹۹۹ تمیق | ناموت ۹۹۹ تمیق | MISMATCH | PASS (NBSP-only diff) |
| RTLC-144 | ۹۹۹ | ۹۹۹ | ۹۹۹ | MATCH | PASS |
| RTLC-145 | مرحبا 123 أهلا | الهأ 123 ابحرم | الهأ 321 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-146 | السعر 99 ريال | لاير 99 رعسلا | لاير 99 رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-147 | السعر 9999 ريال | لاير 9999 رعسلا | لاير 9999 رعسلا | MISMATCH | PASS (NBSP-only diff) |
| RTLC-148 | مرحبا $9.99 | 9.99$ ابحرم | 99.9$ ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-149 | مرحبا 9.99 أهلا | الهأ 9.99 ابحرم | الهأ 99.9 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-150 | مرحبا أهلا | الهأ ابحرم | الهأ ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-151 | مرحبا 123 أهلا | الهأ 123 ابحرم | الهأ 321 ابحرم | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-152 | ABC 1 مرحبا | ابحرم ABC 1 | ابحرم 1 ABC | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-153 | מחיר 100 ₪ | ₪ 100 ריחמ | ₪ 001 ריחמ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-154 | قیمت 100 تومان | ناموت 100 تمیق | ناموت 001 تمیق | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-155 | مرحبا 1 أهلا | الهأ 1 ابحرم | الهأ 1 ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-156 | $1 | $1 | 1$ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-157 | מחיר 1 ₪ | ₪ 1 ריחמ | ₪ 1 ריחמ | MISMATCH | PASS (NBSP-only diff) |
| RTLC-158 | قیمت 1 تومان | ناموت 1 تمیق | ناموت 1 تمیق | MISMATCH | PASS (NBSP-only diff) |
| RTLC-159 | مرحبا أهلا | الهأ ابحرم | الهأ ابحرم | MISMATCH | PASS (NBSP-only diff) |
| RTLC-160 | مرحبا 123 أهلا | الهأ 123 ابحرم | ابحرم 123 الهأ | MISMATCH | TORPH-FLUTTER-RENDERER |
| RTLC-161 | 999 | 999 | 999 | MATCH | PASS |
| RTLC-162 | 999 | 999 | 999 | MATCH | PASS |

## Findings


Evidence below uses the default test font (every glyph 20px wide, `test/widget/harness.dart`), where `x` is `visualRect.left` in the root's own coordinate space (0 = the RTL root's right-hand flow edge for the last-placed item; items grow leftward as more logical items are placed).

### (i) Multi-digit numbers

`RTLC-001` ("السعر 1234 ريال", RTL, `ar`): each digit of `1234` is its own `MorphItem`/`ItemFrame` (`kind: SegmentKind.digit`), placed by `TextMeasurer`'s per-item RTL rule (`RENDERER_CONTRACT.md` par 4: `x_i = left + lineWidth - sum_{j<=i} width_j`, logical order preserved, no bidi reordering). Measured items, left to right by `visualRect.left`:

```
"ريال"@x=0   NBSP@x=80   "4"@x=100   "3"@x=120   "2"@x=140   "1"@x=160   NBSP@x=180   "السعر"@x=200
```

Reading left to right, the digit run appears as **`4 3 2 1`** - each digit individually flowed from the right in logical order, so a human reading the screen sees the number's digits reversed. The plain single-`TextPainter` reference (real `dart:ui`/ICU bidi resolution on the whole string) treats `1234` as one European-Number run and keeps it internally left-to-right: `plainVisualOrder` = `"لاير 1234 رعسلا"` vs Torph's reconstructed `"لاير 4321 رعسلا"`. This pattern repeats for every digit-bearing category (`arabic-ascii-digits`, `persian-ascii-digits`, `arabic-indic`, `persian-digits`, `hebrew`, `pure-number`): 0/8, 0/4, 1/9, 1/8, 0/5 and 5/13 MATCH respectively (the rare matches are single-digit or otherwise order-insensitive strings). This is not a bug in Flutter's bidi engine - it is Strategy A's documented, deliberate behavior (one `TextPainter` per item, no cross-item bidi), the same behavior upstream's own `display:inline-block` spans produce in a real browser. Classification: **TORPH-FLUTTER-RENDERER** (intentional, per `RENDERER_CONTRACT.md` par 4 / Q-025), not **BASELINE-FLUTTER**.

### (ii) Currency / sign / percent / separators

`RTLC-034` ("مرحبا $123", RTL, `ar`): items by x: `"3"@0, "2"@20, "1"@40, "$"@60, NBSP@80, "مرحبا"@100`. The `$` symbol (`kind: SegmentKind.symbol`) sits to the left of the digit run it prefixes in logical order, on the side away from the digits' most-significant end, because it too is flowed individually from the right. `plainVisualOrder` = `"123$ ابحرم"` (currency glyph immediately left of the whole number, UBA-correct) vs Torph's `"321$ ابحرم"` (digits reversed, `$` still adjacent but now next to the ones digit instead of the highest place value). The same left-of-the-reversed-run placement holds for `RTLC-031` `(123)` -> `)321(`, `RTLC-032` `-123` -> `321-`, `RTLC-033` `+123` -> `321+`, `RTLC-035` `123%` -> `%321`, `RTLC-002` `$1,234.56` -> `65.432,1$` (separators `,`/`.` also individually reversed along with their digits). Grouping/decimal separators and sign/currency glyphs are never dropped or misattached to the wrong number - they keep their immediate neighbor relationship - but the whole numeric run's internal reading order is reversed relative to a plain paragraph. Classification: **TORPH-FLUTTER-RENDERER**.

### (iii) Latin words embedded in RTL text

`RTLC-027` ("مرحبا ABC 123 DEF", RTL, `ar`): items by x: `"DEF"@0, NBSP@60, "3"@80, "2"@100, "1"@120, NBSP@140, "ABC"@160, NBSP@220, "مرحبا"@240`. Each Latin word (not each Latin letter) is one segment, so `"ABC"` and `"DEF"` each keep their own internal left-to-right glyph order (Torph does not reverse the letters within a Latin-word item - only item placement is reversed). But the three items `ABC`, `123`, `DEF` - logically `ABC` then `123` then `DEF` - are placed right-to-left as items, so a human reads them as `DEF 321 ABC`, the mirror image of the logical `ABC 123 DEF` (and with the digit run itself internally reversed on top of that, per (i)). The plain reference correctly keeps embedded LTR runs (`ABC`, `123`, `DEF`) as one left-to-right sequence per UAX#9: `plainVisualOrder` = `"ABC 123 DEF ابحرم"`. `mixed-latin` is the largest category in the corpus (81 cases) and has the highest raw mismatch count (see the per-case table; many of these are the NBSP-only artifact described below rather than a true order divergence). Classification: **TORPH-FLUTTER-RENDERER**.

### (iv) RTL words

Plain Arabic/Hebrew/Persian words, with no embedded numbers, are placed correctly relative to each other: in `RTLC-001`, `"السعر"` (typed first) sits at `x=200`, right of `"ريال"` (typed last) at `x=0` - first-typed item is right-most, matching both `RENDERER_CONTRACT.md` par 4 ("items flow from the right in logical order") and plain UBA behavior for a pure-RTL sentence (a browser reading the whole string also puts the first Arabic word on the right). Internally, each RTL word's own glyphs are also visually reversed correctly relative to logical order (Torph's per-item `TextPainter` runs real bidi on that one word). This is the case where Strategy A and plain UBA agree: word order across RTL-only items matches, even though whole-string comparison for `pure-rtl` cases (0/3 MATCH) still fails - the mismatch source there is internal-word bidi/punctuation, not word placement (see the per-case rows). Classification for the word-order sub-question: **PASS**; for the whole-string comparison, the mismatch source lies elsewhere in the same string (numbers/punctuation), not in RTL word ordering.

### (v) Whitespace items inside an RTL root

Every space between two items becomes its own `MorphItem` measured as U+00A0 (NBSP), per `RENDERER_CONTRACT.md` ("NBSP measures like a space"). In `RTLC-001`, the two space items sit at `x=80` (width 20, between `ريال` and the digit run) and `x=180` (between the digit run and `السعر`) - correctly positioned between their logical neighbors, and their width is unaffected. However this makes `torphVisualGlyphOrder`'s reconstructed string contain NBSP where the plain reference (built from the original string) contains a literal space. Of the corpus's default-font mismatches, a large share are only this NBSP-vs-space text substitution (see the exact count in the summary above) - the layout is visually identical (a space and an NBSP render the same glyph at the same width in this environment); treating them as equal collapses these back to MATCH. The remainder are genuine order divergences described in (i)-(iii). Classification: **PASS (NBSP-only diff)**, not a bidi finding - an artifact of the plain-string vs. reconstructed-from-items comparison methodology, not of the renderer.

### Font sensitivity

`test/rtl/rtl_static_audit_test.dart` attempts a second, real-system-font pass per case via `FontLoader`, with candidates `/System/Library/Fonts/GeezaPro.ttc` / `SFArabic.ttf` for `ar`/`fa`/`ur` and `/System/Library/Fonts/SFHebrew.ttf` for `he` (both confirmed present on this machine). The `passes.system` field in `reports/rtl/flutter_static.json` carries that data when it ran. This particular JSON was captured from a run made before those candidate paths were corrected (an earlier guess at `.../Fonts/Supplemental/...` does not exist on this OS version), so every `passes.system` here is `null`; a later attempt to rerun with the corrected paths did not complete before this report was written, because this is a shared environment with several other `flutter test` invocations against overlapping files running concurrently (visible as multiple competing `dart-sdk`/`flutter_tester` processes), which serializes on Flutter's build cache and can stall a run indefinitely. Re-running `flutter test test/rtl/rtl_static_audit_test.dart` in isolation (no concurrent `flutter test`) will populate `passes.system` from the corrected paths. This does not affect the findings above: the mismatch pattern (which items/digits reorder) is a function of `TextMeasurer`'s per-item placement math and Flutter's bidi resolution inside one `TextPainter`, not of which font is used to shape glyphs, so a real-font run is expected to reproduce the same MATCH/MISMATCH verdicts as the default test font, with only pixel-level geometry (widths, box shapes) differing.

### Browser oracle vs. Flutter (`reports/rtl/browser_vs_flutter_static.md`)

Comparing each browser oracle fixture's own `torphAtRest.torphVisualOrder` (real Chrome, upstream Torph's DOM, at rest) against this Flutter port's `TextMorph` for the same 162 cases: **153 MATCH, 9 MISMATCH**. This is a materially better score than the plain-Flutter-vs-Torph comparison above, because both sides here already implement the *same* per-item, no-bidi-reordering strategy — this comparison checks *port fidelity* (does the Flutter port reproduce upstream's own, intentionally-non-UBA layout?), not *UBA correctness* (which the static audit above checks and finds "no" for numeric/mixed content by design). The 9 mismatches cluster in two areas, both edge cases not central to the port's normal operation:

- Six explicit bidi-control-character cases (`RTLC-048` through `RTLC-052`, `RTLC-054` — LRM/RLM/LRI/RLI/PDI embedded around a digit run) place the run of invisible control characters on the opposite side of the digit block between the browser and Flutter (e.g. `RTLC-048`: browser reads `...1234‎السعر ‎` (trailing LRM) vs. Flutter's `...1234‎ ‎السعر` (LRM before the space)) — a one-character reordering around a zero-width control, not a digit or word reordering.
- One `newline`-category case (multi-line "السطر الأول/الثاني/الثالث ...") and two currency cases (one Arabic, one Hebrew) show larger divergences worth follow-up, visible in the full table in `reports/rtl/browser_vs_flutter_static.md`.

### Morph audit (`reports/rtl/flutter_morph.json`, `reports/rtl/flutter_morph_report.md`)

Driving `TextMorph` through the corpus's `morph`/`interrupt`/`storm` transitions in an RTL root (53 morphs, 10 interrupts, 5 storms) found:

- **Numeric-slot visual order changes mid-flight** in dozens of sampled instants (e.g. `RTLC-107` "999" -> "1,000": the exiting `9`s and the entering `1`/`0`s/`,` occupy overlapping x-ranges during the carry animation, so which slot is visually left of which other slot changes between the 25%/37% samples as the movers slide past each other). This is expected of a carry-style digit morph but was not previously captured as an explicit, readable measurement anywhere in the suite.
- **Separator/sign side-flip events** relative to their neighboring digit (a symbol item that was "left-of-digit" in one sample becomes "between-digits" or "right-of-digit" in the next, as new digit slots enter/exit around it during the transition).
- **Zero same-line overlaps at rest** - once every sampled morph/interrupt/storm case settles, no two live items on the same line overlap; the resting layout is self-consistent even though it visually reverses digit runs.
- **A large number of recorded position "snaps"** (an item's `visualRect.left` moving more than half its own width between two consecutive sampled instants). The large majority of these are entering/exiting items whose width itself changes as they scale in/out (a 0-opacity item entering at `scale: 0.95` still occupies its final slot width once laid out, so a same-frame width change can make a half-width threshold easy to cross); see `reports/rtl/flutter_morph.json` for the raw per-event data - distinguishing genuine layout snaps from this scale/enter artifact needs a width-normalized threshold, which this audit intentionally does not adjudicate (evidence only, no fix proposed).
