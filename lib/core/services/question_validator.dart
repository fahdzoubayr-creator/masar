import 'package:masar_app/core/models/question.dart';

/// فلتر صارم للأسئلة — يُزيل أي سؤال مكسور أو غير تربوي قبل الوصول لشاشة الكويز.
class QuestionValidator {
  QuestionValidator._();

  /// أنماط النص المشوّه (mojibake / CJK / رموز غير عربية).
  static final _garbledPattern = RegExp(
    r'[\u200B-\u200F\u2028-\u202F\u2060-\u2069'
    r'\u4E00-\u9FFF\u3400-\u4DBF'
    r'\uFFFD\uFFFE\uFFFF'
    r'\u0000-\u0008\u000B\u000C\u000E-\u001F]',
  );

  /// كلمات مشوّهة شائعة في البيانات المستخرجة من PDF.
  static final _mojibakeWords = RegExp(
    r'(?:Ø§Ù|ÙØ§|Ø§Ù„|Ù…Ø§|ÙŠÙ†|Ø¹Ù„|Ã)',
  );

  /// عبارة "جميع ما سبق خاطئ" بأي صيغة.
  static final _allWrongPattern = RegExp(
    r'جميع\s+(?:الاختيارات\s+)?(?:أعلاه|المذكورة|السابقة)\s+خاطئ',
  );

  /// عبارة "لا توجد إجابة صحيحة" أو ما شابه.
  static final _noCorrectPattern = RegExp(
    r'لا\s+توجد\s+إجابة\s+صحيحة|لا\s+أي\s+من\s+الخيارات\s+صحيحة',
  );

  /// فحص سؤال واحد — يُرجع `true` إذا كان السؤال صالحاً.
  ///
  /// يرفض الأسئلة المكسورة هيكلياً فقط (خيارات مكررة، فهرس خارج النطاق،
  /// نص مشوّه، خيارات شبيهة جداً). لا يرفض شرح فارغ — ذلك مسألة جودة وليس كسر بنية.
  static bool isValid(Question q) {
    // 1. النص غير فارغ
    if (q.text.trim().isEmpty) return false;

    // 2. طول النص الكافي (ليس عبارة قصيرة جداً)
    if (q.text.trim().length < 8) return false;

    // 3. لا يوجد تشويه في النص (mojibake / CJK / control chars)
    if (_garbledPattern.hasMatch(q.text)) return false;
    if (_mojibakeWords.hasMatch(q.text)) return false;

    // 4. الخيارات موجودة وصحيحة العدد (4)
    if (q.options.length != 4) return false;

    // 5. لا توجد خيارات مكررة (مطابقة تامة)
    final normalized = q.options.map((o) => _normalizeOption(o)).toList();
    final uniqueSet = normalized.toSet();
    if (uniqueSet.length != q.options.length) return false;

    // 6. لا توجد خيارات فارغة
    for (final opt in q.options) {
      if (opt.trim().isEmpty) return false;
    }

    // 7. لا توجد عبارة "جميع ما سبق خاطئ" مكررة في الخيارات
    var allWrongCount = 0;
    for (final opt in normalized) {
      if (_allWrongPattern.hasMatch(opt) || _noCorrectPattern.hasMatch(opt)) {
        allWrongCount++;
      }
    }
    if (allWrongCount > 1) return false;

    // 8. لا توجد خيارات شبيهة جداً (ت相似 > 80%)
    if (_hasNearDuplicateOptions(normalized)) return false;

    // 9. correctIndex في النطاق الصحيح
    if (q.correctIndex < 0 || q.correctIndex >= q.options.length) return false;

    return true;
  }

  /// تطبيع الخيار للمقارنة (إزالة علامات الترقيم والمسافات الزائدة).
  static String _normalizeOption(String opt) {
    var s = opt.trim().toLowerCase();
    // إزالة علامات الترقيم الشائعة في النهاية.
    s = s.replaceAll(RegExp(r'[.\?؟!,،:;\s]+$'), '');
    // إزالة علامات الاقتباس.
    s = s.replaceAll(RegExp(r'''^["«»\u00AB\u00BB']+|["«»\u00AB\u00BB']+$'''), '');
    return s;
  }

