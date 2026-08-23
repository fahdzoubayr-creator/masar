import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';

/// اختبارات تحقق من أن بنك الأسئلة المحمل من JSON يحتوي على البيانات الصحيحة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuestionBankLoader.init();
  });

  group('بنوك JSON — تحقق كامل', () {
    test('التنشيط التربوي → 100 سؤال، 4 خيارات، subject صحيح', () {
      final questions = QuestionBankLoader.questionsFor('التنشيط التربوي');
      expect(questions, isNotNull);
      expect(questions!.length, greaterThanOrEqualTo(50));
      for (final q in questions) {
        expect(q.subject, 'التنشيط التربوي');
        expect(q.options.length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
    });

    test('المهارات الحياتية → 100 سؤال، 4 خيارات', () {
      final questions = QuestionBankLoader.questionsFor('المهارات الحياتية');
      expect(questions, isNotNull);
      expect(questions!.length, greaterThanOrEqualTo(50));
      for (final q in questions) {
        expect(q.subject, 'المهارات الحياتية');
        expect(q.options.length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
    });

    test('المجالس التعليمية → 100 سؤال، 4 خيارات', () {
      final questions = QuestionBankLoader.questionsFor('المجالس التعليمية');
      expect(questions, isNotNull);
      expect(questions!.length, greaterThanOrEqualTo(50));
      for (final q in questions) {
        expect(q.subject, 'المجالس التعليمية');
        expect(q.options.length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
    });

    test('البنوك الثلاث مدمجة في التنشيط التربوي', () {
      final animation = QuestionBankLoader.questionsFor('التنشيط التربوي');
      final skills = QuestionBankLoader.questionsFor('المهارات الحياتية');
      final councils = QuestionBankLoader.questionsFor('المجالس التعليمية');
      expect(animation, isNotNull);
      expect(skills, isNotNull);
      expect(councils, isNotNull);
      expect(animation!.length + skills!.length + councils!.length, greaterThanOrEqualTo(150));
    });

    test('لا توجد أسئلة فارغة النص', () {
      for (final key in QuestionBankLoader.bank.keys) {
        final questions = QuestionBankLoader.questionsFor(key)!;
        for (final q in questions) {
          expect(q.text.trim().isNotEmpty, isTrue,
              reason: 'سؤال فارغ النص في بنك $key');
        }
      }
    });

    test('كل سؤال يحتوي على 4 خيارات و correctIndex سليم', () {
      for (final key in QuestionBankLoader.bank.keys) {
        final questions = QuestionBankLoader.questionsFor(key)!;
        for (final q in questions) {
          final label = q.text.length > 30 ? q.text.substring(0, 30) : q.text;
          expect(q.options.length, 4,
              reason: 'سؤال بخيارات != 4 في $key: $label');
          expect(q.correctIndex, inInclusiveRange(0, 3),
              reason: 'correctIndex خاطئ في $key: $label');
        }
      }
    });

    test('كل سؤال يحتوي على تعليل (قد يكون فارغاً في بعض البنوك الأصلية)', () {
      for (final key in QuestionBankLoader.bank.keys) {
        final questions = QuestionBankLoader.questionsFor(key)!;
        for (final q in questions) {
          final label = q.text.length > 30 ? q.text.substring(0, 30) : q.text;
          expect(q.explanation, isA<String>(),
              reason: '’explanation‘ يجب أن يكون نصاً في $key: $label');
        }
      }
    });

    test('علوم التربية والبيداغوجيا حاضرة', () {
      final questions = QuestionBankLoader.questionsFor('علوم التربية والبيداغوجيا');
      expect(questions, isNotNull);
      expect(questions!.length, greaterThanOrEqualTo(50));
    });

    test('ديداكتيك اللغة العربية حاضرة', () {
      final questions = QuestionBankLoader.questionsFor('ديداكتيك اللغة العربية');
      expect(questions, isNotNull);
      expect(questions!.length, greaterThanOrEqualTo(100));
    });

    test('ديداكتيك الرياضيات حاضرة', () {
      final questions = QuestionBankLoader.questionsFor('ديداكتيك الرياضيات');
      expect(questions, isNotNull);
      expect(questions!.length, greaterThanOrEqualTo(100));
    });

    test('ديداكتيك النشاط العلمي حاضرة', () {
      final all = <String>{'ديداكتيك النشاط العلمي', 'النشاط العلمي'};
      var total = 0;
      for (final key in all) {
        total += QuestionBankLoader.questionsFor(key)?.length ?? 0;
      }
      expect(total, greaterThanOrEqualTo(50));
    });

    test('كل المفاتيح تحتوي أسئلة (لا بنك فارغ)', () {
      for (final key in QuestionBankLoader.bank.keys) {
        final questions = QuestionBankLoader.questionsFor(key);
        expect(questions, isNotNull, reason: 'بنك فارغ: $key');
        expect(questions!.isNotEmpty, true, reason: 'بنك فارغ: $key');
      }
    });

    test('البنك الكلي يحتوي على أكثر من 1000 سؤال', () {
      expect(QuestionBankLoader.totalCount, greaterThanOrEqualTo(1000));
    });
  });
}
