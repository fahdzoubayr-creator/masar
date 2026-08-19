import 'dart:math';

import 'package:masar_app/core/data/popular_bank_data.dart';
import 'package:masar_app/core/data/wadiaa_bank_data.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/review_file_service.dart';

/// يولّد أسئلة اختيار من متعدد تلقائياً من النصوص المستخرجة من ملفات
/// المحور الفرعي (الموجودة في مجلدات assets/review_files).
///
/// صيغ الأسئلة بنمط امتحانات الكفاءة المهنية:
///  - كل سؤال يبدأ بـ「وضعية»: سيناريو مشكلة مهنية أو سياق تشريعي/ديداكتيكي.
///  - ثم سؤال مباشر عن الإجراء الأنسب.
///  - 5 خيارات (أ، ب، ج، د، هـ) — الخامس دائماً «جميع الاختيارات أعلاه خاطئة».
///  - في نحو 70% من الأسئلة يكون الجواب الصحيح هو الخيار الخامس، لكن بشروط
///    تضمن سلامة السؤال: تُعرض حينها 4 خيارات خاطئة فعلياً.
class QuestionGenerator {
  static const String allWrongOption = 'جميع الاختيارات أعلاه خاطئة';
  static const String frenchAllWrongOption =
      'Toutes les réponses ci-dessus sont fausses.';

  /// نسبة الأسئلة التي يكون جوابها الصحيح «كل الإجابات خاطئة» في التوليد
  /// من الملفات، محاكاةً لامتحانات الكفاءة المهنية.
  static const double allWrongChance = 0.7;

  static final Random _random = Random();

  // ---------------- إثراء الأسئلة بالوضعيات تلقائياً ----------------