  /// فحص وجود خيارات شبيهة جداً (> 95% تشابه — يُسمّح بالفروق الدقيقة المقصودة).
  static bool _hasNearDuplicateOptions(List<String> normalized) {
    for (var i = 0; i < normalized.length; i++) {
      for (var j = i + 1; j < normalized.length; j++) {
        if (_similarity(normalized[i], normalized[j]) > 0.95) return true;
      }
    }
    return false;
  }

  /// حساب نسبة التشابه بين نصين (by Levenshtein ratio).
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final maxLen = a.length > b.length ? a.length : b.length;
    if ((a.length - b.length).abs() > maxLen * 0.5) return 0.0;
    final d = _levenshtein(a, b);
    return 1.0 - d / maxLen;
  }

  static int _levenshtein(String a, String b) {
    final la = a.length;
    final lb = b.length;
    final dp = List.generate(la + 1, (i) => List.filled(lb + 1, 0));
    for (var i = 0; i <= la; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= lb; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= la; i++) {
      for (var j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[la][lb];
  }

  /// فلترة قائمة من الأسئلة — يُرجع فقط الأسئلة الصالحة.
  static List<Question> filterValid(List<Question> questions) {
    return questions.where(isValid).toList();
  }

  /// إحصائيات الفلترة — يُرجع {total, valid, removed, reasons}.
  /// يُ区分 بين أخطاء بنية (ترفض السؤال) و质量问题 (تحذر فقط).
  static Map<String, dynamic> audit(List<Question> questions) {
    int total = questions.length;
    int valid = 0;
    int warnings = 0;
    final reasons = <String, int>{
      'empty_text': 0,
      'short_text': 0,
      'garbled_text': 0,
      'invalid_option_count': 0,
      'duplicate_options': 0,
      'near_duplicate_options': 0,
      'all_wrong_duplicated': 0,
      'empty_option': 0,
      'invalid_correct_index': 0,
      'empty_explanation': 0,
    };

    for (final q in questions) {
      bool ok = true;
      bool warned = false;
      if (q.text.trim().isEmpty) {
        reasons['empty_text'] = reasons['empty_text']! + 1;
        ok = false;
      }
      if (q.text.trim().length < 8) {
        reasons['short_text'] = reasons['short_text']! + 1;
        ok = false;
      }
      if (_garbledPattern.hasMatch(q.text) || _mojibakeWords.hasMatch(q.text)) {
        reasons['garbled_text'] = reasons['garbled_text']! + 1;
        ok = false;
      }
      if (q.options.length != 4) {
        reasons['invalid_option_count'] = reasons['invalid_option_count']! + 1;
        ok = false;
      }
      final normalized = q.options.map((o) => _normalizeOption(o)).toList();
      final opts = normalized.toSet();
      if (opts.length != q.options.length) {
        reasons['duplicate_options'] = reasons['duplicate_options']! + 1;
        ok = false;
      }
      if (_hasNearDuplicateOptions(normalized)) {
        reasons['near_duplicate_options'] = reasons['near_duplicate_options']! + 1;
        ok = false;
      }
      var allWrongCount = 0;
      for (final opt in normalized) {
        if (_allWrongPattern.hasMatch(opt) || _noCorrectPattern.hasMatch(opt)) {
          allWrongCount++;
        }
      }
      if (allWrongCount > 1) {
        reasons['all_wrong_duplicated'] = reasons['all_wrong_duplicated']! + 1;
        ok = false;
      }
      for (final opt in q.options) {
        if (opt.trim().isEmpty) {
          reasons['empty_option'] = reasons['empty_option']! + 1;
          ok = false;
          break;
        }
      }
      if (q.correctIndex < 0 || q.correctIndex >= q.options.length) {
        reasons['invalid_correct_index'] = reasons['invalid_correct_index']! + 1;
        ok = false;
      }
      if (q.explanation.trim().isEmpty) {
        reasons['empty_explanation'] = reasons['empty_explanation']! + 1;
        warned = true;
      }
      if (ok) valid++;
      if (warned) warnings++;
    }

    return {
      'total': total,
      'valid': valid,
      'removed': total - valid,
      'warnings': warnings,
      'reasons': reasons,
    };
  }
}
