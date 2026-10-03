# ملاحظات المشروع — Masar (مسار)

## متطلب أساسي (أهمية عالية)
**يجب أن يشتغل تطبيق الويب من الأجهزة الأخرى رغم تغيّر عنوان IP للجهاز الخادم.**

- الجهاز يعمل بنظام DHCP، لذا عنوانه المحلي يتغيّر تلقائياً (تغيّر سابقاً من
  `192.168.100.204` إلى `192.168.0.129`).
- الخادم: `node server.js` (HTTP 8123 / HTTPS 8443)، يعمل حاليّاً من مجلد
  `build\web`.
- **الويب أصلاً مستقلّ عن IP**: كود Flutter يشتقّ العنوان تلقائياً من
  `Uri.base` في `lib/features/live_room/config/live_room_config.dart` —
  يكفي فتح العنوان الحالي: `https://<current-ip>:8443/`.
- `server.js` يطبع عناوين LAN الحالية عند كل إقلاع (دالة `logLanAddresses`).

### الإجراءات المتبعة / المقررة
1. **إيجاد العنوان الحالي**: شغّل على الجهاز الخادم:
   `Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown'}`
   أو اقرأ مخرجات إقلاع server.js.
2. **على المدى الطويل** (أُنجز):
   - جُعل عنوان الخادم على الهاتف **قابلاً للتعديل من داخل التطبيق**: زر
     الإعدادات ⚙ في شاشة «قاعة الجلسات» (يظهر على غير الويب) — يُحدَّث العنوان
     ويُحفظ في shared_preferences عبر `ServerConfigService` دون إعادة بناء.
     `mobileSignalingUrl`/`mobileApiBaseUrl` في `live_room_config.dart` صارا
     getter يقرآن `ServerConfigService.effectiveSignalingUrl`/`effectiveApiBase`.
   - أو تثبيت عنوان للجهاز من إعدادات الراوتر (DHCP reservation / Static IP).
3. عند فتح الويب من هاتف آخر، تذكر ألّا يكون هناك `localhost` في العنوان.

## البنية العامة
- فلاتر: `flutter analyze` ثم `flutter test` (4 اختبارات) قبل أي نشر.
- البناء: `flutter build web --release` ثم `flutter build apk --release`،
  والـ APK يُنسخ إلى `uploads\app-release.apk`.
- الخادم يُعيد تشغيله يدوياً بعد أي تعديل على server.js أو build/web.

## توليد الأسئلة (مطلوب من المستخدم)
- **بلا أي علامة تنقيط** في نهاية الأسئلة (لا `(1 ن)` ولا غيرها).
- نمط 1 — تسلسل/ترتيب (مثل أسئلة حصص الديداكتيك):
  المقدمة «تنجز/تدبر/تخطط ... وفق ما يأتي:» وخيارات A–D سلاسل متقاربة
  (تبديل عنصر أو ترتيب) + خيار E «الأجوبة المقترحة السابقة جميعها خاطئة.»
- نمط 2 — المفهوم/التعريف (مثل Q63–Q66): المقدمة تطرح مفهوماً/غاية
  («... وتعني: / ينبني أساساً على: / يهدف إلى:») والخيارات عبارات طويلة،
  الصحيح تعريف المفهوم والمشتّتات تعاريف مفاهيم مجاورة من نفس الوثيقة،
  + خيار E «جميع الأجوبة المقترحة أعلاه خاطئة.»
- مصدر المحتوى: نص وثيقة يلصقه المستخدم (PDF الأصلية ممسوحة ضوئياً لا تُقرأ).

---

## يوم 2026-10-02 — تقدّم أسئلة الكويز (مولّد المحاور)