  /// خريطة الوضعيات حسب المادة — تُستخدم لتوليد وضعية ملائمة لكل سؤال.
  static const Map<String, List<String>> _situationBySubject = {
    'نظريات التعلم والمقاربات البيداغوجية': [
      'أثناء متابعتك لمحاضرة في نظريات التعلم والمقاربات البيداغوجية، واجهت صعوبة في التمييز بين المفاهيم الأساسية التي تطرحها كل نظرية.',
      'في إطار حصة تكوينية حول نظريات التعلم، لاحظ التلميذ تداخل المفاهيم بين الإشراط الكلاسيكي والفعال.',
      'أثناء إعداد حصة للتعليم البيني، واجهت تحدياً في ربط المفاهيم النظرية بالممارسة الصفية الفعلية.',
    ],
    'النمو واستراتيجيات اكتساب الفهم': [
      'أثناء ملاحظتك لسلوك مجموعة من المتعلمين في الفصل، لاحظت تفاوتاً واضحاً في مراحل النمو المعرفي والجسمي.',
      'في إطار تفعيل استراتيجيات اكتساب الفهم، واجهت صعوبة في تكييف المهام مع مستوى النمو لدى المتعلمين.',
    ],
    'سيكولوجيا التربية وتقاطعاتها': [
      'أثناء تدبيرك للحراسة الإجبارية، لاحظت سلوكاً يثير قلقك بشأن أحد المتعلمين يتعلق بالتوتر والخوف.',
      'في إطار تفعيل البيداغوجيا الفارقية، واجهت تحدياً مرتبطاً بالتعامل مع خصوصيات كل متعلم.',
    ],
    'صعوبات التعلم وعوائقه': [
      'أثناء متابعتك لمجموعة من المتعلمين المتعثرين في الفصل، لاحظت أن بعضهم يعاني من صعوبات تتعلق بالقراءة والكتابة.',
      'في إطار التشخيص المبكر لصعوبات التعلم، واجهت صعوبة في تحديد الإجراءات العلاجية المناسبة.',
    ],
    'سوسيولوجيا التربية وسيكوسوسيولوجيا التربية': [
      'أثناء دراستك للبيئة الاجتماعية للمتعلمين، لاحظت تأثير العوامل الاجتماعية على التحصيل الدراسي.',
      'في إطار تفعيل العلاقة بين المدرسة والأسرة والمجتمع، واجهت تحدياً في إشراك الأسر في العملية التعليمية.',
    ],
    'التقويم والدعم التربويان': [
      'أثناء تدبيرك للتقويم التشخيصي في بداية الموسم الدراسي، لاحظت نتائج تكشف عن فوارق كبيرة بين المتعلمين.',
      'في إطار تفعيل التقويم التنموي، واجهت صعوبة في تحديد معايير التقدير المناسبة.',
    ],
    'الإصلاح التربوي والسياسة التعليمية': [
      'أثناء تطبيق النصوص التنظيمية الجديدة، لاحظت صعوبة في فهم الإطار القانوني المؤطر للمهنة.',
      'في إطار متابعة مستجدات الإصلاح التربوي، واجهت تحدياً في تكييف الممارسة مع المستجدات.',
    ],
    'تخطيط وتدبير التعلمات': [
      'أثناء إعداد خطة علاجية للمتعلمين المتعثرين، لاحظت صعوبة في تحديد الإجراءات البيداغوجية المناسبة.',
      'في إطار تفعيل التخطيط السلوكي، واجهت تحدياً في ربط الأهداف بالنتائج التقويمية.',
    ],
    'التشريع المدرسي': [
      'أثناء تدبيرك للحياة المدرسية، واجهت موقفاً يتطلب معرفة دقيقة بالإطار القانوني المؤطر للمهنة.',
      'في إطار تفعيل النصوص التنظيمية الجديدة، لاحظت صعوبة في تطبيق المقتضيات القانونية على أرض الواقع.',
    ],
    'اللغة العربية': [
      'أثناء تدبيرك لحصة تعليمية في اللغة العربية، لاحظت صعوبة كبيرة لدى المتعلمين في استيعاب المفاهيم اللغوية المطروحة.',
      'في إطار تفعيل الديداكتيك اللغوي الحديث، واجهت تحدياً في إعداد دروس تراعي الفروق الفردية.',
    ],
    'الرياضيات': [
      'أثناء تدبيرك لحصة في مادة الرياضيات، لاحظت صعوبة كبيرة لدى المتعلمين في فهم المفاهيم الرياضية المجردة.',
      'في إطار تفعيل ديداكتيك الرياضيات الحديثة، واجهت تحدياً في إعداد دروس تراعي الفروق الفردية.',
    ],
    'النشاط العلمي': [
      'أثناء تدبيرك لحصة في مادة النشاط العلمي، لاحظت صعوبة كبيرة لدى المتعلمين في استيعاب المفاهيم العلمية التجريبية.',
      'في إطار تفعيل ديداكتيك النشاط العلمي الحديث، واجهت تحدياً في إعداد دروس تراعي الفروق الفردية.',
    ],
    'الفرنسية': [
      'Lors d\'une séquence d\'enseignement du français, vous avez constaté de grandes difficultés chez les apprenants.',
      'Dans le cadre de la didactique du français, vous avez rencontré des défis liés à l\'adaptation des activités.',
    ],
    'الأمازيغية': [
      'أثناء تدبيرك لحصة في مادة الأمازيغية، لاحظت صعوبة كبيرة لدى المتعلمين في استيعاب المفاهيم اللغوية المطروحة.',
      'في إطار تفعيل ديداكتيك الأمازيغية الحديثة، واجهت تحدياً في إعداد دروس تراعي الفروق الفردية.',
    ],
  };

  /// قوالب الوضعيات العامة (للمواد غير الموجودة في الخريطة).
  static const List<String> _genericSituations = [
    'أثناء تدبيرك لحصة تعليمية في إطار التطبيق الفعلي للمنهاج الجديد، لاحظت وجود تفاوت كبير في فهم المتعلمين للمفهوم الأساسي المطروح.',
    'في إطار تفعيل البيداغوجيا الفارقية داخل الفصل الدراسي، واجهت تحدياً مرتبطاً بالتعامل مع مجموعة غير متجانسة من المتعلمين.',
    'أثناء مراجعة نتائج التقويم التشخيصي في بداية الموسم الدراسي، تبين أن فئة مهمة من المتعلمين تعاني من إشكاليات معرفية تتطلب تدخلاً عاجلاً.',
    'في سياق تطبيق النصوص التنظيمية الجديدة المتعلقة بالحياة المدرسية، واجهت موقفاً يتطلب معرفة دقيقة بالإطار القانوني والتشريعي المؤطر للمهنة.',
    'أثناء إعداد خطة علاجية للمتعلمين المتعثرين في مادة التخصص، واجهت صعوبة في تحديد الإجراءات البيداغوجية المناسبة وفق المستجدات التربوية.',
  ];

