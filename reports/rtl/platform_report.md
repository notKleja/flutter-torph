# RTL platform parity report

Static RTL corpus (`oracle/fixtures/rtl/corpus.json`, 162 cases) run on real platform text engines via `example/integration_test/rtl_platform_test.dart`. For each case: `torphVisualOrder` is the live Torph items sorted by `visualRect.left`; `plainVisualOrder` is the grapheme clusters of the raw string laid out with a `TextPainter` (same direction/locale/size), sorted by `getBoxesForSelection` box left. Full per-case data (including left-edge values rounded to 2 decimals) is in `reports/rtl/platform_macos.json` and `reports/rtl/platform_ios.json`.

## Platforms run

- **macOS desktop** (`flutter test integration_test/rtl_platform_test.dart -d macos`): 162/162 cases, all passed.
- **iOS Simulator** (iPhone 17 Pro, iOS 26.4, booted via `xcrun simctl boot`, run with `-d <udid>`): 162/162 cases, all passed.
- **Android**: skipped — no Android emulator/device was running (`flutter devices` listed only macOS and Chrome; `flutter emulators` was not invoked to start one, per the 15-minute budget for platforms beyond macOS/iOS).

## macOS: per-case visual order

| id | torphVisualOrder | plainVisualOrder |
|---|---|---|
| RTLC-001 | ريال 4321 السعر | لاير 1234 رعسلا |
| RTLC-002 | اليوم 65.432,1$ السعر | مويلا 1,234.56$ رعسلا |
| RTLC-003 | تفاحة 321 لدي | ةحافت 123 يدل |
| RTLC-004 | مساءً 45:10 الوقت | ءًاسم 10:45 تقولا |
| RTLC-005 | السعر 1234 ريال | لاير 1234 رعسلا |
| RTLC-006 | أقلام 01 و كتب 5 لدي | مالقأ 10 و بتك 5 يدل |
| RTLC-007 | 7654321050 الهاتف رقم | 0501234567 فتاهلا مقر |
| RTLC-008 | 03 من 21 الفصل | 30 نم 12 لصفلا |
| RTLC-009 | تومان 4321 قیمت | ناموت 1234 تمیق |
| RTLC-010 | دلار 05.432,1 قیمت | رالد 1,234.50 تمیق |
| RTLC-011 | قیمت 1234 تومان | ناموت 1234 تمیق |
| RTLC-012 | دارم برادر 3 من | مراد ردارب 3 نم |
| RTLC-013 | ريال ١٢٣٤ السعر | لاير ١٢٣٤ رعسلا |
| RTLC-014 | ريال ١٬٢٣٤٫٥٦ السعر | لاير ١٬٢٣٤٫٥٦ رعسلا |
| RTLC-015 | السعر ١٢٣٤ ريال | لاير ١٢٣٤ رعسلا |
| RTLC-016 | أقلام ٥ لدي | مالقأ ٥ يدل |
| RTLC-017 | ٤٥٦ و ١٢٣ | ٤٥٦ و ١٢٣ |
| RTLC-018 | تومان ۱۲۳۴ قیمت | ناموت ۱۲۳۴ تمیق |
| RTLC-019 | تومان ۱٬۲۳۴٫۵۶ قیمت | ناموت ۱٬۲۳۴٫۵۶ تمیق |
| RTLC-020 | قیمت ۱۲۳۴ تومان | ناموت ۱۲۳۴ تمیق |
| RTLC-021 | دارم کتاب ۳ من | مراد باتک ۳ نم |
| RTLC-022 | ₪ 4321 מחיר | ₪ 1234 ריחמ |
| RTLC-023 | היום 65.432,1$ מחיר | םויה $1,234.56 ריחמ |
| RTLC-024 | מחיר 1234 ₪ | 1234 ריחמ ₪ |
| RTLC-025 | ספרים 7 לי יש | םירפס 7 יל שי |
| RTLC-026 | 1234567-050 הטלפון מספר | 050-1234567 ןופלטה רפסמ |
| RTLC-027 | DEF 321 ABC مرحبا | ABC 123 DEF ابحرم |
| RTLC-028 | DEF عالم 321 مرحبا ABC | DEF ملاع 123 ابحرم ABC |
| RTLC-029 | مرحبا 321 | ابحرم 123 |
| RTLC-030 | 321 مرحبا | 123 ابحرم |
| RTLC-031 | )321( مرحبا | )123( ابحرم |
| RTLC-032 | 321- مرحبا | 123- ابحرم |
| RTLC-033 | 321+ مرحبا | 123+ ابحرم |
| RTLC-034 | 321$ مرحبا | 123$ ابحرم |
| RTLC-035 | %321 مرحبا | %123 ابحرم |
| RTLC-036 | 2/1 مرحبا | 1/2 ابحرم |
| RTLC-037 | 34:12 مرحبا | 12:34 ابحرم |
| RTLC-038 | مرحبا ABC 123 DEF | ابحرم ABC 123 DEF |
| RTLC-039 | 123 مرحبا | 123 ابحرم |
| RTLC-040 | عنصر 321 يوجد ABC و مرحبا بين | رصنع 123 دجوي ABC و ابحرم نيب |
| RTLC-041 | World 654 مرحبا 321 Hello | World 456 ابحرم Hello 123 |
| RTLC-042 | !4321 :السعر | !1234 :رعسلا |
| RTLC-043 | شكرا ،1234 ،السعر | اركش ،1234 ،رعسلا |
| RTLC-044 | ”321 مرحبا“ | ”123 ابحرم“ |
| RTLC-045 | .321 ؟مرحبا | .123 ؟ابحرم |
| RTLC-046 | 321 )مرحبا( | 123 )ابحرم( |
| RTLC-047 | أهلا :321 ;مرحبا | الهأ :123 ;ابحرم |
| RTLC-048 | ريال 1234‎ ‎السعر | لاير ‎1234 ‎رعسلا |
| RTLC-049 | ريال 1234‏ ‏السعر | لاير 1‏234 ‏رعسلا |
| RTLC-050 | ريال 1234⁩ ⁦السعر | لاير 1⁩234 ⁦رعسلا |
| RTLC-051 | ريال 1234⁩ ⁧السعر | لاير 1⁩234 ⁧رعسلا |
| RTLC-052 | ريال 1234⁩ ⁨السعر | لاير 1⁩234 ⁨رعسلا |
| RTLC-053 | مرحبا 1234⁩⁦ | ابحرم 1⁩234⁦ |
| RTLC-054 | 1234⁩ ⁦مرحبا | 1⁩234 ⁦ابحرم |
| RTLC-055 | 123‏$ مرحبا‏ | 1‏23$ ابحرم‏ |
| RTLC-056 | السعر ‎1234‎ ريال | رعسلا ‎1234‎ لاير |
| RTLC-057 | +971 50 123 4567 | +971 50 123 4567 |
| RTLC-058 | 7654 321 05 179+ على بي اتصل | 4567 123 50 971+ ىلع يب لصتا |
| RTLC-059 | 4567-123-50-971+ :هاتفي | 4567-123-50-971+ :يفتاه |
| RTLC-060 | +98 21 1234 5678 | +98 21 1234 5678 |
| RTLC-061 | 8765 4321 12 89+ بگیرید تماس | 5678 1234 21 98+ دیریگب سامت |
| RTLC-062 | 4567-123-50 279+ אליי התקשר | 50-123-4567 972+ יילא רשקתה |
| RTLC-063 | 08-09-2026 التاريخ | 08-09-2026 خيراتلا |
| RTLC-064 | 30:14 الساعة الاجتماع | 14:30 ةعاسلا عامتجالا |
| RTLC-065 | 2026/09/08 اليوم | 08/09/2026 مويلا |
| RTLC-066 | 5 إلى 9 الساعة من | 5 ىلإ 9 ةعاسلا نم |
| RTLC-067 | ۱۷/۰۶/۱۴۰۵ امروز تاریخ | ۱۴۰۵/۰۶/۱۷ زورما خیرات |
| RTLC-068 | 2026/09/08 הוא היום התאריך | 08/09/2026 אוה םויה ךיראתה |
| RTLC-069 | 432فقط1 السعر ريال | 1\n23ط4ق فر علسايلرا |
| RTLC-070 | 232312311  الثانيالثالث الأول   السطرالسطرالسطر | \n23231\n2311  يث لنلوااثثألللااا   رررطططسسسلللااا |
| RTLC-071 | 432בלבד1 מחיר ₪ | 1\n23ד4ב רליבח ₪מ |
| RTLC-072 | 4321 تومانقیمت | 1\n234 نتاممیوقت |
| RTLC-073 | 1234 | 1234 |
| RTLC-074 | 4321 | 1234 |
| RTLC-075 | ٤٣٢١ | ١٢٣٤ |
| RTLC-076 | ۴۳۲۱ | ۱۲۳۴ |
| RTLC-077 | بالعالم مرحبا | ملاعلاب ابحرم |
| RTLC-078 | עולם שלום | םלוע םולש |
| RTLC-079 | دنیا سلام | ایند مالس |
| RTLC-080 | 654 مرحبا 321 | 456 ابحرم 123 |
| RTLC-081 | وسهلا 654 أهلا 321 مرحبا | الهسو 456 الهأ 123 ابحرم |
| RTLC-082 | 4321 4321 | 1234 1234 |
| RTLC-083 | الهأ،321،ابحرم | الهأ،123،ابحرم |
| RTLC-084 | 321CBAابحرم | ABC123ابحرم |
| RTLC-085 | ابحرمCBA321 | ابحرم123ABC |
| RTLC-086 | ريال 765 432 1 السعر | لاير 1 234 567 رعسلا |
| RTLC-087 | ريال 765 432 1 السعر | لاير 1 234 567 رعسلا |
| RTLC-088 | تومان 234٫56 1 قیمت | ناموت 1 234٫56 تمیق |
| RTLC-089 | ريال 1234٫56 السعر | لاير 1234٫56 رعسلا |
| RTLC-090 | ريال 1٬234٬567 السعر | لاير 1٬234٬567 رعسلا |
| RTLC-091 | ہے روپے 4321 قیمت | ےہ ےپور 1234 تمیق |
| RTLC-092 | ہیں کتابیں 5 پاس میرے | ںیہ ںیباتک 5 ساپ ےریم |
| RTLC-093 | روپے ۱۲۳۴ قیمت | ےپور ۱۲۳۴ تمیق |
| RTLC-094 | 7654321 003 29+ نمبر فون | 1234567 300 92+ ربمن نوف |
| RTLC-095 | 321 | 123 |
| RTLC-096 | أهلا 321 مرحبا | الهأ 123 ابحرم |
| RTLC-097 | مرحبا 321 | ابحرم 123 |
| RTLC-098 | 321 مرحبا | 123 ابحرم |
| RTLC-099 | وسهلا أهلا 321 مرحبا | الهسو الهأ 123 ابحرم |
| RTLC-100 | ابحرم321CBA | ابحرمABC123 |
| RTLC-101 | 921 | 129 |
| RTLC-102 | أهلا 921 مرحبا | الهأ 129 ابحرم |
| RTLC-103 | مرحبا 921 | ابحرم 129 |
| RTLC-104 | 921 مرحبا | 129 ابحرم |
| RTLC-105 | وسهلا أهلا 921 مرحبا | الهسو الهأ 129 ابحرم |
| RTLC-106 | ابحرم921CBA | ابحرمABC129 |
| RTLC-107 | 999 | 999 |
| RTLC-108 | أهلا 999 مرحبا | الهأ 999 ابحرم |
| RTLC-109 | مرحبا 999 | ابحرم 999 |
| RTLC-110 | 999 مرحبا | 999 ابحرم |
| RTLC-111 | وسهلا أهلا 999 مرحبا | الهسو الهأ 999 ابحرم |
| RTLC-112 | ابحرم999CBA | ابحرمABC999 |
| RTLC-113 | 999,1 | 1,999 |
| RTLC-114 | أهلا 999,1 مرحبا | الهأ 1,999 ابحرم |
| RTLC-115 | مرحبا 999,1 | ابحرم 1,999 |
| RTLC-116 | 999,1 مرحبا | 1,999 ابحرم |
| RTLC-117 | وسهلا أهلا 999,1 مرحبا | الهسو الهأ 1,999 ابحرم |
| RTLC-118 | ابحرم999,1CBA | ابحرمABC1,999 |
| RTLC-119 | 99.9 | 9.99 |
| RTLC-120 | أهلا 99.9 مرحبا | الهأ 9.99 ابحرم |
| RTLC-121 | مرحبا 99.9 | ابحرم 9.99 |
| RTLC-122 | 99.9 مرحبا | 9.99 ابحرم |
| RTLC-123 | وسهلا أهلا 99.9 مرحبا | الهسو الهأ 9.99 ابحرم |
| RTLC-124 | ابحرم99.9CBA | ابحرمABC9.99 |
| RTLC-125 | 99- | 99- |
| RTLC-126 | أهلا 99- مرحبا | الهأ 99- ابحرم |
| RTLC-127 | مرحبا 99- | ابحرم 99- |
| RTLC-128 | 99- مرحبا | 99- ابحرم |
| RTLC-129 | وسهلا أهلا 99- مرحبا | الهسو الهأ 99- ابحرم |
| RTLC-130 | ابحرم99-CBA | ابحرمABC-99 |
| RTLC-131 | 999$ | $999 |
| RTLC-132 | أهلا 999$ مرحبا | الهأ 999$ ابحرم |
| RTLC-133 | مرحبا 999$ | ابحرم $999 |
| RTLC-134 | 999$ مرحبا | 999$ ابحرم |
| RTLC-135 | وسهلا أهلا 999$ مرحبا | الهسو الهأ 999$ ابحرم |
| RTLC-136 | ابحرم999$CBA | ابحرمABC$999 |
| RTLC-137 | أهلا ١٢٣ مرحبا | الهأ ١٢٣ ابحرم |
| RTLC-138 | ٣٢١ | ١٢٣ |
| RTLC-139 | أهلا ٩٩٩ مرحبا | الهأ ٩٩٩ ابحرم |
| RTLC-140 | ٩٩٩ | ٩٩٩ |
| RTLC-141 | تومان ۱۲۳ قیمت | ناموت ۱۲۳ تمیق |
| RTLC-142 | ۳۲۱ | ۱۲۳ |
| RTLC-143 | تومان ۹۹۹ قیمت | ناموت ۹۹۹ تمیق |
| RTLC-144 | ۹۹۹ | ۹۹۹ |
| RTLC-145 | أهلا 321 مرحبا | الهأ 123 ابحرم |
| RTLC-146 | ريال 99 السعر | لاير 99 رعسلا |
| RTLC-147 | ريال 9999 السعر | لاير 9999 رعسلا |
| RTLC-148 | 99.9$ مرحبا | 9.99$ ابحرم |
| RTLC-149 | أهلا 99.9 مرحبا | الهأ 9.99 ابحرم |
| RTLC-150 | أهلا مرحبا | الهأ ابحرم |
| RTLC-151 | أهلا 321 مرحبا | الهأ 123 ابحرم |
| RTLC-152 | مرحبا 1 ABC | ابحرم ABC 1 |
| RTLC-153 | ₪ 001 מחיר | ₪ 100 ריחמ |
| RTLC-154 | تومان 001 قیمت | ناموت 100 تمیق |
| RTLC-155 | أهلا 1 مرحبا | الهأ 1 ابحرم |
| RTLC-156 | 1$ | $1 |
| RTLC-157 | ₪ 1 מחיר | ₪ 1 ריחמ |
| RTLC-158 | تومان 1 قیمت | ناموت 1 تمیق |
| RTLC-159 | أهلا مرحبا | الهأ ابحرم |
| RTLC-160 | مرحبا 123 أهلا | الهأ 123 ابحرم |
| RTLC-161 | 999 | 999 |
| RTLC-162 | 999 | 999 |

## iOS: per-case visual order

| id | torphVisualOrder | plainVisualOrder |
|---|---|---|
| RTLC-001 | ريال 4321 السعر | لاير 1234 رعسلا |
| RTLC-002 | اليوم 65.432,1$ السعر | مويلا 1,234.56$ رعسلا |
| RTLC-003 | تفاحة 321 لدي | ةحافت 123 يدل |
| RTLC-004 | مساءً 45:10 الوقت | ءًاسم 10:45 تقولا |
| RTLC-005 | السعر 1234 ريال | لاير 1234 رعسلا |
| RTLC-006 | أقلام 01 و كتب 5 لدي | مالقأ 10 و بتك 5 يدل |
| RTLC-007 | 7654321050 الهاتف رقم | 0501234567 فتاهلا مقر |
| RTLC-008 | 03 من 21 الفصل | 30 نم 12 لصفلا |
| RTLC-009 | تومان 4321 قیمت | ناموت 1234 تمیق |
| RTLC-010 | دلار 05.432,1 قیمت | رالد 1,234.50 تمیق |
| RTLC-011 | قیمت 1234 تومان | ناموت 1234 تمیق |
| RTLC-012 | دارم برادر 3 من | مراد ردارب 3 نم |
| RTLC-013 | ريال ١٢٣٤ السعر | لاير ١٢٣٤ رعسلا |
| RTLC-014 | ريال ١٬٢٣٤٫٥٦ السعر | لاير ١٬٢٣٤٫٥٦ رعسلا |
| RTLC-015 | السعر ١٢٣٤ ريال | لاير ١٢٣٤ رعسلا |
| RTLC-016 | أقلام ٥ لدي | مالقأ ٥ يدل |
| RTLC-017 | ٤٥٦ و ١٢٣ | ٤٥٦ و ١٢٣ |
| RTLC-018 | تومان ۱۲۳۴ قیمت | ناموت ۱۲۳۴ تمیق |
| RTLC-019 | تومان ۱٬۲۳۴٫۵۶ قیمت | ناموت ۱٬۲۳۴٫۵۶ تمیق |
| RTLC-020 | قیمت ۱۲۳۴ تومان | ناموت ۱۲۳۴ تمیق |
| RTLC-021 | دارم کتاب ۳ من | مراد باتک ۳ نم |
| RTLC-022 | ₪ 4321 מחיר | ₪ 1234 ריחמ |
| RTLC-023 | היום 65.432,1$ מחיר | םויה $1,234.56 ריחמ |
| RTLC-024 | מחיר 1234 ₪ | 1234 ריחמ ₪ |
| RTLC-025 | ספרים 7 לי יש | םירפס 7 יל שי |
| RTLC-026 | 1234567-050 הטלפון מספר | 050-1234567 ןופלטה רפסמ |
| RTLC-027 | DEF 321 ABC مرحبا | ABC 123 DEF ابحرم |
| RTLC-028 | DEF عالم 321 مرحبا ABC | DEF ملاع 123 ابحرم ABC |
| RTLC-029 | مرحبا 321 | ابحرم 123 |
| RTLC-030 | 321 مرحبا | 123 ابحرم |
| RTLC-031 | )321( مرحبا | )123( ابحرم |
| RTLC-032 | 321- مرحبا | 123- ابحرم |
| RTLC-033 | 321+ مرحبا | 123+ ابحرم |
| RTLC-034 | 321$ مرحبا | 123$ ابحرم |
| RTLC-035 | %321 مرحبا | %123 ابحرم |
| RTLC-036 | 2/1 مرحبا | 1/2 ابحرم |
| RTLC-037 | 34:12 مرحبا | 12:34 ابحرم |
| RTLC-038 | مرحبا ABC 123 DEF | ابحرم ABC 123 DEF |
| RTLC-039 | 123 مرحبا | 123 ابحرم |
| RTLC-040 | عنصر 321 يوجد ABC و مرحبا بين | رصنع 123 دجوي ABC و ابحرم نيب |
| RTLC-041 | World 654 مرحبا 321 Hello | World 456 ابحرم Hello 123 |
| RTLC-042 | !4321 :السعر | !1234 :رعسلا |
| RTLC-043 | شكرا ،1234 ،السعر | اركش ،1234 ،رعسلا |
| RTLC-044 | ”321 مرحبا“ | ”123 ابحرم“ |
| RTLC-045 | .321 ؟مرحبا | .123 ؟ابحرم |
| RTLC-046 | 321 )مرحبا( | 123 )ابحرم( |
| RTLC-047 | أهلا :321 ;مرحبا | الهأ :123 ;ابحرم |
| RTLC-048 | ريال 1234‎ ‎السعر | لاير ‎1234 ‎رعسلا |
| RTLC-049 | ريال 1234‏ ‏السعر | لاير 1‏234 ‏رعسلا |
| RTLC-050 | ريال 1234⁩ ⁦السعر | لاير 1⁩234 ⁦رعسلا |
| RTLC-051 | ريال 1234⁩ ⁧السعر | لاير 1⁩234 ⁧رعسلا |
| RTLC-052 | ريال 1234⁩ ⁨السعر | لاير 1⁩234 ⁨رعسلا |
| RTLC-053 | مرحبا 1234⁩⁦ | ابحرم 1⁩234⁦ |
| RTLC-054 | 1234⁩ ⁦مرحبا | 1⁩234 ⁦ابحرم |
| RTLC-055 | 123‏$ مرحبا‏ | 1‏23$ ابحرم‏ |
| RTLC-056 | السعر ‎1234‎ ريال | رعسلا ‎1234‎ لاير |
| RTLC-057 | +971 50 123 4567 | +971 50 123 4567 |
| RTLC-058 | 7654 321 05 179+ على بي اتصل | 4567 123 50 971+ ىلع يب لصتا |
| RTLC-059 | 4567-123-50-971+ :هاتفي | 4567-123-50-971+ :يفتاه |
| RTLC-060 | +98 21 1234 5678 | +98 21 1234 5678 |
| RTLC-061 | 8765 4321 12 89+ بگیرید تماس | 5678 1234 21 98+ دیریگب سامت |
| RTLC-062 | 4567-123-50 279+ אליי התקשר | 50-123-4567 972+ יילא רשקתה |
| RTLC-063 | 08-09-2026 التاريخ | 08-09-2026 خيراتلا |
| RTLC-064 | 30:14 الساعة الاجتماع | 14:30 ةعاسلا عامتجالا |
| RTLC-065 | 2026/09/08 اليوم | 08/09/2026 مويلا |
| RTLC-066 | 5 إلى 9 الساعة من | 5 ىلإ 9 ةعاسلا نم |
| RTLC-067 | ۱۷/۰۶/۱۴۰۵ امروز تاریخ | ۱۴۰۵/۰۶/۱۷ زورما خیرات |
| RTLC-068 | 2026/09/08 הוא היום התאריך | 08/09/2026 אוה םויה ךיראתה |
| RTLC-069 | 432فقط1 السعر ريال | 1\n23ط4ق فر علسايلرا |
| RTLC-070 | 232312311  الثانيالثالث الأول   السطرالسطرالسطر | \n23231\n2311  يث لنلوااثثألللااا   رررطططسسسلللااا |
| RTLC-071 | 432בלבד1 מחיר ₪ | 1\n23ד4ב לרביח ₪מ |
| RTLC-072 | 4321 تومانقیمت | 1\n234 نتاممیوقت |
| RTLC-073 | 1234 | 1234 |
| RTLC-074 | 4321 | 1234 |
| RTLC-075 | ٤٣٢١ | ١٢٣٤ |
| RTLC-076 | ۴۳۲۱ | ۱۲۳۴ |
| RTLC-077 | بالعالم مرحبا | ملاعلاب ابحرم |
| RTLC-078 | עולם שלום | םלוע םולש |
| RTLC-079 | دنیا سلام | ایند مالس |
| RTLC-080 | 654 مرحبا 321 | 456 ابحرم 123 |
| RTLC-081 | وسهلا 654 أهلا 321 مرحبا | الهسو 456 الهأ 123 ابحرم |
| RTLC-082 | 4321 4321 | 1234 1234 |
| RTLC-083 | الهأ،321،ابحرم | الهأ،123،ابحرم |
| RTLC-084 | 321CBAابحرم | ABC123ابحرم |
| RTLC-085 | ابحرمCBA321 | ابحرم123ABC |
| RTLC-086 | ريال 765 432 1 السعر | لاير 1 234 567 رعسلا |
| RTLC-087 | ريال 765 432 1 السعر | لاير 1 234 567 رعسلا |
| RTLC-088 | تومان 234٫56 1 قیمت | ناموت 1 234٫56 تمیق |
| RTLC-089 | ريال 1234٫56 السعر | لاير 1234٫56 رعسلا |
| RTLC-090 | ريال 1٬234٬567 السعر | لاير 1٬234٬567 رعسلا |
| RTLC-091 | ہے روپے 4321 قیمت | ےہ ےپور 1234 تمیق |
| RTLC-092 | ہیں کتابیں 5 پاس میرے | ںیہ ںیباتک 5 ساپ ےریم |
| RTLC-093 | روپے ۱۲۳۴ قیمت | ےپور ۱۲۳۴ تمیق |
| RTLC-094 | 7654321 003 29+ نمبر فون | 1234567 300 92+ ربمن نوف |
| RTLC-095 | 321 | 123 |
| RTLC-096 | أهلا 321 مرحبا | الهأ 123 ابحرم |
| RTLC-097 | مرحبا 321 | ابحرم 123 |
| RTLC-098 | 321 مرحبا | 123 ابحرم |
| RTLC-099 | وسهلا أهلا 321 مرحبا | الهسو الهأ 123 ابحرم |
| RTLC-100 | ابحرم321CBA | ابحرمABC123 |
| RTLC-101 | 921 | 129 |
| RTLC-102 | أهلا 921 مرحبا | الهأ 129 ابحرم |
| RTLC-103 | مرحبا 921 | ابحرم 129 |
| RTLC-104 | 921 مرحبا | 129 ابحرم |
| RTLC-105 | وسهلا أهلا 921 مرحبا | الهسو الهأ 129 ابحرم |
| RTLC-106 | ابحرم921CBA | ابحرمABC129 |
| RTLC-107 | 999 | 999 |
| RTLC-108 | أهلا 999 مرحبا | الهأ 999 ابحرم |
| RTLC-109 | مرحبا 999 | ابحرم 999 |
| RTLC-110 | 999 مرحبا | 999 ابحرم |
| RTLC-111 | وسهلا أهلا 999 مرحبا | الهسو الهأ 999 ابحرم |
| RTLC-112 | ابحرم999CBA | ابحرمABC999 |
| RTLC-113 | 999,1 | 1,999 |
| RTLC-114 | أهلا 999,1 مرحبا | الهأ 1,999 ابحرم |
| RTLC-115 | مرحبا 999,1 | ابحرم 1,999 |
| RTLC-116 | 999,1 مرحبا | 1,999 ابحرم |
| RTLC-117 | وسهلا أهلا 999,1 مرحبا | الهسو الهأ 1,999 ابحرم |
| RTLC-118 | ابحرم999,1CBA | ابحرمABC1,999 |
| RTLC-119 | 99.9 | 9.99 |
| RTLC-120 | أهلا 99.9 مرحبا | الهأ 9.99 ابحرم |
| RTLC-121 | مرحبا 99.9 | ابحرم 9.99 |
| RTLC-122 | 99.9 مرحبا | 9.99 ابحرم |
| RTLC-123 | وسهلا أهلا 99.9 مرحبا | الهسو الهأ 9.99 ابحرم |
| RTLC-124 | ابحرم99.9CBA | ابحرمABC9.99 |
| RTLC-125 | 99- | 99- |
| RTLC-126 | أهلا 99- مرحبا | الهأ 99- ابحرم |
| RTLC-127 | مرحبا 99- | ابحرم 99- |
| RTLC-128 | 99- مرحبا | 99- ابحرم |
| RTLC-129 | وسهلا أهلا 99- مرحبا | الهسو الهأ 99- ابحرم |
| RTLC-130 | ابحرم99-CBA | ابحرمABC-99 |
| RTLC-131 | 999$ | $999 |
| RTLC-132 | أهلا 999$ مرحبا | الهأ 999$ ابحرم |
| RTLC-133 | مرحبا 999$ | ابحرم $999 |
| RTLC-134 | 999$ مرحبا | 999$ ابحرم |
| RTLC-135 | وسهلا أهلا 999$ مرحبا | الهسو الهأ 999$ ابحرم |
| RTLC-136 | ابحرم999$CBA | ابحرمABC$999 |
| RTLC-137 | أهلا ١٢٣ مرحبا | الهأ ١٢٣ ابحرم |
| RTLC-138 | ٣٢١ | ١٢٣ |
| RTLC-139 | أهلا ٩٩٩ مرحبا | الهأ ٩٩٩ ابحرم |
| RTLC-140 | ٩٩٩ | ٩٩٩ |
| RTLC-141 | تومان ۱۲۳ قیمت | ناموت ۱۲۳ تمیق |
| RTLC-142 | ۳۲۱ | ۱۲۳ |
| RTLC-143 | تومان ۹۹۹ قیمت | ناموت ۹۹۹ تمیق |
| RTLC-144 | ۹۹۹ | ۹۹۹ |
| RTLC-145 | أهلا 321 مرحبا | الهأ 123 ابحرم |
| RTLC-146 | ريال 99 السعر | لاير 99 رعسلا |
| RTLC-147 | ريال 9999 السعر | لاير 9999 رعسلا |
| RTLC-148 | 99.9$ مرحبا | 9.99$ ابحرم |
| RTLC-149 | أهلا 99.9 مرحبا | الهأ 9.99 ابحرم |
| RTLC-150 | أهلا مرحبا | الهأ ابحرم |
| RTLC-151 | أهلا 321 مرحبا | الهأ 123 ابحرم |
| RTLC-152 | مرحبا 1 ABC | ابحرم ABC 1 |
| RTLC-153 | ₪ 001 מחיר | ₪ 100 ריחמ |
| RTLC-154 | تومان 001 قیمت | ناموت 100 تمیق |
| RTLC-155 | أهلا 1 مرحبا | الهأ 1 ابحرم |
| RTLC-156 | 1$ | $1 |
| RTLC-157 | ₪ 1 מחיר | ₪ 1 ריחמ |
| RTLC-158 | تومان 1 قیمت | ناموت 1 تمیق |
| RTLC-159 | أهلا مرحبا | الهأ ابحرم |
| RTLC-160 | مرحبا 123 أهلا | الهأ 123 ابحرم |
| RTLC-161 | 999 | 999 |
| RTLC-162 | 999 | 999 |

## Diffs: macOS vs iOS

- Cases whose **torphVisualOrder** differs between macOS and iOS (ORDER differences, ignoring x): **0** (none).
- Cases whose **plainVisualOrder** differs between macOS and iOS (ORDER differences, ignoring x): **1** — RTLC-071
- Cases that are **geometry-only** (same torphVisualOrder, different visualRect.left values) between macOS and iOS: **8** — RTLC-023, RTLC-024, RTLC-025, RTLC-026, RTLC-062, RTLC-068, RTLC-071, RTLC-078

### RTLC-071 detail (the one plainVisualOrder platform difference)

- text: `מחיר 1234\n₪ בלבד`
- macOS plainVisualOrder: `1\n23ד4ב רליבח ₪מ`
- iOS plainVisualOrder: `1\n23ד4ב לרביח ₪מ`
- The two platforms' native Hebrew shaping/BiDi resolution puts the second line's graphemes in a different relative left-to-right order (`רליבח` vs `לרביח`) for the plain `TextPainter` paragraph. Torph's own `torphVisualOrder` for this case is identical on both platforms — the difference is confined to the plain-paragraph oracle, not to Torph's item layout.

### Geometry-only cases (same order, different x)

These 8 cases keep the same left-to-right item order on both platforms; only the measured `visualRect.left` values shift, consistent with the two platforms' system fonts (San Francisco variants) having slightly different glyph metrics for the scripts involved: RTLC-023, RTLC-024, RTLC-025, RTLC-026, RTLC-062, RTLC-068, RTLC-071, RTLC-078.

## Diffs vs host-font static run (`reports/rtl/flutter_static.json`)

- torphVisualOrder differences, macOS vs the flutter_test host font (order only): **2** — RTLC-070, RTLC-071
- torphVisualOrder differences, iOS vs the flutter_test host font (order only): **2** — RTLC-070, RTLC-071

Both platform mismatches against the host-font run are `RTLC-070` and `RTLC-071`, the two multi-line (`\n`-containing) cases in the corpus. The host-font run and the real-platform runs disagree because `torphVisualOrder` is computed by sorting every live item purely by `visualRect.left`, which is not a valid ordering across multiple lines — real fonts (proportional, variable glyph widths) versus the fixed-width flutter_test host font place line boundaries at different y/x combinations, changing how lines interleave when flattened onto one x-axis. This is a limitation of the single-axis sort used by this methodology for multi-line text, not evidence of an RTL ordering bug. macOS and iOS agree with each other on `torphVisualOrder` for both of these cases (see the macOS vs iOS diff above), so the divergence is real-font-vs-host-font only, not real-platform-vs-real-platform.

## Summary

- macOS vs iOS: **0** Torph ORDER differences, **1** plain-paragraph ORDER difference (RTLC-071, Hebrew line 2), **8** geometry-only differences (same order, different x).
- macOS/iOS vs host-font static baseline: **2** Torph ORDER differences each (RTLC-070, RTLC-071), both attributable to the multi-line sort-by-x methodology rather than to a real RTL/BiDi regression.
- Android was not exercised (no running emulator/device); see the note above.
