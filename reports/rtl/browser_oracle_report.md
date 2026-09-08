# Browser RTL Oracle Report

Comparison of plain-browser UBA (Unicode Bidi Algorithm) grapheme layout against upstream Torph's own `[torph-item]` DOM ordering, at rest, for every corpus case. `plainVisualOrder` and `torphVisualGlyphOrder` both read left → right in viewport (screen) coordinates.

Font: `Arial, "Helvetica Neue", system-ui, sans-serif`, size 20px.

| id | text | plainVisualOrder | torphVisualGlyphOrder | result | note |
|---|---|---|---|---|---|
| RTLC-001 | السعر 1234 ريال | لاير 1234 رعسلا | لاير 4321 رعسلا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-002 | السعر $1,234.56 اليوم | مويلا 1,234.56$ رعسلا | مويلا 65.432,1$ رعسلا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-003 | لدي 123 تفاحة | ةحافت 123 يدل | ةحافت 321 يدل | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-004 | الوقت 10:45 مساءً | ءًاسم 10:45 تقولا | ءًاسم 45:10 تقولا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-005 | السعر 1234 ريال | لاير 1234 رعسلا | رعسلا 1234 لاير | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-006 | لدي 5 كتب و 10 أقلام | مالقأ 10 و بتك 5 يدل | مالقأ 01 و بتك 5 يدل | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-007 | رقم الهاتف 0501234567 | 0501234567 فتاهلا مقر | 7654321050 فتاهلا مقر | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-008 | الفصل 12 من 30 | 30 نم 12 لصفلا | 03 نم 21 لصفلا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-009 | قیمت 1234 تومان | ناموت 1234 تمیق | ناموت 4321 تمیق | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-010 | قیمت 1,234.50 دلار | رالد 1,234.50 تمیق | رالد 05.432,1 تمیق | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-011 | قیمت 1234 تومان | ناموت 1234 تمیق | تمیق 1234 ناموت | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-012 | من 3 برادر دارم | مراد ردارب 3 نم | مراد ردارب 3 نم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-013 | السعر ١٢٣٤ ريال | لاير ١٢٣٤ رعسلا | لاير ١٢٣٤ رعسلا | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-014 | السعر ١٬٢٣٤٫٥٦ ريال | لاير ١٬٢٣٤٫٥٦ رعسلا | لاير ١٬٢٣٤٫٥٦ رعسلا | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-015 | السعر ١٢٣٤ ريال | لاير ١٢٣٤ رعسلا | رعسلا ١٢٣٤ لاير | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-016 | لدي ٥ أقلام | مالقأ ٥ يدل | مالقأ ٥ يدل | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-017 | ١٢٣ و ٤٥٦ | ٤٥٦ و ١٢٣ | ٤٥٦ و ١٢٣ | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-018 | قیمت ۱۲۳۴ تومان | ناموت ۱۲۳۴ تمیق | ناموت ۱۲۳۴ تمیق | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-019 | قیمت ۱٬۲۳۴٫۵۶ تومان | ناموت ۱٬۲۳۴٫۵۶ تمیق | ناموت ۱٬۲۳۴٫۵۶ تمیق | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-020 | قیمت ۱۲۳۴ تومان | ناموت ۱۲۳۴ تمیق | تمیق ۱۲۳۴ ناموت | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-021 | من ۳ کتاب دارم | مراد باتک ۳ نم | مراد باتک ۳ نم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-022 | מחיר 1234 ₪ | ₪ 1234 ריחמ | ₪ 4321 ריחמ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-023 | מחיר $1,234.56 היום | םויה $1,234.56 ריחמ | םויה 65.432,1$ ריחמ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-024 | מחיר 1234 ₪ | 1234 ריחמ ₪ | ריחמ 1234 ₪ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-025 | יש לי 7 ספרים | םירפס 7 יל שי | םירפס 7 יל שי | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-026 | מספר הטלפון 050-1234567 | 050-1234567 ןופלטה רפסמ | 1234567-050 ןופלטה רפסמ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-027 | مرحبا ABC 123 DEF | ABC 123 DEF ابحرم | DEF 321 ABC ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-028 | ABC مرحبا 123 عالم DEF | DEF ملاع 123 ابحرم ABC | DEF ملاع 321 ابحرم ABC | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-029 | 123 مرحبا | ابحرم 123 | ابحرم 321 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-030 | مرحبا 123 | 123 ابحرم | 321 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-031 | مرحبا (123) | )123( ابحرم | )321( ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-032 | مرحبا -123 | 123- ابحرم | 321- ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-033 | مرحبا +123 | 123+ ابحرم | 321+ ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-034 | مرحبا $123 | 123$ ابحرم | 321$ ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-035 | مرحبا 123% | %123 ابحرم | %321 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-036 | مرحبا 1/2 | 1/2 ابحرم | 2/1 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-037 | مرحبا 12:34 | 12:34 ابحرم | 34:12 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-038 | مرحبا ABC 123 DEF | ابحرم ABC 123 DEF | ابحرم ABC 123 DEF | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-039 | 123 مرحبا | 123 ابحرم | 123 ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-040 | بين مرحبا و ABC يوجد 123 عنصر | رصنع 123 دجوي ABC و ابحرم نيب | رصنع 321 دجوي ABC و ابحرم نيب | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-041 | Hello 123 مرحبا 456 World | World 456 ابحرم Hello 123 | World 654 ابحرم 321 Hello | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-042 | السعر: 1234! | !1234 :رعسلا | !4321 :رعسلا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-043 | السعر، 1234، شكرا | اركش ،1234 ،رعسلا | اركش ،1234 ،رعسلا | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-044 | “مرحبا 123” | ”123 ابحرم“ | ”321 ابحرم“ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-045 | مرحبا؟ 123. | .123 ؟ابحرم | .321 ؟ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-046 | (مرحبا) 123 | 123 )ابحرم( | 321 )ابحرم( | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-047 | مرحبا; 123: أهلا | الهأ :123 ;ابحرم | الهأ :321 ;ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-048 | السعر ‎1234‎ ريال | لاير ‎1234‎ رعسلا | لاير 1234‎رعسلا ‎ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-049 | السعر ‏1234‏ ريال | لاير ‏1234 ‏رعسلا | لاير 1‏234رعسلا ‏ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-050 | السعر ⁦1234⁩ ريال | لاير ⁩1234 ⁦رعسلا | لاير 1⁩234رعسلا ⁦ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-051 | السعر ⁧1234⁩ ريال | لاير ⁩1234 ⁧رعسلا | لاير 1⁩234رعسلا ⁧ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-052 | السعر ⁨1234⁩ ريال | لاير ⁩1234 ⁨رعسلا | لاير 1⁩234رعسلا ⁨ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-053 | ⁦1234⁩ مرحبا | ابحرم 1⁩234⁦ | ابحرم 1⁩234⁦ | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-054 | مرحبا ⁦1234⁩ | 1⁩234 ⁦ابحرم | 1⁩234ابحرم ⁦ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-055 | ‏مرحبا $123‏ | 1‏23$ ابحرم‏ | 1‏23$ ابحرم‏ | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-056 | السعر ‎1234‎ ريال | رعسلا ‎1234‎ لاير | رعسلا ‎1234‎ لاير | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-057 | +971 50 123 4567 | +971 50 123 4567 | +971 50 123 4567 | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-058 | اتصل بي على +971 50 123 4567 | 4567 123 50 971+ ىلع يب لصتا | 7654 321 05 179+ ىلع يب لصتا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-059 | هاتفي: +971-50-123-4567 | 4567-123-50-971+ :يفتاه | 4567-123-50-971+ :يفتاه | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-060 | +98 21 1234 5678 | +98 21 1234 5678 | +98 21 1234 5678 | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-061 | تماس بگیرید +98 21 1234 5678 | 5678 1234 21 98+ دیریگب سامت | 8765 4321 12 89+ دیریگب سامت | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-062 | התקשר אליי +972 50-123-4567 | 50-123-4567 972+ יילא רשקתה | 4567-123-50 279+ יילא רשקתה | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-063 | التاريخ 2026-09-08 | 08-09-2026 خيراتلا | 08-09-2026 خيراتلا | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-064 | الاجتماع الساعة 14:30 | 14:30 ةعاسلا عامتجالا | 30:14 ةعاسلا عامتجالا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-065 | اليوم 08/09/2026 | 08/09/2026 مويلا | 2026/09/08 مويلا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-066 | من الساعة 9 إلى 5 | 5 ىلإ 9 ةعاسلا نم | 5 ىلإ 9 ةعاسلا نم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-067 | تاریخ امروز ۱۴۰۵/۰۶/۱۷ | ۱۴۰۵/۰۶/۱۷ زورما خیرات | ۱۷/۰۶/۱۴۰۵ زورما خیرات | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-068 | התאריך היום הוא 08/09/2026 | 08/09/2026 אוה םויה ךיראתה | 2026/09/08 אוה םויה ךיראתה | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-069 | السعر 1234\nريال فقط | طقف لاير\n1234 رعسلا | 4321طقف رعسلا لاير | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-070 | السطر الأول 111\nالسطر الثاني 222\nالسطر الثالث 333 | 333 ثلاثلا رطسلا\n222 يناثلا رطسلا\n111 لوألا رطسلا | 321321321   ثلاثلايناثلالوألا   رطسلارطسلارطسلا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-071 | מחיר 1234\n₪ בלבד | דבלב ₪\n1234 ריחמ | 432דבלב1 ריחמ ₪ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-072 | قیمت 1234\nتومان | ناموت\n1234 تمیق | 4321 ناموتتمیق | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-073 | 1234 | 1234 | 1234 | MATCH |  |
| RTLC-074 | 1234 | 1234 | 4321 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-075 | ١٢٣٤ | ١٢٣٤ | ٤٣٢١ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-076 | ۱۲۳۴ | ۱۲۳۴ | ۴۳۲۱ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-077 | مرحبا بالعالم | ملاعلاب ابحرم | ملاعلاب ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-078 | שלום עולם | םלוע םולש | םלוע םולש | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-079 | سلام دنیا | ایند مالس | ایند مالس | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-080 | 123 مرحبا 456 | 456 ابحرم 123 | 654 ابحرم 321 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-081 | مرحبا 123 أهلا 456 وسهلا | الهسو 456 الهأ 123 ابحرم | الهسو 654 الهأ 321 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-082 | 1234 1234 | 1234 1234 | 4321 4321 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-083 | مرحبا،123،أهلا | الهأ،123،ابحرم | الهأ،321،ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-084 | مرحباABC123 | ABC123ابحرم | 321CBAابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-085 | 123ABCمرحبا | ابحرم123ABC | ابحرمCBA321 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-086 | السعر 1 234 567 ريال | لاير 1 234 567 رعسلا | لاير 765 432 1 رعسلا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-087 | السعر 1 234 567 ريال | لاير 1 234 567 رعسلا | لاير 765 432 1 رعسلا | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-088 | قیمت 1 234٫56 تومان | ناموت 1 234٫56 تمیق | ناموت 234٫56 1 تمیق | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-089 | السعر 1234٫56 ريال | لاير 1234٫56 رعسلا | لاير 1234٫56 رعسلا | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-090 | السعر 1٬234٬567 ريال | لاير 1٬234٬567 رعسلا | لاير 1٬234٬567 رعسلا | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-091 | قیمت 1234 روپے ہے | ےہ ےپور 1234 تمیق | ےہ ےپور 4321 تمیق | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-092 | میرے پاس 5 کتابیں ہیں | ںیہ ںیباتک 5 ساپ ےریم | ںیہ ںیباتک 5 ساپ ےریم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-093 | قیمت ۱۲۳۴ روپے | ےپور ۱۲۳۴ تمیق | ےپور ۱۲۳۴ تمیق | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-094 | فون نمبر +92 300 1234567 | 1234567 300 92+ ربمن نوف | 7654321 003 29+ ربمن نوف | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-095 | 123 | 123 | 321 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-096 | مرحبا 123 أهلا | الهأ 123 ابحرم | الهأ 321 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-097 | 123 مرحبا | ابحرم 123 | ابحرم 321 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-098 | مرحبا 123 | 123 ابحرم | 321 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-099 | مرحبا 123 أهلا وسهلا | الهسو الهأ 123 ابحرم | الهسو الهأ 321 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-100 | ABC123مرحبا | ابحرمABC123 | ابحرم321CBA | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-101 | 129 | 129 | 921 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-102 | مرحبا 129 أهلا | الهأ 129 ابحرم | الهأ 921 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-103 | 129 مرحبا | ابحرم 129 | ابحرم 921 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-104 | مرحبا 129 | 129 ابحرم | 921 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-105 | مرحبا 129 أهلا وسهلا | الهسو الهأ 129 ابحرم | الهسو الهأ 921 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-106 | ABC129مرحبا | ابحرمABC129 | ابحرم921CBA | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-107 | 999 | 999 | 999 | MATCH |  |
| RTLC-108 | مرحبا 999 أهلا | الهأ 999 ابحرم | الهأ 999 ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-109 | 999 مرحبا | ابحرم 999 | ابحرم 999 | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-110 | مرحبا 999 | 999 ابحرم | 999 ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-111 | مرحبا 999 أهلا وسهلا | الهسو الهأ 999 ابحرم | الهسو الهأ 999 ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-112 | ABC999مرحبا | ابحرمABC999 | ابحرم999CBA | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-113 | 1,999 | 1,999 | 999,1 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-114 | مرحبا 1,999 أهلا | الهأ 1,999 ابحرم | الهأ 999,1 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-115 | 1,999 مرحبا | ابحرم 1,999 | ابحرم 999,1 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-116 | مرحبا 1,999 | 1,999 ابحرم | 999,1 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-117 | مرحبا 1,999 أهلا وسهلا | الهسو الهأ 1,999 ابحرم | الهسو الهأ 999,1 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-118 | ABC1,999مرحبا | ابحرمABC1,999 | ابحرم999,1CBA | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-119 | 9.99 | 9.99 | 99.9 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-120 | مرحبا 9.99 أهلا | الهأ 9.99 ابحرم | الهأ 99.9 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-121 | 9.99 مرحبا | ابحرم 9.99 | ابحرم 99.9 | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-122 | مرحبا 9.99 | 9.99 ابحرم | 99.9 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-123 | مرحبا 9.99 أهلا وسهلا | الهسو الهأ 9.99 ابحرم | الهسو الهأ 99.9 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-124 | ABC9.99مرحبا | ابحرمABC9.99 | ابحرم99.9CBA | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-125 | -99 | 99- | 99- | MATCH |  |
| RTLC-126 | مرحبا -99 أهلا | الهأ 99- ابحرم | الهأ 99- ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-127 | -99 مرحبا | ابحرم 99- | ابحرم 99- | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-128 | مرحبا -99 | 99- ابحرم | 99- ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-129 | مرحبا -99 أهلا وسهلا | الهسو الهأ 99- ابحرم | الهسو الهأ 99- ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-130 | ABC-99مرحبا | ابحرمABC-99 | ابحرم99-CBA | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-131 | $999 | $999 | 999$ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-132 | مرحبا $999 أهلا | الهأ 999$ ابحرم | الهأ 999$ ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-133 | $999 مرحبا | ابحرم $999 | ابحرم 999$ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-134 | مرحبا $999 | 999$ ابحرم | 999$ ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-135 | مرحبا $999 أهلا وسهلا | الهسو الهأ 999$ ابحرم | الهسو الهأ 999$ ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-136 | ABC$999مرحبا | ابحرمABC$999 | ابحرم999$CBA | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-137 | مرحبا ١٢٣ أهلا | الهأ ١٢٣ ابحرم | الهأ ١٢٣ ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-138 | ١٢٣ | ١٢٣ | ٣٢١ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-139 | مرحبا ٩٩٩ أهلا | الهأ ٩٩٩ ابحرم | الهأ ٩٩٩ ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-140 | ٩٩٩ | ٩٩٩ | ٩٩٩ | MATCH |  |
| RTLC-141 | قیمت ۱۲۳ تومان | ناموت ۱۲۳ تمیق | ناموت ۱۲۳ تمیق | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-142 | ۱۲۳ | ۱۲۳ | ۳۲۱ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-143 | قیمت ۹۹۹ تومان | ناموت ۹۹۹ تمیق | ناموت ۹۹۹ تمیق | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-144 | ۹۹۹ | ۹۹۹ | ۹۹۹ | MATCH |  |
| RTLC-145 | مرحبا 123 أهلا | الهأ 123 ابحرم | الهأ 321 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-146 | السعر 99 ريال | لاير 99 رعسلا | لاير 99 رعسلا | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-147 | السعر 9999 ريال | لاير 9999 رعسلا | لاير 9999 رعسلا | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-148 | مرحبا $9.99 | 9.99$ ابحرم | 99.9$ ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-149 | مرحبا 9.99 أهلا | الهأ 9.99 ابحرم | الهأ 99.9 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-150 | مرحبا أهلا | الهأ ابحرم | الهأ ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-151 | مرحبا 123 أهلا | الهأ 123 ابحرم | الهأ 321 ابحرم | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-152 | ABC 1 مرحبا | ابحرم ABC 1 | ابحرم 1 ABC | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-153 | מחיר 100 ₪ | ₪ 100 ריחמ | ₪ 001 ריחמ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-154 | قیمت 100 تومان | ناموت 100 تمیق | ناموت 001 تمیق | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-155 | مرحبا 1 أهلا | الهأ 1 ابحرم | الهأ 1 ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-156 | $1 | $1 | 1$ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-157 | מחיר 1 ₪ | ₪ 1 ריחמ | ₪ 1 ריחמ | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-158 | قیمت 1 تومان | ناموت 1 تمیق | ناموت 1 تمیق | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-159 | مرحبا أهلا | الهأ ابحرم | الهأ ابحرم | MISMATCH | same visual order; differs only by NBSP vs plain space |
| RTLC-160 | مرحبا 123 أهلا | الهأ 123 ابحرم | ابحرم 123 الهأ | MISMATCH | reordered relative to plain UBA rendering |
| RTLC-161 | 999 | 999 | 999 | MATCH |  |
| RTLC-162 | 999 | 999 | 999 | MATCH |  |

**162 cases, 7 MATCH, 155 MISMATCH (of which 49 differ only by NBSP-vs-space, 106 are true reorderings).**

## Findings

### (i) Multi-digit numbers
Case `RTLC-001` (`السعر 1234 ريال`):

- Plain browser graphemes, left→right by x: `ا`@x=112.4531, `ل`@x=108.3125, `س`@x=97.6875, `ع`@x=89.8125, `ر`@x=80.0313, ` `@x=74.4844, `1`@x=29.9844, `2`@x=41.0938, `3`@x=52.2188, `4`@x=63.3438, ` `@x=24.4219, `ر`@x=18.3125, `ي`@x=12.2031, `ا`@x=6.0938, `ل`@x=0
- Torph `[torph-item]` DOM children, by x: `السعر`@x=80.0625, ` `@x=74.5, `1`@x=63.375 (kind=digit) slot, `2`@x=52.25 (kind=digit) slot, `3`@x=41.125 (kind=digit) slot, `4`@x=30 (kind=digit) slot, ` `@x=24.4375, `ريال`@x=0
- Torph visual glyph order string: `لاير 4321 رعسلا`; plain: `لاير 1234 رعسلا`.

### (ii) Currency / sign / percent / separators
Case `RTLC-002` (`السعر $1,234.56 اليوم`):

- Plain browser graphemes, by x: `ا`@x=161.0625, `ل`@x=156.9219, `س`@x=146.3125, `ع`@x=138.4375, `ر`@x=128.6563, ` `@x=123.0938, `$`@x=111.9844, `1`@x=34.125, `,`@x=45.2344, `2`@x=50.7969, `3`@x=61.9219, `4`@x=73.0469, `.`@x=84.1719, `5`@x=89.7188, `6`@x=100.8438, ` `@x=28.5625, `ا`@x=24.4219, `ل`@x=20.2813, `ي`@x=15.3906, `و`@x=6.75, `م`@x=0
- Torph items, by x: `السعر`@x=128.7031, ` `@x=123.1406, `$`@x=112.0156 (kind=symbol) slot, `1`@x=100.8906 (kind=digit) slot, `,`@x=95.3281 (kind=symbol) slot, `2`@x=84.2031 (kind=digit) slot, `3`@x=73.0781 (kind=digit) slot, `4`@x=61.9531 (kind=digit) slot, `.`@x=56.3906 (kind=symbol) slot, `5`@x=45.2656 (kind=digit) slot, `6`@x=34.1406 (kind=digit) slot, ` `@x=28.5781, `اليوم`@x=0

### (iii) Latin words embedded in RTL text
Case `RTLC-027` (`مرحبا ABC 123 DEF`):

- Plain browser graphemes, by x: `م`@x=161, `ر`@x=151.2344, `ح`@x=140.625, `ب`@x=135.75, `ا`@x=131.1563, ` `@x=125.6094, `A`@x=0, `B`@x=13.3281, `C`@x=26.6719, ` `@x=41.1094, `1`@x=46.6719, `2`@x=57.7969, `3`@x=68.9219, ` `@x=80.0469, `D`@x=85.5938, `E`@x=100.0469, `F`@x=113.375
- Torph items, by x: `مرحبا`@x=131.1875, ` `@x=125.625, `ABC`@x=84.5, ` `@x=78.9375, `1`@x=67.8125 (kind=digit) slot, `2`@x=56.6875 (kind=digit) slot, `3`@x=45.5625 (kind=digit) slot, ` `@x=40, `DEF`@x=0

### (iv) RTL words
Case `RTLC-001` (`السعر 1234 ريال`):

- Plain browser graphemes, by x: `ا`@x=112.4531, `ل`@x=108.3125, `س`@x=97.6875, `ع`@x=89.8125, `ر`@x=80.0313, ` `@x=74.4844, `1`@x=29.9844, `2`@x=41.0938, `3`@x=52.2188, `4`@x=63.3438, ` `@x=24.4219, `ر`@x=18.3125, `ي`@x=12.2031, `ا`@x=6.0938, `ل`@x=0
- Torph items, by x: `السعر`@x=80.0625, ` `@x=74.5, `1`@x=63.375 (kind=digit) slot, `2`@x=52.25 (kind=digit) slot, `3`@x=41.125 (kind=digit) slot, `4`@x=30 (kind=digit) slot, ` `@x=24.4375, `ريال`@x=0

### (v) Whitespace items inside an RTL root
Case `RTLC-001` (`السعر 1234 ريال`):

- Space item(s): index=1 x=74.5 w=5.5625; index=6 x=24.4375 w=5.5625

### inline-block items and bidi (measured, not assumed)
- Sample item ` n0` (text `1`): computed `display=inline-block`, `direction=rtl`, `unicode-bidi=normal`; its mover: `display=inline-block`, `direction=rtl`, `unicode-bidi=normal`.
- Root computed: `direction=rtl`, `unicode-bidi=normal`, `display=inline-block`.

### Mover/slot ordering during morphs, interrupts, storms

**Morph** — case `RTLC-095`: `123` → `124` (resolved duration 400ms).

- t=0 (frac 0): visual order by x: 3@0, 4@0, 2@11.125, 1@22.25
- t=40 (frac 0.1): visual order by x: 3@0, 4@0, 2@11.125, 1@22.25
- t=100 (frac 0.25): visual order by x: 3@0, 4@0, 2@11.125, 1@22.25
- t=148 (frac 0.37): visual order by x: 3@0, 4@0, 2@11.125, 1@22.25
- t=200 (frac 0.5): visual order by x: 4@0, 2@11.125, 1@22.25
- t=292 (frac 0.73): visual order by x: 4@0, 2@11.125, 1@22.25
- t=360 (frac 0.9): visual order by x: 4@0, 2@11.125, 1@22.25
- t=400 (frac 1): visual order by x: 4@0, 2@11.125, 1@22.25

**Interrupt** — case `RTLC-145`: `مرحبا 123 أهلا` → `مرحبا 456 أهلا` → `مرحبا 789 أهلا`.

- Interrupted at frac 0.37 (t1=148):
  - before: أهلا@0,  @25.1563, 6@30.7188, 3@31, 5@41.8438, 2@42, 4@52.9688, 1@53,  @64.0938, مرحبا@69.6563
  - right after interrupt: أهلا@0,  @25.1563, 9@30.7188, 3@31, 6@31, 8@41.8438, 2@42, 5@42, 7@52.9688, 1@53, 4@53,  @64.0938, مرحبا@69.6563
  - at end: أهلا@0,  @25.1563, 9@30.7188, 8@41.8438, 7@52.9688,  @64.0938, مرحبا@69.6563

**Storm** — case `RTLC-155`: `مرحبا 1 أهلا` → `مرحبا 12 أهلا` → `مرحبا 123 أهلا` → `مرحبا 1,234 أهلا` → `مرحبا 12,345 أهلا`.

- t=0 value=`مرحبا 12 أهلا`: visual order by x: أهلا@0,  @14.1703, 2@19.5938,  @25, 1@30.7188,  @41.8438, مرحبا@47.4063
- t=16 value=`مرحبا 123 أهلا`: visual order by x: أهلا@-0.0023,  @5.3265, 3@10.75,  @16, 2@21.8874,  @25.0287, 1@33.0124,  @44.1374, مرحبا@49.6999
- t=32 value=`مرحبا 1,234 أهلا`: visual order by x:  @-1.7047, أهلا@-0.0291, 4@3.7188,  @9,  @13.7328, 3@14.8438,  @25.0551, 2@25.9786, ,@31.5313, 1@37.1036,  @48.2286, مرحبا@53.7911
- t=48 value=`مرحبا 12,345 أهلا`: visual order by x:  @-11.6735, 5@-6.25, أهلا@-0.0245,  @3.4063,  @5.5848, 4@9.2896,  @11.6525, 3@20.4146, ,@21.5625,  @25.0771, 2@31.5474, ,@38, 1@43.8203,  @54.9453, مرحبا@60.5078
- t=564 value=`(settled)`: visual order by x: أهلا@0,  @25.1563, 5@30.7188, 4@41.8438, 3@52.9688, ,@64.0938, 2@69.6563, 1@80.7813,  @91.9063, مرحبا@97.4688