  /// يُضيف «وضعية» تلقائية لأي سؤال لا يملكها، بناءً على مادة السؤال.
  /// يُعيد القائمة بعد الإثراء (لا يُعدّل الأصلية).
  static List<Question> enrichWithSituations(List<Question> questions) {
    return questions.map((q) {
      if (q.situation != null && q.situation!.isNotEmpty) return q;
      final situation = _situationForSubject(q.subject);
      return Question(
        subject: q.subject,
        level: q.level,
        text: q.text,
        options: q.options,
        correctIndex: q.correctIndex,
        explanation: q.explanation,
        source: q.source,
        situation: situation,
      );
    }).toList();
  }

  /// يختار وضعية مناسبة لمادة السؤال.
  static String _situationForSubject(String subject) {
    // بحث جزئي: قد يكون اسم المادة جزءاً من مفتاح الخريطة.
    for (final entry in _situationBySubject.entries) {
      if (subject.contains(entry.key) || entry.key.contains(subject)) {
        return entry.value[_random.nextInt(entry.value.length)];
      }
    }
    return _genericSituations[_random.nextInt(_genericSituations.length)];
  }

  // ---------------- توليد الأسئلة من النصوص ----------------

  /// يولد حتى [count] سؤالاً لمحور [folder] (افتراضياً 70 سؤالاً).
  ///
  /// أولوية التوليد من ملفات المحور النصية (المستخرجة من ملفات PDF لكل
  /// محور) بنمط أسئلة الكفاءة المهنية، لأنها الأقرب إلى مرجعية المراجعة
  /// الفعلية؛ فإن لم تكفِ لبلوغ [count] يُستكمل ببنك أسئلة الوضعيات الجاهز
  /// (WadiaaBankData) عند وجوده — تُبحث الأسئلة أولاً بعنوان المحور الفرعي
  /// [topic] (مفاتيح البنك) ثم بعنوان المجلد [folder] — فإذا بقي نقص يُلجأ
  /// إلى البنك المخفي داخل التطبيق (PopularBankData) حسب مادة المجلد، فتبقى
  /// كل الاختبارات عند العدد المطلوب (70 سؤالاً افتراضياً).
  /// يعيد قائمة فارغة فقط إذا لم تتوفر أي أسئلة إطلاقاً.
  static Future<List<Question>> generateForFolder(String folder,
      {String? topic, int count = 70}) async {
    final pool = <Question>[];
    final seen = <String>{};
    void addAll(List<Question> questions) {
      for (final q in questions) {
        if (seen.add(q.text)) pool.add(q);
      }
    }

    // 1) التوليد الآلي من ملفات المحور النصية أولاً.
    if (pool.length < count) {
      final text = await ReviewFileService.loadFolderText(folder, topic: topic);
      addAll(generateFromText(text, folder: folder, count: count));
    }
    final generatedCount = pool.length;

    // 2) بنك المجلد/الموضوع (أسئلة الكفاءة المهنية المصاغة يدوياً) يغطي
    // النقص بعد الملفات. يُفضَّل بنك المجلد (عند وجوده) على بنك الموضوع
    // عندما يتعارض عنوان الموضوع بين مجلدين (مثل النشاط العلمي والأمازيغية).
    final folderBank = WadiaaBankData.questionsFor(folder);
    final topicBank =
        topic != null ? WadiaaBankData.questionsFor(topic) : null;
    final effectiveBank =
        (folderBank != null && folderBank.isNotEmpty) ? folderBank : topicBank;
    if (effectiveBank != null) addAll(effectiveBank);
    final bankCount = pool.length;

    // 3) البنك المخفي داخل التطبيق (بنك الأسئلة الشائعة) ملاذ أخير فقط،
    // ليُسدَّد النقص المتبقي حتى العدد المطلوب.
    if (pool.length < count) {
      addAll(_popularBankFor(folder));
    }

    // الاختيار النهائي يراعي الأولوية حسب المصدر: المولَّد من النصوص أولاً
    // ثم بنك المحور ثم البنك المخفي، حتى لا يطغى البنك على أسئلة الملفات
    // عند سدّ النقص بعينة عشوائية من السلة المخلوطة.
    final generated = pool.sublist(0, generatedCount)..shuffle(_random);
    final effective = pool.sublist(generatedCount, bankCount)..shuffle(_random);
    final popular = pool.sublist(bankCount)..shuffle(_random);

    final result = <Question>[];
    result.addAll(generated.take(count));
    if (result.length < count) {
      result.addAll(effective.take(count - result.length));
    }
    if (result.length < count) {
      result.addAll(popular.take(count - result.length));
    }
    return enrichWithSituations(result);
  }

