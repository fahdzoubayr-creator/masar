import 'package:web/web.dart' as web;

/// فحص مفتاح البناء القديم المحفوظ خاماً في localStorage (بلا بادئة flutter.)
/// والقيمة النصية "1" — يقاوم أي خطأ في الوصول للمخزن.
bool wasExamUnlockedLegacy() {
  try {
    return web.window.localStorage.getItem('masar_exam_unlocked') == '1';
  } catch (_) {
    return false;
  }
}
