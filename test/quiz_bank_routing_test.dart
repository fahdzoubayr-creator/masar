import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';

/// اختبارات تحقق من بنك الأسئلة الجديد (RAG-generated).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuestionBankLoader.init();
  });

  group('بنوك JSON — تحقق كامل', () {
    test('لا توجد أسئلة فارغة النص', () {
      for (final key in QuestionBankLoader.bank.keys) {
        final questions = QuestionBankLoader.questionsFor(key)!;
        for (final q in questions) {
          expect(q.text.trim().isNotEmpty, isTrue,
              reason: 'سؤال فارغ النص في بنك $key');
        }
      }
    });

    test('كل سؤال يحتوي على 3-5 خيارات و correctIndex سليم', () {
      for (final key in QuestionBankLoader.bank.keys) {
        final questions = QuestionBankLoader.questionsFor(key)!;
        for (final q in questions) {
          final label = q.text.length > 30 ? q.text.substring(0, 30) : q.text;
          expect(q.options.length, inInclusiveRange(3, 5),
              reason: 'عدد خيارات خارج 3-5 في $key: $label');
          expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1),
              reason: 'correctIndex خاطئ في $key: $label');
        }
      }
    });

    test('كل سؤال يحتوي على تعليل', () {
      for (final key in QuestionBankLoader.bank.keys) {
        final questions = QuestionBankLoader.questionsFor(key)!;
        for (final q in questions) {
          final label = q.text.length > 30 ? q.text.substring(0, 30) : q.text;
          expect(q.explanation, isA<String>(),
              reason: 'explanation يجب أن يكون نصاً في $key: $label');
        }
      }
    });

    test('كل المفاتيح تحتوي أسئلة (لا بنك فارغ)', () {
      for (final key in QuestionBankLoader.bank.keys) {
        final questions = QuestionBankLoader.questionsFor(key);
        expect(questions, isNotNull, reason: 'بنك فارغ: $key');
        expect(questions!.isNotEmpty, true, reason: 'بنك فارغ: $key');
      }
    });

    test('البنك الكلي يحتوي على أسئلة', () {
      expect(QuestionBankLoader.totalCount, greaterThanOrEqualTo(10));
    });

    test('يوجد ملفات JSON في assets/banks', () {
      expect(QuestionBankLoader.bank.keys.length, greaterThanOrEqualTo(1));
    });
  });
}