### ما أُنجز ويُعمل به الآن
| البند | التنفيذ | الملف |
|---|---|---|
| صيغة الوضعية + السؤال | `situation` جملة قصيرة 8–18 كلمة، ثم السؤال مباشرة | `tools/quiz_from_pdf.py` (PROMPT + `valid_item`) |
| 4 خيارات + «د» ثابتة | `compose`/`_fill_options` تبني 3 حقيقية + العبارة الإلزامية أخيراً | `tools/quiz_from_pdf.py` |
| بثّ تدريجي | `flush_progress` يكتب `*.progress.json` بعد كل نداء | `tools/quiz_from_pdf.py` |
| ردّ فوري | `POST /api/quiz/start-from-pdf` يردّ بـ`jobId` فقط | `server.js:746` |
| بثّ عبر الاستطلاع | `GET /api/quiz/job/<id>` يقدّم ما وصل + `state:working` | `server.js` (~779) |
| فتح الكويز فوري | 10 أسئلة بنك أولاً + `unawaited` بدء التوليد | `topic_files_screen.dart` |
| إضافة واحد تلو الآخر | `restLoader` يُعيد سؤالاً واحداً؛ `_scheduleMore(1)` | `topic_files_screen.dart`, `quiz_screen.dart` |
| العدد 70 → 50 | `server.js`, `question_repository.dart`, `question_generator.dart`, `generated_quiz_service.dart`, `topic_files_screen.dart` | |
| توزيع الإجابة | `correctIndex` من 100% «د» → ~25% لكل موضع | `question_generator.dart:189` |
| تنوّع الخيارات | `_isDistinctDistractor` (Jaccard ≥0.6 مع الصحيح، ≥0.75 بين المشتّتات) | `question_generator.dart` |
| فلترة المادة | `_isSameSubject` + `_subjectKeywords` | `question_generator.dart:142` |

### قرارات معتمدة
1. **بنك الأسئلة لا يُعرض إلا لملء الفارق**: أول 10 بنك (فورية)، والباقي مولَّد.
2. **المولّد يجب أن يسبق المستخدم**: حلقة الاستطلاع تستمر حتى 50، ولا «انتظر».
3. **«د» اختيارية كإجابة**: تُثبَّت نصاً في الموضع 4، لكنها ليست الصحيحة دائماً (~25%).
4. `POST` يجب أن يبقى **< 5 ثوانٍ** (حالياً ~40ms).

### ⚠️ الواجب المعلّق (لغداً)
1. **المولّد لا يبلغ 50 بعد** — آخر اختبار:
   ```
   ROUND_EXTRA r=1 need=23 calls=12 have=27
   ROUND_EXTRA r=2 need=23 calls=12 have=27   ← لا جديد (تكرار/حصة)
   GEN_OK count=27
   PARTIAL_OK got=27 need=50
   ```
   السبب المرجّح: المقاطع تتكرّر بعدد لا يتجاوز 27 عنصراً فريداً، أو نفاد حصة
   المزوّد. يلزم: تنويع داخل النداء (أسئلة مختلفة لكل مقطع)، و`chunks` لكلمات
   متداخلة، ورفعة `PER_CALL` أو `max_tokens`، ربّما استدعاء موازٍ في الجولة الثانية
   بمقاطع لم تُستخدم (`used_chunks`).
2. **التحقّق من فلترة المادة فعلياً**: لم يُختبر بعد — المطلوب فتح كويز الرياضيات
   والتأكد أن لا يظهر فيه سؤال عربي أو علوم تربية (البناء الأخير ضمّن
   `_isSameSubject` لكن لم يُجرَّب في الواجهة).
3. **تنظيف مؤقّت**: حذف `C:\Users\JAMAL\AppData\Local\Temp\opencode\*.py`
   المتبقية (`fix_lead.py`, `fix_subject.py`, `audit_keys.py`).
4. `flutter analyze` + `flutter build web --release` بعد إصلاح 1، ثم إعادة
   تشغيل السيرفر بـ`taskkill /PID` (لا `Stop-Process` — يفشل صامتاً).

### حالة الخادم الآن
- `server.js` يعمل: PID `12088` على `https://127.0.0.1:8443/`.
- الأسرار في `.env` فقط (لا تُطبع؛ الملف ignored). ترتيب المزوّدين:
  `gemini → groq → github`.
