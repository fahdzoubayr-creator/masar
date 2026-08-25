import 'dart:math';

import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/question_validator.dart';

/// يسحب أسئلة اختيار من متعدد من بنك الأسئلة (PopularBankData + WadiaaBankData).
///
/// لا يُولّد أي سؤال من النصوص — يأخذ الأسئلة حصرياً من البنوك الموجودة.
class QuestionGenerator {
  static const String allWrongOption = 'كل الاقتراحات خاطئة';
  static const String frenchAllWrongOption =
      'Toutes les réponses ci-dessus sont fausses.';

  /// نسبة الأسئلة التي يكون جوابها الصحيح «جميع الاختيارات أعلاه خاطئة».
  static const double allWrongChance = 0.7;

  static final Random _random = Random();

  // ---------------- سحب الأسئلة من البنوك ----------------

  /// يسحب حتى [count] سؤالاً لمحور [folder] (افتراضياً 70 سؤالاً).
  /// يأخذ الأسئلة حصرياً من بنك الأسئلة (PopularBankData + WadiaaBankData)
  /// ولا يُولّد أي سؤال من النصوص.
  static Future<List<Question>> generateForFolder(String folder,
      {String? topic, int count = 70}) async {
    final pool = <Question>[];
    final seen = <String>{};
    void addAll(List<Question> questions) {
      for (final q in questions) {
        if (seen.add(q.text)) pool.add(q);
      }
    }

    // 1) بنك المجلد/الموضوع (أسئلة الكفاءة المهنية المصاغة يدوياً).
    final folderBank = QuestionBankLoader.questionsFor(folder);
    final topicBank =
        topic != null ? QuestionBankLoader.questionsFor(topic) : null;
    final effectiveBank =
        (folderBank != null && folderBank.isNotEmpty) ? folderBank : topicBank;
    if (effectiveBank != null) addAll(effectiveBank);

    // 2) بنك الأسئلة الشائعة (PopularBankData) — subject-filtered when topic is specified.
    if (pool.length < count) {
      final popular = _popularBankFor(folder);
      if (topic != null) {
        // Filter popular pool to only include questions whose subject matches the topic.
        final topicFiltered = popular.where((q) =>
            q.subject == topic ||
            q.subject.contains(topic) ||
            topic.contains(q.subject)).toList();
        // Use topic-filtered pool first; only fall back to full pool if still short.
        if (topicFiltered.isNotEmpty) {
          addAll(topicFiltered);
        }
        if (pool.length < count) {
          addAll(popular);
        }
      } else {
        addAll(popular);
      }
    }

    // خلط واختيار العدد
    final validPool = QuestionValidator.filterValid(pool);
    validPool.shuffle(_random);
    final result =
        (validPool.length > count ? validPool.sublist(0, count) : validPool)
            .map(withShuffledOptions)
            .toList();
    return result;
  }

  /// يعيد توزيع موضع الإجابة الصحيحة عشوائياً بين الاختيارات، مع تثبيت
  /// خيار «جميع الإجابات خاطئة» في آخر موضع لأن نصه يحيل إلى ما قبله.
  static Question withShuffledOptions(Question q) {
    final opts = List<String>.of(q.options);
    if (opts.length < 2 || q.correctIndex >= opts.length) return q;
    String? pinned;
    for (final special in const [allWrongOption, frenchAllWrongOption]) {
      final i = opts.indexOf(special);
      if (i >= 0) {
        pinned = opts.removeAt(i);
        break;
      }
    }
    for (int i = opts.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final t = opts[i];
      opts[i] = opts[j];
      opts[j] = t;
    }
    if (pinned != null) opts.add(pinned);
    return Question(
      subject: q.subject,
      level: q.level,
      text: q.text,
      options: opts,
      correctIndex: opts.indexOf(q.options[q.correctIndex]),
      explanation: q.explanation,
      source: q.source,
      situation: q.situation,
    );
  }

  /// يعيد عدد أسئلة البنك المتاحة لمحور [folder] / موضوع [topic].
  static int bankCountFor(String folder, {String? topic}) {
    final folderBank = QuestionBankLoader.questionsFor(folder);
    final topicBank = topic != null ? QuestionBankLoader.questionsFor(topic) : null;
    final effective =
        (folderBank != null && folderBank.isNotEmpty) ? folderBank : topicBank;
    var count = effective?.length ?? 0;
    count += _popularBankFor(folder).length;
    return count;
  }

  static List<Question> _popularBankFor(String folder) {
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
      for (final key in ['التنشيط التربوي', 'المجالس التعليمية', 'المهارات الحياتية']) {
        all.addAll(QuestionBankLoader.questionsFor(key) ?? const []);
      }
      return all;
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
      'التشريع المدرسي': 'التشريع المدرسي والتنظيمي',
      'التنشيط التربوي': 'التنشيط التربوي',
      'مؤسسات الريادة': 'مؤسسة الريادة — مقاربة TaRL',
      'مشروع المؤسسة المندمج': 'مشروع المؤسسة المندمج',
    };
    return subjectByFolder[folder];
  }

  /// يحول نصاً خاماً إلى أسئلة بنمط امتحان الكفاءة المهنية.
  static List<Question> generateFromText(String text,
      {required String folder, int count = 70}) {
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
