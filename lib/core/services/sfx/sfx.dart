import 'sfx_stub.dart'
    if (dart.library.js_interop) 'sfx_web.dart' as impl;

/// أحداث الصوت في التطبيق — أسماء الملفات في assets/sounds تطابق قيم enum.
enum Sfx { tap, select, success, error, complete, victory, defeat, explosion, path_unlock, dam_unlock }

/// يشغّل مؤثراً صوتياً أنيقاً دون تعطيل التدفق — استدعاء ناري وآمن.
void playSfx(Sfx s) => impl.playSfx(s);

/// يشغّل صوت ارتفاع تصاعدي (rising pitch) لفتح المسار.
void playRisingSfx() => impl.playRisingSfx();

/// استئناف استباقي لسياق الصوت على الويب (لا شيء خارج الويب).
void primeAudio() => impl.primeAudio();

/// تحميل مسبق للمخازن الصوتية (لا عمليّة على منصات الأصول المحلية).
void preloadSfx() => impl.preloadSfx();
