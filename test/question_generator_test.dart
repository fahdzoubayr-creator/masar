import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/core/models/quiz_result.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
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

  setUpAll(() async {
    try {
      await QuestionBankLoader.init();
    } catch (_) {
      // game_challenges.json مُزيل في 9f0222f — اختبار البنك المعتمد عليه يُتخطّى.
    }
  });

  test('المولد عربي: 4 خيارات، الجواب في أي خيار', () {
    final questions = QuestionGenerator.generateFromText(
      _sampleText,
      folder: 'علوم التربية',
      count: 10,
    );

    expect(questions, isNotEmpty);
    expect(questions.length, lessThanOrEqualTo(10));

    for (final q in questions) {
      expect(q.options.length, 4, reason: 'كل سؤال له 4 خيارات');
      expect(q.correctIndex, inInclusiveRange(0, 3),
          reason: 'الجواب الصحيح بين الخيارات الأربع');
      expect(q.options[q.correctIndex], isNotNull);
      expect(q.text, isNot(contains('أكمل الفراغ')),
          reason: 'لا أسئلة «أكمل الفراغ»');
      expect(q.explanation, isNotEmpty);
    }

    final definitions = questions.where((q) => q.text.startsWith('ما المقصود'));
    expect(definitions, isNotEmpty,
        reason: 'أسئلة «ما المقصود بمصطلح» بنمط الكفاءة المهنية');
    for (final q in definitions) {
      expect(q.explanation, contains(':'),
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
      expect(q.options.length, 4);
      expect(q.correctIndex, inInclusiveRange(0, 3));
      expect(q.explanation, isNotEmpty);
    }
  });

  test('المولد فرنسي: يولّد أسئلة بخيار E فرنسي', () {
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
      expect(q.options.length, 4, reason: '4 خيارات لكل سؤال فرنسي');
      expect(q.correctIndex, inInclusiveRange(0, 3));
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

  test('الأسئلة المولّدة: كل سؤال له خيار صحيح واحد على الأقل', () {
    var total = 0;
    var withCorrect = 0;
    for (var run = 0; run < 10; run++) {
      final questions = QuestionGenerator.generateFromText(
        _sampleText,
        folder: 'علوم التربية',
        count: 20,
      );
      for (final q in questions) {
        total++;
        if (q.correctIndex >= 0 && q.correctIndex < q.options.length) {
          withCorrect++;
        }
      }
    }
    expect(total, greaterThan(100), reason: 'عيّنة كافية');
    expect(withCorrect, total, reason: 'جميع الأسئلة لها correctIndex سليم');
  });

  test('بنك RAG: أسئلة مؤسسات الريادة، 3-5 خيارات وخيار صحيح', () {
    if (QuestionBankLoader.bank.isEmpty) {
      markTestSkipped(
          'assets/banks/game_challenges.json محذوف منذ 9f0222f — لا بنك للتحقق');
      return;
    }
    final questions = QuestionBankLoader.questionsFor('مؤسسات الريادة');
    expect(questions, isNotNull, reason: 'بنك مؤسسات الريادة غير موجود');
    expect(questions!.length, greaterThanOrEqualTo(10));
    for (final q in questions) {
      expect(q.options.length, inInclusiveRange(3, 5),
          reason: 'عدد الخيارات خارج 3-5');
      expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
    }
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

    final fail = await QuizAttemptService.record('علوم التربية › محور', r(2, 10));
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
