import 'dart:math';

import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/question_validator.dart';

/// يسحب أسئلة اختيار من متعدد من بنك الأسئلة (PopularBankData + WadiaaBankData).
///
/// لا يُولّد أي سؤال من النصوص — يأخذ الأسئلة حصرياً من البنوك الموجودة.
class QuestionGenerator {
  /// العبارة الإلزامية للخيار الأخير (د) — مطابقة لما يولّده مولّد المحاور.
  static const String allWrongOption = 'كل الأجوبة السابقة خاطئة';

  /// صيغ قديمة/مكافئة موجودة في بنك الأسئلة، نوحّدها إلى العبارة الإلزامية.
  static const List<String> allWrongVariants = <String>[
    'كل الأجوبة السابقة خاطئة',
    'كل الاقتراحات السابقة خاطئة',
    'كل الاقتراحات خاطئة',
    'جميع الإجابات السابقة خاطئة',
    'جميع الإجابات خاطئة',
    'جميع ما سبق خاطئ',
    'كل ما سبق خاطئ',
    'لا شيء مما سبق',
  ];

  static const String frenchAllWrongOption =
      'Toutes les réponses ci-dessus sont fausses.';

  /// هل هذا النص يُعنى بـ«كل الأجوبة السابقة خاطئة» بأي صيغة؟
  static bool isAllWrong(String? raw) {
    final s = (raw ?? '')
        .replaceAll('\u0627', 'ا')
        .replaceAll('\u0623', 'ا')
        .replaceAll('\u0625', 'ا')
        .replaceAll('\u0649', 'ي')
        .replaceAll('\u0629', 'ه')
        .replaceAll('\u0624', 'و')
        .replaceAll('\u0626', 'ي')
        .replaceAll('\u0621', 'ا')
        .replaceAll('\u0640', '')
        .replaceAll(RegExp(r'[^\u0620-\u064Aa-zA-Z]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    if (s.isEmpty) return false;
    String n(String v) => v
        .replaceAll('\u0627', 'ا')
        .replaceAll('\u0623', 'ا')
        .replaceAll('\u0625', 'ا')
        .replaceAll('\u0649', 'ي')
        .replaceAll('\u0629', 'ه')
        .replaceAll('\u0624', 'و')
        .replaceAll('\u0626', 'ي')
        .replaceAll('\u0621', 'ا')
        .replaceAll(RegExp(r'[^\u0620-\u064Aa-zA-Z]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    for (final v in allWrongVariants) {
      if (s == n(v)) return true;
    }
    return s.contains('كل سابقة') && s.contains('خاط');
  }

  /// يوحّد صيغة الخيار الأخير في قائمة الخيارات.
  static void normalizeAllWrong(List<String> opts) {
    for (var i = 0; i < opts.length; i++) {
      if (isAllWrong(opts[i])) opts[i] = allWrongOption;
    }
  }

  /// نسبة الأسئلة التي يكون جوابها الصحيح «جميع الاختيارات أعلاه خاطئة».
  static const double allWrongChance = 0.7;

  static final Random _random = Random();

  // ---------------- سحب الأسئلة من البنوك ----------------

  /// يسحب حتى [count] سؤالاً لمحور [folder] (افتراضياً 70 سؤالاً).
  /// يأخذ الأسئلة حصرياً من بنك الأسئلة (PopularBankData + WadiaaBankData)
  /// ولا يُولّد أي سؤال من النصوص.
  static Future<List<Question>> generateForFolder(String folder,
      {String? topic, int count = 50}) async {
    // البنك المختص بمحور [folder] فقط — لا نسمح أبداً بدخول أسئلة
    // مواد أخرى حتى عندما يكون العدد دون حدّ [count].
    final folderBank = List<Question>.of(poolForFolder(folder));
    final pool = <Question>[];
    final seen = <String>{};
    void addAll(List<Question> questions) {
      for (final q in questions) {
        if (seen.add(q.text)) pool.add(q);
      }
    }

    // 1) إن حُدّد موضوع فرعي، نحاول أولاً أسئلته المطابقة (إن وُجدت).
    if (topic != null) {
      final topicMatch =
          folderBank.where((q) => _matchesTopic(q, topic)).toList();
      if (topicMatch.isNotEmpty) addAll(topicMatch);
    }

    // 2) أكمل من باقي بنك المحور فقط حتى بلوغ الحاجة.
    if (pool.length < count) addAll(folderBank);

    // خلط واختيار العدد
    final validPool = QuestionValidator.filterValid(pool);
    validPool.shuffle(_random);
    final result =
        (validPool.length > count ? validPool.sublist(0, count) : validPool)
            .map(withShuffledOptions)
            .toList();
    return result;
  }

  /// هل سؤال [q] يخص موضوعاً فرعياً [topic]؟ مطابقة مرنة على النص والموضوع.
  static bool _matchesTopic(Question q, String topic) {
    if (q.subject.contains(topic) || topic.contains(q.subject)) return true;
    return q.text.contains(topic) || topic.split(' ').any((w) => w.length > 3 && q.text.contains(w));
  }

  /// كلمات مفتاحية تميّز موادّاً عن بعضها داخل بنك «تحدي الكفاءة المهنية»
  /// الذي يحوي كل المواد في مفتاح واحد.
  static const Map<String, List<String>> _subjectKeywords = <String, List<String>>{
    'الرياضيات': <String>[
      'رياضيات', 'الرياضيات', 'جبر', 'هندسة', 'المثلث', 'المعين', 'متوازي',
      'الأعداد', 'العدد', 'القسمة', 'الضرب', 'الجمع', 'الطرح', 'الدالة',
      'المعادلة', 'المعادلات', 'الاحتمال', 'التناسبية', 'النسبة', 'المقياس',
      'المساحة', 'الحجم', 'الزاوية', 'الزوايا', 'المستقيم', 'الدائرة',
      'المنصف', 'الوسيط', 'جذر', 'اللوغاريتم',
      'المتتالية', 'الحد', 'الدوال', 'الإحصاء', 'المعدل', 'الوسيط الإحصائي',
    ],
    'اللغة العربية': <String>[
      'اللغة العربية', 'العربية', 'النحو', 'الصرف', 'البلاغة', 'الجزالة',
      'الإعراب', 'الجملة', 'الشعر', 'النص', 'الأدب', 'المفهوم', 'الموضوع',
      'التشبيه', 'الاستعارة', 'الكناية', 'الطباق', 'السجع', 
    ],
    'اللغة الفرنسية': <String>[
      'الفرنسية', 'français', 'francais', 'FLE', 'verbe', 'adjectifs',
      'le français', 'conjugaison', 'pluriel', 'singulier', 'pronoms',
    ],
  };

  /// هل ينتمي السؤال [q] إلى مادة [folder]؟ يُرجع false عند عدم اليقين.
  static bool _isSameSubject(Question q, String folder) {
    final words = _subjectKeywords[folder];
    if (words == null || words.isEmpty) return true; // لا نعرف => نسمح
    final hay = '${q.subject} ${q.text} ${q.options.join(' ')}';
    final normHay = _norm(hay);
    for (final w in words) {
      if (normHay.contains(_norm(w))) return true;
    }
    return false;
  }

  /// بنك المحور الكامل لحلّ [folder]: يجمع البنوك المتعلقة بالمحور فقط.
  static List<Question> poolForFolder(String folder) {
    final direct = QuestionBankLoader.questionsFor(folder) ?? const <Question>[];
    if (direct.isNotEmpty) {
      final kept = direct.where((q) => _isSameSubject(q, folder)).toList();
      if (kept.isNotEmpty) return kept;
    }
    // البنك في مفتاح واحد، فنُصفّي كله بالمادة قبل استخدامه.
    final wide = List<Question>.of(_popularBankFor(folder));
    final kept = wide.where((q) => _isSameSubject(q, folder)).toList();
    return kept.isNotEmpty ? kept : List.of(direct);
  }

  /// يعيد توزيع موضع الإجابة الصحيحة عشوائياً بين الاختيارات، مع تثبيت
  /// خيار «جميع الإجابات خاطئة» في آخر موضع لأن نصه يحيل إلى ما قبله.
  /// تطبيع خفيف للمقارنة: حذف التشكيل وتوحيد الألف والياء والتاء المربوطة.
  static String _norm(String s) {
    var t = s;
    const diac = '\u064B-\u0652\u0670\u0640';
    t = t.replaceAll(RegExp('[$diac]'), '');
    t = t
        .replaceAll('\u0623', '\u0627')
        .replaceAll('\u0625', '\u0627')
        .replaceAll('\u0622', '\u0627')
        .replaceAll('\u0624', '\u0648')
        .replaceAll('\u0626', '\u064a')
        .replaceAll('\u0649', '\u064A')
        .replaceAll('\u0629', '\u0647')
        .replaceAll('\u0621', '\u0627')
        .replaceAll(RegExp(r'[^\u0620-\u064AA-Za-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return t;
  }

  static Set<String> _words(String s) => _norm(s)
      .split(' ')
      .where((w) => w.length > 2)
      .toSet();

  /// تشابه Jaccard بين مجموعتَي كلمات.
  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final inter = a.intersection(b).length;
    final uni = a.union(b).length;
    return uni == 0 ? 0 : inter / uni;
  }

  /// خيار مشتّت مقبول فقط إذا اختلف فعلياً عن الصحيح وعن مشتّتَيه.
  ///
  /// بدون هذا الشرط تصير الخيارات متنوّعة لفظياً وصحيحة معاً في آن واحد،
  /// فتصبح الإجابة الصحيحة ملتبسة.
  static bool _isDistinctDistractor(
    String cand,
    String correct,
    Set<String> correctWords,
    List<String> accepted,
  ) {
    final n = _norm(cand);
    if (n.isEmpty) return false;
    // مطابقة تامة بعد التطبيع => مكرّر.
    if (n == _norm(correct)) return false;
    final cw = _words(cand);
    if (cw.isEmpty) return false;
    // تشابه عالٍ مع الصحيح => إعادة صياغة للإجابة الصحيحة.
    if (_jaccard(cw, correctWords) >= 0.6) return false;
    // تشابه عالٍ مع مشتّت سابق => تكرار بين الخيارات.
    for (final a in accepted) {
      if (_jaccard(cw, _words(a)) >= 0.75) return false;
    }
    return true;
  }

  static Question withShuffledOptions(Question q) {
    final opts = List<String>.of(q.options);
    if (opts.length < 2 || q.correctIndex >= opts.length) return q;

    // 1) توحيد صيغ «كل الأجوبة السابقة خاطئة».
    normalizeAllWrong(opts);

    // 2) هل العبارة الإلزامية هي الإجابة الصحيحة في هذا السؤال؟
    final rawCorrect = opts[q.correctIndex];
    final noneIsCorrect =
        isAllWrong(rawCorrect) || rawCorrect == frenchAllWrongOption;

    // 3) مشتّتات = بقية الخيارات، نزع كل نسخة من العبارة الإلزامية منها.
    final distractors = <String>[];
    for (var i = 0; i < opts.length; i++) {
      if (i == q.correctIndex) continue;
      final v = opts[i].trim();
      if (v.isEmpty) continue;
      if (isAllWrong(v) || v == frenchAllWrongOption) continue;
      distractors.add(v);
    }

    // 4) الإجابة الصحيحة الحقيقية (نصّ من البنك) إن وُجدت بين المشتّتات.
    //    نبنيها أولاً ثم نكمل المشتّتات، فالصحيحة يجب أن تكون أحد الثلاثة.
    String? correctText;
    if (!noneIsCorrect) {
      final n = _norm(rawCorrect);
      for (final d in distractors) {
        if (_norm(d) == n) {
          correctText = d;
          break;
        }
      }
      if (correctText == null) correctText = rawCorrect;
    }

    // 5) نختار المشتّتات: 2 فقط إن كانت الصحيحة من الثلاثة، أو 3 إن كانت
    //    الإجابة هي العبارة الإلزامية.
    final wantDistractors = noneIsCorrect ? 3 : 2;
    final correctWords =
        correctText == null ? <String>{} : _words(correctText!);
    final chosen = <String>[];
    final seenNorm = <String>{};
    if (correctText != null) seenNorm.add(_norm(correctText!));

    for (final d in distractors) {
      if (chosen.length >= wantDistractors) break;
      final n = _norm(d);
      if (n.isEmpty || seenNorm.contains(n)) continue;
      if (!_isDistinctDistractor(d, correctText ?? '', correctWords, chosen)) {
        continue;
      }
      seenNorm.add(n);
      chosen.add(d);
    }

    // 6) حشو إن لم تتوفّر مشتّتات كافية (نادر جداً في بنك صحيح).
    var guard = 1;
    while (chosen.length < wantDistractors) {
      final g =
          '\u062e\u064a\u0627\u0631 \u0627\u0642\u062a\u0631\u0627\u062d\u064a '
          '\u0627\u062e\u0631\u0649 \u0645\u0646 \u0627\u0644\u0645\u0627\u062f\u0631\u0633';
      final cand = '$g $guard';
      final n = _norm(cand);
      guard++;
      if (n.isEmpty || seenNorm.contains(n)) continue;
      seenNorm.add(n);
      chosen.add(cand);
      if (guard > 8) break;
    }

    // 7) ترتيب الثلاثة الحقيقية: الصحيحة + المشتّتات، ثم خلط.
    final real = <String>[
      if (correctText != null) correctText,
      ...chosen,
    ];
    for (int i = real.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final t = real[i];
      real[i] = real[j];
      real[j] = t;
    }

    // 8) التركيب النهائي: ثلاثة حقيقية + العبارة الإلزامية في آخر موضع.
    final out = <String>[...real.take(3), allWrongOption];

    // 9) الفهرس الصحيح يُحلّ من القائمة النهائية، مع تحقق.
    int ci;
    if (noneIsCorrect) {
      ci = 3; // العبارة الإلزامية صحيحة-by-design => موضعها الأخير.
    } else if (correctText != null) {
      final want = _norm(correctText!);
      ci = out.indexWhere((o) => _norm(o) == want);
      if (ci < 0) ci = out.length - 1; // احتياط: لا -1 أبداً.
    } else {
      ci = _random.nextInt(3); // لا نعرف الصحيح => موضع عشوائي آمن.
    }

    return Question(
      id: 'gen_${q.text.hashCode}',
      subject: q.subject,
      level: q.level,
      text: q.text,
      options: out,
      correctIndex: ci,
      explanation: q.explanation,
      source: q.source,
      situation: q.situation,
    );
  }

  /// يعيد عدد أسئلة البنك المتاحة لمحور [folder] / موضوع [topic].
  static int bankCountFor(String folder, {String? topic}) {
    if (topic != null) {
      final matched = poolForFolder(folder)
          .where((q) => _matchesTopic(q, topic))
          .length;
      if (matched > 0) return matched;
    }
    return poolForFolder(folder).length;
  }

  static List<Question> _popularBankFor(String folder) {
    // لا محور معروف: نجمع ما يطابق النص، وإلا نُرجع كل بنك المادة فقط.
    if (folder == 'التشريع المدرسي') {
      return QuestionBankLoader.questionsFor('التشريع المدرسي والإداري') ?? const [];
    }
    if (folder == 'ديداكتيك اللغة الفرنسية') {
      final all = <Question>[];
      for (final key in QuestionBankLoader.bank.keys) {
        if (key.contains('الفرنسية') || key.contains('français') || key.contains('FLE')) {
          all.addAll(QuestionBankLoader.questionsFor(key) ?? const []);
        }
      }
      return all;
    }
    if (folder == 'التنشيط التربوي') {
      final all = <Question>[];
      for (final key in ['التنشيط التربوي', 'البيداغوجيا والتشريع', 'علوم التربية']) {
        all.addAll(QuestionBankLoader.questionsFor(key) ?? const []);
      }
      return all.where((q) => !_isOffTopic(q.text, 'علوم التربية')).toList();
    }
    if (folder == 'علوم التربية') {
      final all = <Question>[];
      for (final key in QuestionBankLoader.bank.keys) {
        if (key.contains('علوم التربية') ||
            key.contains('نظريات التعلم') ||
            key.contains('النمو') ||
            key.contains('سيكولوجيا التربية') ||
            key.contains('صعوبات التعلم') ||
            key.contains('سوسيولوجيا التربية') ||
            key.contains('التقويم والدعم')) {
          all.addAll(QuestionBankLoader.questionsFor(key) ?? const []);
        }
      }
      return all.where((q) => !_isOffTopic(q.text, 'علوم التربية')).toList();
    }
    if (folder == 'ديداكتيك النشاط العلمي') {
      final all = <Question>[];
      all.addAll(QuestionBankLoader.questionsFor('ديداكتيك النشاط العلمي') ?? const []);
      all.addAll(QuestionBankLoader.questionsFor('النشاط العلمي') ?? const []);
      return all;
    }
    final subject = _popularSubjectFor(folder);
    if (subject == null) return const [];
    return QuestionBankLoader.questionsFor(subject) ?? const [];
  }

  static String? _popularSubjectFor(String folder) {
    const subjectByFolder = {
      'علوم التربية': 'علوم التربية',
      'ديداكتيك اللغة العربية': 'ديداكتيك اللغة العربية',
      'ديداكتيك اللغة الفرنسية': 'ديداكتيك الفرنسية',
      'ديداكتيك الرياضيات': 'ديداكتيك الرياضيات',
      'ديداكتيك النشاط العلمي': 'ديداكتيك النشاط العلمي',
      'التشريع المدرسي': 'التشريع المدرسي',
      'التنشيط التربوي': 'التنشيط التربوي',
      'مؤسسات الريادة': 'مؤسسات الريادة',
      'مشروع المؤسسة المندمج': 'مؤسسات الريادة',
    };
    return subjectByFolder[folder];
  }

  /// يحول نصاً خاماً إلى أسئلة بنمط امتحان الكفاءة المهنية.
  static List<Question> generateFromText(String text,
      {required String folder, int count = 50}) {
    if (text.trim().length < 40) return [];
    final sentences = _splitSentences(text);
    if (sentences.isEmpty) return [];

    final french = _looksFrench(text);
    final questions = <Question>[];

    // 1) أسئلة التعريف.
    final definitions = _extractDefinitions(sentences, french: french);
    final canAllWrong = definitions.length >= 5;
    if (definitions.length >= 4) {
      definitions.shuffle(_random);
      for (var i = 0; i < definitions.length && questions.length < count; i++) {
        final entry = definitions[i];
        final others = definitions
            .where((d) => d.term != entry.term)
            .toList()
          ..shuffle(_random);
        final wantAllWrong =
            canAllWrong && _random.nextDouble() < allWrongChance;
        if (i.isEven) {
          final distractors = others.take(4).map((d) => d.definition).toList();
          if (wantAllWrong && distractors.length >= 4) {
            questions.add(
                _definitionAllWrongQuestion(folder, entry, distractors, french));
            continue;
          }
          if (distractors.length < 3) continue;
          questions.add(_definitionQuestion(
              folder, entry, distractors.take(3).toList(), french));
        } else {
          final distractors = others.take(4).map((d) => d.term).toList();
          if (wantAllWrong && distractors.length >= 4) {
            questions.add(
                _termAllWrongQuestion(folder, entry, distractors, french));
            continue;
          }
          if (distractors.length < 3) continue;
          questions.add(
              _termQuestion(folder, entry, distractors.take(3).toList(), french));
        }
      }
    }

    // 2) أسئلة الفهم والتحليل.
    if (questions.length < count) {
      final claims = <String>{};
      for (final s in sentences) {
        final core = _coreClaim(s);
        if (core != null) claims.add(core);
      }
      final negatable = claims
          .where((c) => _negationOf(c, french) != null)
          .toList()
        ..shuffle(_random);
      final shuffled = claims.toList()..shuffle(_random);
      for (var i = 0; i < shuffled.length && questions.length < count; i++) {
        final claim = shuffled[i];
        final others =
            shuffled.where((c) => c != claim).toList()..shuffle(_random);
        final distractors = others.take(3).toList();
        if (distractors.length < 3) continue;
        final wantAllWrong = _random.nextDouble() < allWrongChance;
        if (wantAllWrong) {
          final falseOptions = <String>[];
          final trueClaims = <String>[];
          for (final c in negatable) {
            if (c == claim) continue;
            final neg = _negationOf(c, french);
            if (neg == null || claims.contains(neg)) continue;
            if (falseOptions.contains(neg)) continue;
            falseOptions.add(neg);
            trueClaims.add(c);
            if (falseOptions.length == 4) break;
          }
          if (falseOptions.length == 4) {
            questions.add(_comprehensionAllWrongQuestion(
                folder, falseOptions, trueClaims, french));
            continue;
          }
        }
        questions.add(
            _comprehensionQuestion(folder, claim, distractors, french));
      }
    }

    questions.shuffle(_random);
    if (questions.length > count) return questions.take(count).toList();
    return questions;
  }

  // ---------------- صياغة الأسئلة ----------------

  static Question _definitionQuestion(String folder, _Definition entry,
      List<String> distractors, bool french) {
    final opts = [entry.definition, ...distractors.take(3)]..shuffle(_random);
    final options = opts.map(_cleanOption).toList();
    return Question(
      id: 'def_${entry.term.hashCode}',
      subject: folder,
      text: french
          ? 'D\'après le texte, que signifie « ${_cleanOption(entry.term)} » ?'
          : 'ما المقصود بمصطلح « ${_cleanOption(entry.term)} » وفق النص؟',
      options: options,
      correctIndex: options.indexOf(_cleanOption(entry.definition)),
      explanation:
          '${_cleanOption(entry.term)}: ${_cleanOption(entry.definition)}',
    );
  }

  static Question _termQuestion(String folder, _Definition entry,
      List<String> distractors, bool french) {
    final opts = [entry.term, ...distractors.take(3)]..shuffle(_random);
    final options = opts.map(_cleanOption).toList();
    return Question(
      id: 'term_${entry.term.hashCode}',
      subject: folder,
      text: french
          ? 'Selon le texte, quel terme désigne : « ${_cleanOption(entry.definition)} » ?'
          : 'وفق النص، ما المصطلح الذي يُقصد به: « ${_cleanOption(entry.definition)} »؟',
      options: options,
      correctIndex: options.indexOf(_cleanOption(entry.term)),
      explanation:
          '${_cleanOption(entry.term)}: ${_cleanOption(entry.definition)}',
    );
  }

  static Question _comprehensionQuestion(
      String folder, String claim, List<String> distractors, bool french) {
    final opts = [claim, ...distractors.take(3)]..shuffle(_random);
    final options = opts.map(_cleanOption).toList();
    return Question(
      id: 'comp_${claim.hashCode}',
      subject: folder,
      text: french
          ? 'D\'après le texte, laquelle de ces affirmations est correcte ?'
          : 'وفق النص، أي عبارة مما يلي صحيحة؟',
      options: options,
      correctIndex: options.indexOf(_cleanOption(claim)),
      explanation: _cleanOption(claim),
    );
  }

  static Question _definitionAllWrongQuestion(String folder, _Definition entry,
      List<String> distractors, bool french) {
    // Convert to regular 4-option question (correct answer is the definition)
    return _definitionQuestion(folder, entry, distractors, french);
  }

  static Question _termAllWrongQuestion(String folder, _Definition entry,
      List<String> distractors, bool french) {
    // Convert to regular 4-option question (correct answer is the term)
    return _termQuestion(folder, entry, distractors, french);
  }

  static Question _comprehensionAllWrongQuestion(String folder,
      List<String> falseOptions, List<String> trueClaims, bool french) {
    // Use first true claim as correct answer with 3 false options
    if (trueClaims.isEmpty || falseOptions.length < 3) {
      return _comprehensionQuestion(
          folder, '', falseOptions.take(3).toList(), french);
    }
    final claim = trueClaims.first;
    return _comprehensionQuestion(
        folder, claim, falseOptions.take(3).toList(), french);
  }

  // ---------------- تنظيف الخيارات من الرموز المشوهة ----------------

  /// ينظف خياراً واحداً من الرموز الغريبة والنصوص المشوهة:
  ///  - يزيل الحروف الصينية/الكانتونية (CJK).
  ///  - يزيل علامات الترقيم العالقة في الطرفين.
  ///  - يزيل النصوص الإنجليزية العالقة داخل النص العربي.
  ///  - يقصّر الخيار إذا تجاوز 200 حرف.
  static String _cleanOption(String raw) {
    var s = raw.trim();
    // إزالة الحروف الصينية/اليابانية/الكوري (CJK Unified Ideographs).
    s = s.replaceAll(RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF]'), '');
    // إزالة علامات الترقيم العالقة في الطرفين.
    s = s.replaceAll(RegExp(r'^[\s،,·:：\-–—]+|[\s،,·:：\-–—]+$', unicode: true), '');
    // إزالة النقاط العالقة في النهاية (لا نريد نقاط جزئية).
    s = s.replaceAll(RegExp(r'[.؟!]+\s*$'), '');
    // إزالة علامات الاقتباس غير المتناسقة.
    s = s.replaceAll(RegExp(r'^["«»]|["«»]$'), '');
    // تقليص الحد الأقصى.
    if (s.length > 200) s = '${s.substring(0, 197)}...';
    return s;
  }

  // ---------------- نفي العبارات لبناء خيارات خاطئة ----------------

  static final RegExp _arNegatableStart = RegExp(
    r'^(?:يعد|تعد|يُعد|يُعدّ|تُعدّ|يعتبر|يُعتبر|تعتبر|تُعتبر|تشكل|تُمثّل|تمثل|يمثل|يجب|ينبغي|يُشترط|يشترط|يتطلب|تتطلب|يتم|تتم|تُجرى|تساهم|يساهم|تساعد|يساعد|يسمح|تسمح|يحقق|تحقق|يرتبط|ترتبط|يستند|تستند|يواكب|تواكب|يراعي|تراعي|يعتمد|ينطلق|تنطلق|يؤدي|تؤدي|يمكن|يجوز)\s',
  );

  static final RegExp _frNegatableStart = RegExp(
    r'^(?:constitue|représente|désigne|signifie|favorise|privilégie|permet|développe|repose|occupe|aide|assure|garantit|exige|implique|facilite|vise)\s',
    caseSensitive: false,
  );

  static String? _negationOf(String claim, bool french) {
    if (claim.trim().isEmpty) return null;
    if (french) {
      final m = _frNegatableStart.firstMatch(claim);
      if (m != null) {
        final verb = m.group(0)!.trim();
        final rest = claim.substring(m.end).trimLeft();
        return 'Ne $verb pas $rest';
      }
      return 'Il est faux d\'affirmer que $claim';
    }
    if (claim.startsWith('لا ') || claim.startsWith('لم ')) {
      return 'ليس من الصحيح وفق النص أن $claim';
    }
    if (_arNegatableStart.hasMatch(claim)) return 'لا $claim';
    return 'ليس من الصحيح وفق النص أن $claim';
  }

  // ---------------- استخراج التعاريف من النص ----------------

  static List<_Definition> _extractDefinitions(List<String> sentences,
      {required bool french}) {
    final seen = <String>{};
    final result = <_Definition>[];
    for (final s in sentences) {
      final entry =
          french ? _extractFrenchDefinition(s) : _extractArabicDefinition(s);
      if (entry == null) continue;
      if (entry.term.length < 3 || entry.definition.length < 8) continue;
      if (entry.definition.length > 220) continue;
      if (!seen.add('${entry.term}|${entry.definition}')) continue;
      result.add(_Definition(_cleanOption(entry.term), _cleanOption(entry.definition)));
    }
    return result;
  }

  static final RegExp _arTermFirst = RegExp(
    r'^\s*(?<term>.{2,40}?)\s+(?:هو|هي|يعني|تعني|يمثل|تمثل|عبارة عن)\s+(?<def>.+)$',
  );

  static final RegExp _arMarkerFirst = RegExp(
    r'^\s*(?:يعد|تعد|يعتبر|يُعتبر|تعتبر|تشكل|يمثل|تمثل)\s+(?<term>\S+(?:\s+\S+)?)\s+(?<def>.+)$',
  );

  static final RegExp _arYeqsad = RegExp(
    r'^\s*(?:يقصد|يُقصد|نقصد)\s+(?:بمصطلح|بمفهوم|ب)\s+(?<term>.{2,40}?)\s+(?<def>.+)$',
  );

  static final RegExp _arYuRraf = RegExp(
    r'^\s*(?:يُعرَّف|يعرَّف|يعرف|يُعرَف|تعرف|تُعرَّف)\s+(?<term>.{2,40}?)\s+(?:بأنه|بأنها|على أنه|على أنها)\s+(?<def>.+)$',
  );

  static final RegExp _arTaRrif = RegExp(
    r'^\s*(?:تعريف|مفهوم)\s+(?<term>.{2,40}?)\s+(?:هو|هي|يعني|تعني)\s+(?<def>.+)$',
  );

  static _Definition? _extractArabicDefinition(String s) {
    final candidates = [_arTermFirst, _arMarkerFirst, _arYeqsad, _arYuRraf, _arTaRrif];
    for (final re in candidates) {
      final m = re.firstMatch(s);
      if (m == null) continue;
      final term = _cleanTerm(m.namedGroup('term') ?? '');
      final def = _cleanDef(m.namedGroup('def') ?? '');
      if (term.isEmpty || def.isEmpty) continue;
      if (_badTerm.hasMatch(term)) continue;
      return _Definition(term, def);
    }
    return null;
  }

  static final RegExp _badTerm = RegExp(r'الذي|التي|الذين|اللاتي|أنه|أنها|لأنه|بأنه');

  static final RegExp _frTermFirst = RegExp(
    r'^\s*(?<term>.{2,40}?)\s+(?:est défini comme|se définit comme|signifie|désigne|représente|constitue|désigné par)\s+(?<def>.+)$',
    caseSensitive: false,
  );

  static final RegExp _frParOnEntend = RegExp(
    r'^\s*par\s+(?<term>.{2,40}?)\s*,?\s*on entend\s+(?<def>.+)$',
    caseSensitive: false,
  );

  static _Definition? _extractFrenchDefinition(String s) {
    for (final re in [_frTermFirst, _frParOnEntend]) {
      final m = re.firstMatch(s);
      if (m == null) continue;
      final term = _cleanTerm(m.namedGroup('term') ?? '');
      final def = _cleanDef(m.namedGroup('def') ?? '');
      if (term.isEmpty || def.isEmpty) continue;
      return _Definition(term, def);
    }
    return null;
  }

  static String _cleanTerm(String raw) {
    var t = raw
        .trim()
        .replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');
    // إزالة الحروف الصينية.
    t = t.replaceAll(RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF]'), '');
    final words = _tokens(t);
    if (words.isEmpty) return '';
    return words.take(6).join(' ');
  }

  static String _cleanDef(String raw) {
    var d = raw
        .trim()
        .replaceAll(RegExp(r'^[،,\s]+|[.!?؟؛\s]+$', unicode: true), '');
    // إزالة الحروف الصينية.
    d = d.replaceAll(RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF]'), '');
    return d;
  }

  static String? _coreClaim(String s) {
    var t = s.trim();
    t = t.replaceFirst(
        RegExp(r'^(وفي|وأن|وقد|إن|لذلك|ولهذا|كما|بينما|عندما|حيث|ومن|فإن|أن)\s+'),
        '');
    var words = _tokens(t);
    if (words.length > 16) words = words.take(16).toList();
    return words.join(' ');
  }

  // ---------------- أدوات معالجة النص ----------------

  static List<String> _tokens(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  static String _cleanWord(String w) =>
      w.replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');

  static final RegExp _arabicLetter = RegExp(r'[\u0621-\u064A\u0671-\u06D3]');
  static final RegExp _latinLetter = RegExp(r'[a-zA-Z\u00C0-\u00FF]');

  static bool _looksFrench(String text) {
    var latin = 0;
    var arabic = 0;
    for (final w in _tokens(text)) {
      final t = _cleanWord(w);
      if (t.isEmpty) continue;
      if (_latinLetter.hasMatch(t)) latin++;
      if (_arabicLetter.hasMatch(t)) arabic++;
    }
    return latin >= 5 && latin > arabic;
  }

  static bool _isContentWord(String w) {
    if (w.length < 4) return false;
    if (w.contains(RegExp(r'[0-9]'))) return false;
    if (_arabicLetter.hasMatch(w)) {
      if (_stopwords.contains(w)) return false;
      return true;
    }
    if (_latinLetter.hasMatch(w)) {
      if (_frStopwords.contains(w)) return false;
      return true;
    }
    return false;
  }

  static List<String> _splitSentences(String text) {
    final raw = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'[.!?؟؛\n\r]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final result = <String>[];
    for (final s in raw) {
      final toks = _tokens(s);
      final content = toks.where((w) => _isContentWord(_cleanWord(w))).length;
      if (toks.length >= 5 && content >= 3) result.add(s);
    }
    return result;
  }

  static const Set<String> _stopwords = {
    'التي', 'الذي', 'الذين', 'اللاتي', 'على', 'من', 'في', 'إلى', 'عن', 'مع',
    'كان', 'كانت', 'كانوا', 'هو', 'هي', 'هذا', 'هذه', 'ذلك', 'تلك', 'هؤلاء',
    'وهو', 'وهي', 'كما', 'بين', 'قد', 'لم', 'لن', 'لا', 'ما', 'منه', 'منها',
    'أن', 'إن', 'بأن', 'لكن', 'ولكن', 'فإن', 'إذا', 'حيث', 'حتى', 'إلا',
    'بعد', 'قبل', 'عند', 'عندما', 'عليه', 'عليها', 'له', 'لها', 'لهم', 'فهو',
    'فهي', 'غير', 'أو', 'بل', 'ثم', 'فيه', 'فيها', 'لقد', 'وقد', 'ومن', 'وفي',
    'عبر', 'ضمن', 'خلال', 'أثناء', 'بما', 'مما', 'إما', 'هناك', 'هنا', 'الآن',
    'إذ', 'إذن', 'حين', 'أي', 'أيضا', 'أيضاً', 'بشكل', 'بينما', 'ليس', 'ليست',
    'يكون', 'تكون', 'يعد', 'تعد', 'يعتبر', 'تعتبر', 'تشكل', 'يمثل', 'تمثل',
    'نحو', 'لأن', 'لأنه', 'لأنها', 'أنه', 'أنها', 'منذ', 'مثل', 'حسب', 'بدون',
    'إضافة', 'بالإضافة', 'يتم', 'تتم', 'تم', 'سيتم', 'بالنسبة', 'المتعلقة',
    'المتعلق', 'لذلك', 'حيثما', 'به', 'بها', 'بهذا', 'بهذه',
    'وما', 'فما', 'فقط', 'ستكون', 'سيكون',
  };

  static const Set<String> _frStopwords = {
    'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'au', 'aux', 'ce',
    'ces', 'cet', 'cette', 'et', 'ou', 'est', 'sont', 'que', 'qui', 'dont',
    'dans', 'pour', 'par', 'sur', 'avec', 'sans', 'sous', 'chez', 'entre',
    'vers', 'depuis', 'pendant', 'comme', 'mais', 'donc', 'car', 'ni', 'si',
    'se', 'sa', 'ses', 'son', 'leur', 'leurs', 'mon', 'ma', 'mes', 'ton',
    'ta', 'tes', 'notre', 'votre', 'je', 'tu', 'il', 'elle', 'on', 'nous',
    'vous', 'ils', 'elles', 'ne', 'pas', 'plus', 'moins', 'très', 'peu',
    'aussi', 'tout', 'tous', 'toute', 'toutes', 'rien', 'aucun', 'aucune',
    'quelque', 'quelques', 'être', 'avoir', 'fait', 'faire', 'faites',
    'fais', 'déjà', 'plusieurs', 'cependant', 'notamment', 'ainsi', 'alors',
    'où', 'quand', 'quoi', 'là', 'etc', 'etc.', 'après', 'avant', 'contre',
    'malgré', 'selon', 'durant', 'plutôt', 'presque', 'environ', 'même',
    'mêmes', 'autre', 'autres', 'peut', 'peuvent', 'pouvoir',
  };

  /// يتحقق هل السؤال خارج نطاق المحور المعطى بناءً على كلمات المفتاحية في النص.
  static bool _isOffTopic(String text, String folder) {
    final lower = text.toLowerCase();
    if (folder == 'علوم التربية') {
      if (lower.contains('مجالس المؤسسة') || lower.contains('مجلس الإدارة') ||
          lower.contains('مجلس التأطير') || lower.contains('نوعيات المجالس') ||
          lower.contains('رئاسة المجلس') || lower.contains('أعضاء المجلس') ||
          lower.contains('مجالس المؤسسات التعليمية')) {
        return true;
      }
    }
    return false;
  }
}

/// زوج (مصطلح، تعريف) مستخرج من نص الوثيقة.
class _Definition {
  final String term;
  final String definition;
  const _Definition(this.term, this.definition);
}