  /// يعيد عدد أسئلة البنك المتاحة لمحور [folder] / موضوع [topic] دون تحميل
  /// أي ملفات — مؤشر للواجهة على وجود كويز يُولَّد من البنك عندما لا تتوفر
  /// ملفات نصية كافية للمحور (مثل مواضيع البنوك الخالصة).
  static int bankCountFor(String folder, {String? topic}) {
    final folderBank = WadiaaBankData.questionsFor(folder);
    final topicBank = topic != null ? WadiaaBankData.questionsFor(topic) : null;
    final effective =
        (folderBank != null && folderBank.isNotEmpty) ? folderBank : topicBank;
    var count = effective?.length ?? 0;
    count += _popularBankFor(folder).length;
    return count;
  }

  /// أسئلة بنك الأسئلة الشائعة المطابقة لمادة المجلد [folder]،
  /// تُستعمل سدّاً للنقص عند عدم كفاية أسئلة المحور.
  static List<Question> _popularBankFor(String folder) {
    final subject = _popularSubjectFor(folder);
    if (subject == null) return const [];
    return PopularBankData.questionsFor(subject) ?? const [];
  }

  /// يحدد مادة بنك الأسئلة الشائعة لمجلد المحور.
  static String? _popularSubjectFor(String folder) {
    const subjectByFolder = {
      'علوم التربية': 'علوم التربية والبيداغوجيا',
      'ديداكتيك اللغة العربية': 'اللغة العربية',
      'ديداكتيك الرياضيات': 'الرياضيات',
    };
    return subjectByFolder[folder];
  }

