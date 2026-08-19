import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/core/data/wadiaa_bank_data.dart';
import 'package:masar_app/core/data/professional_bank_data.dart';
import 'package:masar_app/core/models/quiz_result.dart';
import 'package:masar_app/core/services/question_generator.dart';
import 'package:masar_app/core/services/quiz_attempt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sampleText = '''
نظرية التعلم البنائية تؤكد أن المتعلم يبني معارفه بنفسه عبر التفاعل مع المحيط.
يعد التقويم التشخيصي ضرورياً للكشف عن المكتسبات القبلية قبل بداية التعلمات الجديدة.
تساعد بيداغوجيا الخطأ على فهم التمثلات الخاطئة ومعالجتها داخل القسم.
يرتبط النمو المعرفي عند الطفل بمراحل التطور التي حددها بياجيه.
تشكل صعوبات التعلم عائقاً حقيقياً يستدعي برامج دعم خاصة وفردية.
يعتمد التدبير الفارقي على مراعاة الفروق الفردية بين المتعلمين.
تساهم السوسيولوجيا في فهم تأثير المحيط الاجتماعي على التحصيل الدراسي.
ينبغي للتقويم المستمر أن يواكب جميع مراحل الدرس من الإعداد إلى الاستنتاج.
تساعد استراتيجيات التنشيط على رفع مشاركة المتعلمين داخل الفصل الدراسي.
يمثل الوضع البيداغوجي مدخلاً لبناء التعلمات الجديدة.
ينبغي على الأستاذ ضبط الوقت والزمن المدرسي أثناء تدبير حصة الدرس.
تعتبر المقاربة بالكفايات الإطار المرجعي للتعليم الابتدائي الحديث.
يعتبر الأستاذ الناجح منشطاً للتعلمات ومرشداً للمتعلمين داخل القسم.
يقصد بالتقويم الحقيقي قياس أداء المتعلم في مهام واقعية ذات معنى.
يُعرَّف التدبير الفارقي بأنه تكييف التعلمات وفق حاجات المتعلمين ومؤهلاتهم.
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('المولد عربي: 5 خيارات، الخامس «جميع الاختيارات أعلاه خاطئة»، والجواب قد يكون عليه', () {
    final questions = QuestionGenerator.generateFromText(
      _sampleText,
      folder: 'علوم التربية',
      count: 10,
    );

    expect(questions, isNotEmpty);
    expect(questions.length, lessThanOrEqualTo(10));

    for (final q in questions) {
      expect(q.options.length, 5, reason: 'كل سؤال له 5 خيارات');
      expect(q.options.last, QuestionGenerator.allWrongOption,
          reason: 'الخيار الأخير هو دائماً «جميع الاختيارات أعلاه خاطئة»');
      expect(q.correctIndex, inInclusiveRange(0, 4),
          reason: 'الجواب الصحيح بين الخيارات الخمسة');
      expect(q.options[q.correctIndex], isNotNull);
      expect(q.text, isNot(contains('أكمل الفراغ')),
          reason: 'لا أسئلة «أكمل الفراغ»');
      expect(q.explanation, isNotEmpty);
    }

    final definitions = questions.where((q) => q.text.startsWith('ما المقصود'));
    expect(definitions, isNotEmpty,
        reason: 'أسئلة «ما المقصود بمصطلح» بنمط الكفاءة المهنية');
    for (final q in definitions) {
      expect(q.explanation, contains(':' ),
          reason: 'التعليل يحمل المصطلح وتعريفه');
    }
  });

  test('المولد عربي: أسئلة فهم النص بنمط الكفاءة المهنية', () {
    final questions = QuestionGenerator.generateFromText(
      _sampleText,
      folder: 'علوم التربية',
      count: 10,
    );

    expect(questions, isNotEmpty);
    final comprehension = questions
        .where((q) => q.text.startsWith('وفق النص، أي عبارة'))
        .toList();
    expect(comprehension, isNotEmpty, reason: 'أسئلة «وفق النص أي عبارة صحيحة»');
    for (final q in comprehension) {
      expect(q.options.length, 5);
      expect(q.options.last, QuestionGenerator.allWrongOption);
      expect(q.correctIndex, inInclusiveRange(0, 4));
      expect(q.explanation, isNotEmpty);
    }
  });

  test('المولد فرنسي: يولّد أسئلة «أكمل الفراغ» بخيار E فرنسي', () {
    const frText = '''
La didactique du français repose sur des principes pédagogiques clairs.
L'enseignement du FLE au primaire privilégie la communication orale.
Le maître doit organiser des situations d'apprentissage variées et motivantes.
La compétence communicative développe la production et la compréhension.
Les activités langagières favorisent l'expression des apprenants.
L'évaluation formative accompagne le processus d'apprentissage des élèves.
La pédagogie du projet engage les apprenants dans des tâches concrètes.
L'enseignant différencie ses supports selon les besoins des élèves.
La langue française occupe une place importante au Maroc.
Les exercices structuraux aident à la mémorisation des structures.
''';

    final questions = QuestionGenerator.generateFromText(
      frText,
      folder: 'ديداكتيك اللغة الفرنسية',
      count: 10,
    );

    expect(questions, isNotEmpty, reason: 'نص فرنسي يولّد أسئلة');
    for (final q in questions) {
      expect(q.options.length, 5, reason: '5 خيارات لكل سؤال فرنسي');
      expect(q.options.last, QuestionGenerator.frenchAllWrongOption,
          reason: 'الخيار الأخير فرنسي «جميع الأجوبة خاطئة»');
      expect(q.correctIndex, inInclusiveRange(0, 4));
      expect(q.text, isNot(contains('Complétez')),
          reason: 'لا أسئلة «أكمل الفراغ» في النمط الجديد');
      expect(q.explanation, isNotEmpty);
    }
  });

  test('التوليد عشوائي: الترتيب يختلف بين دخول وآخر', () {
    final a = QuestionGenerator.generateFromText(_sampleText, folder: 'علوم التربية');
    final b = QuestionGenerator.generateFromText(_sampleText, folder: 'علوم التربية');
    expect(a, isNotEmpty);
    expect(b, isNotEmpty);
    final seqA = a.map((q) => q.text).join('|');
    final seqB = b.map((q) => q.text).join('|');
    expect(seqA != seqB, isTrue, reason: 'ترتيب الأسئلة يتغير بين دخول وآخر');
  });

  test('نحو 70% من الأسئلة المولّدة من الملفات جوابها «كل الإجابات خاطئة»', () {
    var total = 0;
    var allWrong = 0;
    for (var run = 0; run < 30; run++) {
      final questions = QuestionGenerator.generateFromText(
        _sampleText,
        folder: 'علوم التربية',
        count: 70,
      );
      for (final q in questions) {
        total++;
        if (q.correctIndex == q.options.length - 1) allWrong++;
      }
    }
    expect(total, greaterThan(200), reason: 'عيّنة كافية لتقدير النسبة');
    final ratio = allWrong / total;
    expect(ratio, inInclusiveRange(0.55, 0.85),
        reason: 'نسبة أسئلة «كل الإجابات خاطئة» تقارب 70% '
            '(حالياً ${(ratio * 100).toStringAsFixed(1)}%)');
  });

  test('سؤال «كل الإجابات خاطئة» سليم: لا يوجد جواب صحيح بين الخيارات الأربعة', () {
    final questions = QuestionGenerator.generateFromText(
      _sampleText,
      folder: 'علوم التربية',
      count: 30,
    );
    final allWrongOnes =
        questions.where((q) => q.correctIndex == q.options.length - 1).toList();
    expect(allWrongOnes, isNotEmpty,
        reason: 'يجب أن يحتوي الكويز أسئلة جوابها «كل الإجابات خاطئة»');
    for (final q in allWrongOnes) {
      expect(q.explanation, contains('خاطئ'),
          reason: 'التعليل يوضح أن الخيارات المذكورة خاطئة');
      expect(q.options[4], QuestionGenerator.allWrongOption,
          reason: 'الخيار الخامس هو «جميع الاختيارات أعلاه خاطئة»');
      // لا يظهر جواب صحيح فعلي بين الخيارات الأربعة الأولى في أسئلة
      // التعريف: التعليل يعرض التعريف الصحيح، فلا يكون حرفياً أحد الخيارات.
      final defMatch =
          RegExp(r'جميع الخيارات المذكورة خاطئة — (.+): (.+)$').firstMatch(q.explanation);
      if (defMatch != null) {
        final trueDefinition = defMatch.group(2)!.trim();
        expect(q.options.take(4).contains(trueDefinition), isFalse,
            reason: 'لا تُعرض «$trueDefinition» كخيار عندما يكون الجواب E');
      }
    }
  });

  test('بنك الوضعيات: 5 خيارات، E خاطئة دائماً، تعليل، بلا تنقيط', () {
    const folders = [
      'التخطيط والتدبير لأنشطة التعلم',
      'تقويم التعلمات ودعمها',
    ];
    var total = 0;
    for (final folder in folders) {
      final questions = WadiaaBankData.questionsFor(folder);
      expect(questions, isNotNull, reason: 'بنك للمحور $folder');
      expect(questions!.length, greaterThanOrEqualTo(10),
          reason: 'عدد أسئلة كافٍ للمحور $folder');
      for (final q in questions) {
        expect(q.options.length, 5, reason: '5 خيارات لكل سؤال');
        expect(q.options.last, WadiaaBankData.allWrong,
            reason: 'الخيار E دائماً خاطئ');
        expect(q.correctIndex, inInclusiveRange(0, 4));
        expect(q.options[q.correctIndex], isNotNull);
        expect(q.explanation, isNotEmpty);
        expect(q.text, isNot(contains('أكمل الفراغ')));
        // لا تنقيط عددي في الخيارات (لا نقاط جزئية ممنوحة في السؤال)
        expect(q.options.join(), isNot(contains('نقطتين')));
        expect(q.options.join(), isNot(contains('نقطتا')));
        expect(q.options.join(), isNot(contains('من 20')));
        // توزيع المواضع الصحيحة على غير موضع ثابت
      }
      total += questions.length;
    }
    expect(total, greaterThanOrEqualTo(30), reason: 'حجم البنك الإجمالي كافٍ');
  });

  test('بنك الوضعيات: المصدر إحالة مرجعية بصفحة، وغيابه مسموح للمعرفة الخارجية', () {
    const folders = [
      'التخطيط والتدبير لأنشطة التعلم',
      'تقويم التعلمات ودعمها',
    ];
    final sourceRe = RegExp(r'^دليل الأستاذ\(ة\) كتابي في اللغة العربية 6 — ص \d+$');
    var withSource = 0;
    var withoutSource = 0;
    for (final folder in folders) {
      final questions = WadiaaBankData.questionsFor(folder);
      for (final q in questions!) {
        if (q.source == null) {
          withoutSource++;
        } else {
          expect(sourceRe.hasMatch(q.source!), isTrue,
              reason: 'صيغة المصدر: «دليل الأستاذ(ة) … — ص N» فعلياً: ${q.source}');
          withSource++;
        }
      }
    }
    expect(withSource, greaterThanOrEqualTo(40),
        reason: 'غالبية أسئلة البنك تحمل إحالة مصدر');
    expect(withoutSource, lessThanOrEqualTo(7),
        reason: 'القليل من الأسئلة بلا مصدر (معرفة خارج الدليل)');
  });

  test('توليد المحور المخصص للبنك: يعيد أسئلة البنك مرجعة، بلا تنقيط', () async {
    final list = await QuestionGenerator.generateForFolder(
      'التخطيط والتدبير لأنشطة التعلم',
      count: 20,
    );
    expect(list, isNotEmpty);
    expect(list.length, lessThanOrEqualTo(20));
    for (final q in list) {
      expect(q.options.length, 5);
      expect(q.options.last, 'جميع الاختيارات أعلاه خاطئة.');
    }
  });

  test('الاستدعاء من مجلد بموضوع فرعي: يجد بنك الأسئلة بعنوان الموضوع', () async {
    final list = await QuestionGenerator.generateForFolder(
      'ديداكتيك اللغة العربية',
      topic: 'التخطيط والتدبير لأنشطة التعلم',
    );
    expect(list, isNotEmpty, reason: 'بنك الموضوع يُلتقط عبر العنوان الفرعي');
    expect(list.length, lessThanOrEqualTo(70),
        reason: 'لا يتجاوز الكويز حد 70 سؤالاً حتى بعد سدّ النقص');
    // أسئلة بنك الموضوع حاضرة في الناتج حتى لو سُدّ النقص من البنك المخفي.
    final bankQuestions = list.where((q) => q.options.length == 5).toList();
    expect(bankQuestions, isNotEmpty,
        reason: 'أسئلة بنك الموضوع حاضرة في الكويز');
    for (final q in bankQuestions) {
      expect(q.options.last, 'جميع الاختيارات أعلاه خاطئة.');
    }
  });

  test('بنك الكفاءة المهنية: علوم التربية مواضيع، 5 خيارات، E خاطئة دائماً', () {
    const topics = [
      'نظريات التعلم والمقاربات البيداغوجية',
      'النمو واستراتيجيات اكتساب الفهم',
      'سيكولوجيا التربية وتقاطعاتها',
      'صعوبات التعلم وعوائقه',
      'سوسيولوجيا التربية وسيكوسوسيولوجيا التربية',
      'التقويم والدعم التربويان',
    ];
    var total = 0;
    for (final topic in topics) {
      final questions = ProfessionalBankData.questionsFor(topic);
      expect(questions, isNotNull, reason: 'بنك للموضوع $topic');
      expect(questions!.length, greaterThanOrEqualTo(10),
          reason: 'عدد أسئلة كافٍ للموضوع $topic');
      for (final q in questions) {
        expect(q.options.length, 5, reason: '5 خيارات لكل سؤال');
        expect(q.options.last, ProfessionalBankData.allWrong,
            reason: 'الخيار E دائماً خاطئ');
        expect(q.correctIndex, inInclusiveRange(0, 4));
        expect(q.options[q.correctIndex], isNotNull);
        expect(q.explanation, isNotEmpty);
        expect(q.text, isNot(contains('أكمل الفراغ')));
      }
      total += questions.length;
    }
    expect(total, greaterThanOrEqualTo(60),
        reason: 'حجم بنك علوم التربية كافٍ');
  });

  test('توليد كويز علوم التربية يفضّل بنك الكفاءة المهنية', () async {
    final list = await QuestionGenerator.generateForFolder(
      'علوم التربية',
      topic: 'نظريات التعلم والمقاربات البيداغوجية',
      count: 30,
    );
    expect(list, isNotEmpty);
    expect(list.length, lessThanOrEqualTo(30));
    // أسئلة بنك الكفاءة المهنية (5 خيارات) حاضرة حتى لو سُدّ النقص
    // من ملفات المحور أو من البنك المخفي.
    final fromBank = list.where((q) => q.options.length == 5).toList();
    expect(fromBank, isNotEmpty,
        reason: 'بنك الكفاءة المهنية يُفضَّل عند توليد الكويز');
    for (final q in fromBank) {
      expect(q.options.last, 'جميع الاختيارات أعلاه خاطئة.');
    }
  });

  test('بنوك الديداكتيك: رياضيات، نشاط علمي، أمازيغية، فرنسية', () async {
    const checks = [
      ('ديداكتيك الرياضيات', 'التخطيط والتدبير', 5, 'جميع الاختيارات أعلاه خاطئة.'),
      ('ديداكتيك الرياضيات', 'التقويم والدعم', 5, 'جميع الاختيارات أعلاه خاطئة.'),
      ('ديداكتيك النشاط العلمي', null, 5, 'جميع الاختيارات أعلاه خاطئة.'),
      ('ديداكتيك اللغة الأمازيغية', null, 5, 'جميع الاختيارات أعلاه خاطئة.'),
      ('ديداكتيك اللغة الفرنسية',
          'La planification des activités d\'enseignement/apprentissage', 5,
          'Toutes les réponses ci-dessus sont fausses.'),
      ('ديداكتيك اللغة الفرنسية',
          'La gestion des activités d\'enseignement/apprentissage', 5,
          'Toutes les réponses ci-dessus sont fausses.'),
      ('ديداكتيك اللغة الفرنسية',
          'L\'évaluation et le soutien des apprentissages', 5,
          'Toutes les réponses ci-dessus sont fausses.'),
    ];
    for (final (folder, topic, size, allWrong) in checks) {
      final list = await QuestionGenerator.generateForFolder(folder,
          topic: topic, count: 12);
      expect(list, isNotEmpty, reason: '$folder / $topic');
      expect(list.length, lessThanOrEqualTo(12));
      for (final q in list) {
        expect(q.options.length, size);
        expect(q.options.last, allWrong,
            reason: 'آخر خيار خاطئ دائماً في $folder / $topic');
        expect(q.correctIndex, lessThan(size - 1));
        expect(q.explanation, isNotEmpty);
      }
    }
  });

  test('النشاط العلمي والأمازيغية: بنك المجلد لا يُخلط', () async {
    final science = await QuestionGenerator.generateForFolder(
        'ديداكتيك النشاط العلمي',
        topic: 'التخطيط والتدبير الديدكتيكي',
        count: 8);
    final amazigh = await QuestionGenerator.generateForFolder(
        'ديداكتيك اللغة الأمازيغية',
        topic: 'التخطيط والتدبير الديدكتيكي',
        count: 8);
    expect(science, isNotEmpty);
    expect(amazigh, isNotEmpty);
    expect(science.every((q) => q.subject == 'ديداكتيك النشاط العلمي'), isTrue);
    expect(amazigh.every((q) => q.subject == 'ديداكتيك اللغة الأمازيغية'), isTrue);
  });

  test('المصادر موثقة ومتنوعة: لا مصادر وهمية في بنك الكفاءة المهنية', () {
    const fake = ['علوم التربية لجميع التخصصات 2025', 'www.wadifaprepa.com'];
    final all = ProfessionalBankData.questionsFor(
        'نظريات التعلم والمقاربات البيداغوجية')!;
    final seen = <String>{};
    var total = 0;
    for (final q in all) {
      total++;
      expect(q.source, isNotNull);
      expect(q.source!.trim(), isNotEmpty);
      for (final f in fake) {
        expect(q.source!.contains(f), isFalse,
            reason: 'لا مصدر وهمي: ${q.source}');
      }
      seen.add(q.source!);
    }
    expect(seen.length, greaterThan(2),
        reason: 'يجب أن تتوزع المصادر على أكثر من مرجعين');
    expect(total, greaterThanOrEqualTo(12));
  });

  test('سجل المحاولات: أفضل نسبة وحظر 3 ساعات عند الفشل', () async {
    QuizResult r(int score, int total) => QuizResult(
          subject: 'علوم التربية › محور',
          score: score,
          total: total,
          percentage: ((score / total) * 100).round(),
          date: DateTime.now(),
        );

    final pass = await QuizAttemptService.record('علوم التربية › محور', r(8, 10));
    expect(pass.bestPercentage, 80);
    expect(pass.attempts, 1);
    expect(QuizAttemptService.isLocked(pass), isFalse);

    final fail = await QuizAttemptService.record('علوم التربية › محور', r(3, 10));
    expect(fail.bestPercentage, 80, reason: 'أفضل نسبة لا تتراجع');
    expect(fail.attempts, 2);
    expect(QuizAttemptService.isLocked(fail), isTrue);

    final remaining = QuizAttemptService.remainingLock(fail);
    expect(remaining, isNotNull);
    expect(remaining!.inHours, greaterThanOrEqualTo(2));

    final again = await QuizAttemptService.record('علوم التربية › محور', r(5, 10));
    expect(QuizAttemptService.isLocked(again), isTrue,
        reason: 'النجاح لاحقاً لا يرفع الحظر المفروض سابقاً');
  });
}
