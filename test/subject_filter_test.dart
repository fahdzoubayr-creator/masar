import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/question_generator.dart';
import 'package:masar_app/core/services/question_repository.dart';

/// تحقّق من فلترة المادة: كويز الرياضيات يجب ألّا يحوي أسئلة عربية أو
/// علوم تربية أو فرنسية (لا من البنك ولا من السحب الجزئي).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuestionBankLoader.init();
  });

  const foreignMarkers = <String>[
    'العربية',
    'علوم التربية',
    'الفرنسية',
    'النشاط العلمي',
    'التشريع',
  ];

  test('بنك الرياضيات: لا تسرّب مواد أخرى', () {
    final pool = QuestionGenerator.poolForFolder('ديداكتيك الرياضيات');
    expect(pool, isNotEmpty, reason: 'بنك ديداكتيك الرياضيات فارغ');

    for (final q in pool) {
      final tag = '${q.subject} :: ${q.text}';
      expect(q.subject.contains('الرياضيات'), isTrue,
          reason: 'سؤال بلا وسم الرياضيات: $tag');
      for (final m in foreignMarkers) {
        expect(q.subject.contains(m), isFalse,
            reason: 'تسرّب «$m» إلى بنك الرياضيات: $tag');
      }
    }
  });

  test('كويز الرياضيات (50): كل الأسئلة من مادة الرياضيات', () async {
    final quiz = await QuestionGenerator.generateForFolder(
      'ديداكتيك الرياضيات',
      count: 50,
    );
    expect(quiz, isNotEmpty);
    for (final q in quiz) {
      expect(q.subject.contains('الرياضيات'), isTrue,
          reason: 'سؤال غريب داخل كويز الرياضيات: ${q.text}');
      for (final m in foreignMarkers) {
        expect(q.subject.contains(m), isFalse,
            reason: 'تسرّب «$m» إلى كويز الرياضيات: ${q.text}');
      }
    }

    final repo = await QuestionRepository.instance
        .loadQuestions(subject: 'ديداكتيك الرياضيات');
    for (final q in repo) {
      expect(q.subject.contains('الرياضيات'), isTrue,
          reason: 'تسرّب من السحب الجزئي: ${q.text}');
    }
  });
}