- GitHub Models معطّل عملياً (يعيد `OK\r\n` ← `'str' object has no attribute
  'choices'`). الاعتماد على Gemini + Groq.
- لا commit ولا push — كل التعديلات محلية.

---

## يوم 2026-10-03 — إصلاح مولّد الأسئلة ليبلغ 50

### السبب الجذري
- الملفات القصيرة (PDF ممسوح) كانت تُقطَّع إلى **مقطع واحد**؛ فتُكرَّر الاستدعاءات
  على النص نفسه بحصةٍ متطابقة، فتُرفض الأسئلة المكرّرة ويقف العدّاد (~27).
  مثال: `didactique_arabe__01.pdf` = 207 كلمة → مقطع واحد سابقاً.

### ما تغيّر في `tools/quiz_from_pdf.py`
| البند | التنفيذ |
|---|---|
| تقطيع تكيّفي | `CHUNK_WORDS=240`, `CHUNK_TARGET=8`, `CHUNK_MIN=80` — الملف القصير يُقطَّع لعدة مقاطع |
| تنويع الزوايا | `FOCUS_ANGLES` (10 زوايا) تُوزَّع دورياً على الاستدعاءات |
| منع التكرار | `recent_stems()` + كتلة `{avoid}` في `PROMPT` تمنع إعادة الأسئلة السابقة |
| نافذة منزلقة | الاستدعاءات تُطلَق تدريجياً (PARALLEL في الطيران) لترى الـavoid-list المتراكم |
| تهدئة الحصة | `_is_quota()`: التهدئة 120ث على 429 فقط، ولا تهدئة على 503 العابر (كانت 600ث وتُجمّد المزوّد ظلماً) |

### نتائج الاختبار الفعلي
```
ouloum_tarbiya__29.pdf   (945 كلمة، كان 14)  → GEN_OK count=50 في 4 نداءات
didactique_arabe__01.pdf (207 كلمة، كان ~27) → GEN_OK count=50 في 5 نداءات
```

### أُنجز (تكملة يوم 2026-10-03)
1. **فلترة المادة**: أُضيف `test/subject_filter_test.dart`. النتيجة: كويز
   الرياضيات (`ديداكتيك الرياضيات`) لا يحوي أي سؤال عربية/علوم تربية/فرنسية/
   نشاط علمي/تشريع. ملاحظة: `_isSameSubject` لا يُسقط شيئاً فعلياً لأن مفاتيحه
   (`الرياضيات`…) لا تطابق أسماء المحاور الفعلية (`ديداكتيك الرياضيات`)، لكن
   بنك الأسئلة مفتاحه بحقل `subject` أصلاً فلا تسرّب.
2. **تنظيف**: حُذفت `Temp\opencode\{fix_lead,fix_subject,audit_keys}.py`.
3. **تحليل**: `flutter analyze` من 38 إلى 33 ملاحظة (لا أخطاء). أُصلحت ملاحظات
   `question_generator.dart` وأُصلح خلل حقيقي في `splash_screen.dart` (قراءة
   `MediaQuery` داخل `initState` → صارت
   `platformDispatcher.accessibilityFeatures.disableAnimations`) فنجح `widget_test`.
4. **اختبارات**: كل الاختبارات تنجح عدا `review_page_images_test` (يحتاج خادم
   CORS على `127.0.0.1:8641`، خارجي).
5. **بناء**: `flutter build web --release` = `√ Built build\web`.

### حالة الخادم الآن (2026-10-03)
- `node server.js` يعمل PID `2120` على `http://127.0.0.1:8123` و
  `https://127.0.0.1:8443`، وعنوان LAN: `https://192.168.0.161:8443/`.
- **رُفع** فرع `master` إلى GitHub بعد تنقية الأسرار من التاريخ (Groq/GCP)
  وإزالة الملفات الضخمة من التاريخ. `master` = `origin/master`.
- تعديلات اليوم (`subject_filter_test.dart`, `splash_screen.dart`,
  `question_generator.dart`) لم تُلتزم بعد — محلية.