  /// قلب التوليد: يحول نصاً خاماً إلى أسئلة بنمط امتحان الكفاءة المهنية.
  /// معرّضة للاختبار كدالة نقية.
  static List<Question> generateFromText(String text,
      {required String folder, int count = 70}) {
    if (text.trim().length < 40) return [];
    final sentences = _splitSentences(text);
    if (sentences.isEmpty) return [];

    final french = _looksFrench(text);
    final questions = <Question>[];

    // 1) أسئلة التعريف: «ما المقصود بمصطلح X» و«ما المصطلح الذي يُقصد به».
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
        // سؤال «كل الإجابات خاطئة» يُعرض فيه 4 تعريفات/مصطلحات لا تشمل
        // الصحيح، فيكون الخامس هو الجواب؛ يتطلب 5 تعريفات على الأقل.
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
          questions.add(
              _definitionQuestion(folder, entry, distractors.take(3).toList(), french));
        } else {
          final distractors = others.take(4).map((d) => d.term).toList();
          if (wantAllWrong && distractors.length >= 4) {
            questions.add(
                _termAllWrongQuestion(folder, entry, distractors, french));
            continue;
          }
          if (distractors.length < 3) continue;
          questions.add(_termQuestion(folder, entry, distractors.take(3).toList(), french));
        }
      }
    }

    // 2) أسئلة الفهم والتحليل: «وفق النص، أي عبارة مما يلي صحيحة؟».
    if (questions.length < count) {
      final claims = <String>{};
      for (final s in sentences) {
        final core = _coreClaim(s);
        if (core != null) claims.add(core);
      }
      // عبارات يمكن تحويلها إلى عبارات خاطئة (نفي الفعل الخبري أو قلب
      // العبارة إجمالاً) لبناء خيارات «كل الإجابات خاطئة».
      final negatable = claims
          .where((c) => _negationOf(c, french) != null)
          .toList()
        ..shuffle(_random);
      final shuffled = claims.toList()..shuffle(_random);
      for (var i = 0; i < shuffled.length && questions.length < count; i++) {
        final claim = shuffled[i];
        final others = shuffled.where((c) => c != claim).toList()..shuffle(_random);
        final distractors = others.take(3).toList();
        if (distractors.length < 3) continue;
        // سؤال «كل الإجابات خاطئة» يُعرض فيه 4 عبارات منفية لا وجود لها في
        // النص، فيكون الخامس هو الجواب.
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
        questions.add(_comprehensionQuestion(folder, claim, distractors, french));
      }
    }

    questions.shuffle(_random);
    if (questions.length > count) return questions.take(count).toList();
    return questions;
  }

  // ---------------- صياغة الأسئلة بنمط الكفاءة المهنية ----------------

  /// قوالب الوضعيات المشروطة لتوليد الأسئلة التلقائية.
  static const List<String> _situationTemplates = [
    'أثناء تدبيرك لحصة تعليمية في إطار التطبيق الفعلي للمنهاج الجديد، لاحظت وجود تفاوت كبير في فهم المتعلمين للمفهوم الأساسي المطروح، مما أدى إلى صعوبة في تحقيق الأهداف المسطرة.',
    'في إطار تفعيل البيداغوجيا الفارقية داخل الفصل الدراسي، واجهت تحدياً مرتبطاً بالتعامل مع مجموعة غير متجانسة من المتعلمين各有 مستويات متفاوتة.',
    'أثناء مراجعة نتائج التقويم التشخيصي في بداية الموسم الدراسي، تبين أن فئة مهمة من المتعلمين تعاني من إشكاليات معرفية تتطلب تدخلاً عاجلاً.',
    'في سياق تطبيق النصوص التنظيمية الجديدة المتعلقة بالحياة المدرسية، واجهت موقفاً يتطلب معرفة دقيقة بالإطار القانوني والتشريعي المؤطر للمهنة.',
    'أثناء إعداد خطة علاجية للمتعلمين المتعثرين في مادة التخصص، واجهت صعوبة في تحديد الإجراءات البيداغوجية المناسبة وفق المستجدات التربوية.',
  ];

  /// سؤال «ما المقصود بمصطلح X وفق النص؟» — التعريف صحيح، وبقية التعارиф
  /// من نفس الوثيقة مشتّتات.
  static Question _definitionQuestion(String folder, _Definition entry,
      List<String> distractors, bool french) {
    final opts = [entry.definition, ...distractors]..shuffle(_random);
    final options = [...opts, french ? frenchAllWrongOption : allWrongOption];
    final situation = _randomSituation(french);
    return Question(
      subject: folder,
      text: french
          ? 'D\'après le texte, que signifie « ${entry.term} » ?'
          : 'ما المقصود بمصطلح « ${entry.term} » وفق النص؟',
      options: options,
      correctIndex: opts.indexOf(entry.definition),
      explanation: '${entry.term}: ${entry.definition}',
      situation: situation,
    );
  }

  /// سؤال «وفق النص، ما المصطلح الذي يُقصد به: [التعريف]؟» — المصطلح صحيح،
  /// وبقية المصطلحات من الوثيقة مشتّتات.
  static Question _termQuestion(String folder, _Definition entry,
      List<String> distractors, bool french) {
    final opts = [entry.term, ...distractors]..shuffle(_random);
    final options = [...opts, french ? frenchAllWrongOption : allWrongOption];
    final situation = _randomSituation(french);
    return Question(
      subject: folder,
      text: french
          ? 'Selon le texte, quel terme désigne : « ${entry.definition} » ?'
          : 'وفق النص، ما المصطلح الذي يُقصد به: « ${entry.definition} »؟',
      options: options,
      correctIndex: opts.indexOf(entry.term),
      explanation: '${entry.term}: ${entry.definition}',
      situation: situation,
    );
  }

  /// سؤال «وفق النص، أي عبارة مما يلي صحيحة؟» — العبارة المستخرجة صحيحة،
  /// وعبارات أخرى من الوثيقة مشتّتات.
  static Question _comprehensionQuestion(
      String folder, String claim, List<String> distractors, bool french) {
    final opts = [claim, ...distractors]..shuffle(_random);
    final options = [...opts, french ? frenchAllWrongOption : allWrongOption];
    final situation = _randomSituation(french);
    return Question(
      subject: folder,
      text: french
          ? 'D\'après le texte, laquelle de ces affirmations est correcte ?'
          : 'وفق النص، أي عبارة مما يلي صحيحة؟',
      options: options,
      correctIndex: opts.indexOf(claim),
      explanation: claim,
      situation: situation,
    );
  }

  /// سؤال «ما المقصود بمصطلح X وفق النص؟» تُعرض فيه 4 تعريفات أخرى لا تشمل
  /// التعريف الصحيح، فيكون الجواب «جميع الاختيارات أعلاه خاطئة».
  static Question _definitionAllWrongQuestion(String folder, _Definition entry,
      List<String> distractors, bool french) {
    final options =
        [...distractors, french ? frenchAllWrongOption : allWrongOption];
    final situation = _randomSituation(french);
    return Question(
      subject: folder,
      text: french
          ? 'D\'après le texte, que signifie « ${entry.term} » ?'
          : 'ما المقصود بمصطلح « ${entry.term} » وفق النص؟',
      options: options,
      correctIndex: options.length - 1,
      explanation:
          'جميع الخيارات المذكورة خاطئة — ${entry.term}: ${entry.definition}',
      situation: situation,
    );
  }

  /// سؤال «وفق النص، ما المصطلح الذي يُقصد به: [التعريف]؟» تُعرض فيه 4
  /// مصطلحات أخرى لا تشمل المصطلح الصحيح، فيكون الجواب «جميع الاختيارات أعلاه خاطئة».
  static Question _termAllWrongQuestion(String folder, _Definition entry,
      List<String> distractors, bool french) {
    final options =
        [...distractors, french ? frenchAllWrongOption : allWrongOption];
    final situation = _randomSituation(french);
    return Question(
      subject: folder,
      text: french
          ? 'Selon le texte, quel terme désigne : « ${entry.definition} » ?'
          : 'وفق النص، ما المصطلح الذي يُقصد به: « ${entry.definition} »؟',
      options: options,
      correctIndex: options.length - 1,
      explanation:
          'جميع الخيارات المذكورة خاطئة — ${entry.term}: ${entry.definition}',
      situation: situation,
    );
  }

  /// سؤال «وفق النص، أي عبارة مما يلي صحيحة؟» تُعرض فيه 4 عبارات منفية لا
  /// وجود لها في النص، فيكون الجواب «جميع الاختيارات أعلاه خاطئة»؛ والتعليل يعرض
  /// العبارات الصحيحة الأصلية التي حُوّرت.
  static Question _comprehensionAllWrongQuestion(String folder,
      List<String> falseOptions, List<String> trueClaims, bool french) {
    final options =
        [...falseOptions, french ? frenchAllWrongOption : allWrongOption];
    final situation = _randomSituation(french);
    return Question(
      subject: folder,
      text: french
          ? 'D\'après le texte, laquelle de ces affirmations est correcte ?'
          : 'وفق النص، أي عبارة مما يلي صحيحة؟',
      options: options,
      correctIndex: options.length - 1,
      explanation:
          'جميع العبارات المذكورة خاطئة — الصحيح وفق النص: ${trueClaims.join(' / ')}',
      situation: situation,
    );
  }

  // ---------------- نفي العبارات لبناء خيارات خاطئة فعلياً ----------------

  /// أفعال خبرية عربية تبدأ بها عبارات قابلة للنفي الآمن («تعد»، «يجب»...).
  static final RegExp _arNegatableStart = RegExp(
    r'^(?:يعد|تعد|يُعد|يُعدّ|تُعدّ|يعتبر|يُعتبر|تعتبر|تُعتبر|تشكل|تُمثّل|تمثل|يمثل|يجب|ينبغي|يُشترط|يشترط|يتطلب|تتطلب|يتم|تتم|تُجرى|تساهم|يساهم|تساعد|يساعد|يسمح|تسمح|يحقق|تحقق|يرتبط|ترتبط|يستند|تستند|يواكب|تواكب|يراعي|تراعي|يعتمد|ينطلق|تنطلق|يؤدي|تؤدي|يمكن|يجوز)\s',
  );

  /// أفعال خبرية فرنسية تبدأ بها عبارات قابلة للنفي («Constitue...»).
  static final RegExp _frNegatableStart = RegExp(
    r'^(?:constitue|représente|désigne|signifie|favorise|privilégie|permet|développe|repose|occupe|aide|assure|garantit|exige|implique|facilite|vise)\s',
    caseSensitive: false,
  );

  /// يبني عبارة خاطئة من [claim] (لتُعرض كخيار في سؤال «كل الإجابات خاطئة»):
  ///  - بنفي الفعل الخبري الافتتاحي عند توفره («تعد X» ← «لا تعد X»)،
  ///  - وإلا بقلب العبارة إجمالاً («ليس من الصحيح وفق النص أن X») —
  ///    صيغة تصلح لأي جملة مهما بدأت، فتضمن إمكانية توليد أسئلة
  ///    «كل الإجابات خاطئة» من أي وثيقة.
  /// يعيد null فقط للعبارة الفارغة.
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

  /// يستخرج أزواج (مصطلح، تعريف) من جُمل النص حسب أنماط الصياغة العربية
  /// والفرنسية الشائعة في الوثائق التربوية.
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
      result.add(entry);
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

  /// ينظف المصطلح: يزيل علامات الطرفين ويقصّره إلى 6 كلمات.
  static String _cleanTerm(String raw) {
    var t = raw
        .trim()
        .replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');
    final words = _tokens(t);
    if (words.isEmpty) return '';
    return words.take(6).join(' ');
  }

  /// ينظف التعريف: يزيل علامات الترقيم الطرفية والفاصلة الافتتاحية.
  static String _cleanDef(String raw) {
    var d = raw
        .trim()
        .replaceAll(RegExp(r'^[،,\s]+|[.!?؟؛\s]+$', unicode: true), '');
    return d;
  }

  /// يختصر الجملة إلى عبارة مركزيّة قصيرة تصلح خياراً في سؤال الفهم.
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

  /// يختار وضعية عشوائية من القوالب المتاحة.
  static String _randomSituation(bool french) {
    if (french) {
      return 'Lors d\'une séance d\'enseignement dans le cadre de la mise en '
          'œuvre du nouveau programme, vous avez constaté de grandes '
          'différences de compréhension parmi les apprenants.';
    }
    return _situationTemplates[_random.nextInt(_situationTemplates.length)];
  }

  static List<String> _tokens(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// يزيل علامات الترقيم ويلصقها من طرفَي الكلمة.
  static String _cleanWord(String w) =>
      w.replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');

  static final RegExp _arabicLetter = RegExp(r'[\u0621-\u064A\u0671-\u06D3]');
  static final RegExp _latinLetter = RegExp(r'[a-zA-Z\u00C0-\u00FF]');

  /// يحدد ما إذا كان النص فرنسياً (غالبية الكلمات لاتينية).
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
}

/// زوج (مصطلح، تعريف) مستخرج من نص الوثيقة.
class _Definition {
  final String term;
  final String definition;
  const _Definition(this.term, this.definition);
}
