import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/question_generator.dart';
import 'package:masar_app/core/services/question_repository.dart';

/// تحقّق من فلترة المادة: كويز الرياضيات يجب ألّا يحوي أسئلة عربية أو
/// علوم تربية أو فرنسية (لا من البنك ولا من السحب الجزئي).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await QuestionBankLoader.init();
    } catch (_) {
      // game_challenges.json مُزيل في 9f0222f — الاختبارات المعتمدة عليه تُتخطّى.
    }
  });

  bool skipWithoutBank() {
    if (QuestionBankLoader.bank.isNotEmpty) return false;
    markTestSkipped(
        'assets/banks/game_challenges.json محذوف منذ 9f0222f — لا بنك للتحقق');
    return true;
  }

  const foreignMarkers = <String>[
    'العربية',
    'علوم التربية',
    'الفرنسية',
    'النشاط العلمي',
    'التشريع',
  ];

  test('بنك الرياضيات: لا تسرّب مواد أخرى', () {
    if (skipWithoutBank()) return;
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
    if (skipWithoutBank()) return;
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

  test('كويز المحور الفرعي: لا يملأ من بقية المادة', () async {
    if (skipWithoutBank()) return;
    final quiz = await QuestionGenerator.generateForFolder(
      'علوم التربية',
      topic: 'التقويم والدعم التربويان',
      count: 50,
    );
    expect(quiz, isNotEmpty);
    // البنك المطابق قليل؛ قديمًا كان يُكمل من كل الـ131 سؤالًا فيصل إلى 50.
    expect(quiz.length, lessThan(50),
        reason: 'يبدو أن أسئلة محاور أخرى تسرّبت لإكمال العدد');
    const offTopic = <String>['بياجيه', 'فيغوتسكي', 'دوركايم', 'الجشطالتية'];
    for (final q in quiz) {
      for (final m in offTopic) {
        expect(q.text.contains(m), isFalse,
            reason: 'سؤال خارج محور التقويم: ${q.text}');
      }
    }
  });
}
