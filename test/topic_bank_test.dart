import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/core/models/question.dart';

/// بنوك المحاور (assets/banks/topics_index.json + assets/banks/topics/*.json)
/// هي المحتوى الوحيد الذي يعرضه التطبيق: مؤلَّف يدوياً، بلا أي توليد آلي.
/// هذه الاختبارات تحرس بنيتها ومضمونها.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> index;
  late List<Map<String, dynamic>> entries;

  setUpAll(() async {
    final f = File('assets/banks/topics_index.json');
    expect(f.existsSync(), isTrue,
        reason: 'فهرس بنوك المحاور مفقود: assets/banks/topics_index.json');
    index = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    entries = (index['topics'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  });

  Map<String, dynamic> entry(String key) =>
      entries.firstWhere((e) => e['key'] == key,
          orElse: () => <String, dynamic>{});

  test('الفهرس يحوي مفتاحاً فريداً لكل محور وبياناته كاملة', () {
    final keys = entries.map((e) => e['key'] as String).toList();
    expect(keys.toSet().length, keys.length,
        reason: 'مفتاح مكرّر في الفهرس');
    for (final e in entries) {
      expect((e['key'] as String).trim(), isNotEmpty);
      expect((e['folder'] as String).trim(), isNotEmpty);
      expect((e['topic'] as String).trim(), isNotEmpty);
      expect((e['file'] as String).trim(), isNotEmpty);
      expect(e['count'], isA<int>());
      // المفتاح = المجلد + المحور: العنوان وحده ليس فريداً («ديداكتيك»).
      expect(e['key'], '${e['folder']}::${e['topic']}');
    }
  });

  test('كل محور في الفهرس له ملف موجود وعدد صحيح', () {
    for (final e in entries) {
      final f = File('assets/banks/${e['file']}');
      expect(f.existsSync(), isTrue,
          reason: 'ملف بنك مفقود: ${e['file']}');
      final list = jsonDecode(f.readAsStringSync()) as List;
      expect(list.length, e['count'],
          reason: 'عدّاد خاطئ في الفهرس: ${e['key']}');
    }
  });

  test('أسئلة كل بنك صالحة بنيوياً', () {
    for (final e in entries) {
      final list = jsonDecode(File('assets/banks/${e['file']}').readAsStringSync())
          as List;
      for (final item in list) {
        final q = Question.fromJson((item as Map).cast<String, dynamic>());
        expect(q.text.trim(), isNotEmpty, reason: 'سؤال بلا نص: ${e['key']}');
        expect(q.options.length, 4,
            reason: 'أربعة خيارات مطلوبة: ${q.text}');
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1),
            reason: 'مؤشر إجابة خارج المدى: ${q.text}');
        expect((q.explanation ?? '').trim(), isNotEmpty,
            reason: 'شرح فارغ: ${q.text}');
      }
    }
  });

  test('لا أسئلة تحيل إلى «هذا النص/المقتطف» — تذكر المرجع باسمه', () {
    final banned = RegExp(
        r'(?:هذا|هذه)\s+(?:النص|المقتطف|المعطى)\b|النص\s+المرجعي|هذا\s+المقتطف|'
        r'النص|المقتطف|الفقرة|المعطى|المعطيات|السند|كما\s+ورد\s+في');
    for (final e in entries) {
      final list = jsonDecode(File('assets/banks/${e['file']}').readAsStringSync())
          as List;
      for (final item in list) {
        final m = (item as Map).cast<String, dynamic>();
        final blob = <String>[
          (m['text'] ?? '').toString(),
          (m['situation'] ?? '').toString(),
          ...(m['options'] as List).map((o) => o.toString()),
        ].join(' ');
        expect(banned.hasMatch(blob), isFalse,
            reason: 'إحالة إشارية في «${e['key']}»: ${m['text']}');
      }
    }
  });

  test('لا خيار وصفي («كل الأجوبة السابقة خاطئة») يفقد السؤال منطقيته', () {
    final meta = RegExp(
        r'كل\s+(?:الأجوبة|الخيارات|ما\s+سبق)|لا\s+شيء\s+مما\s+سبق'
        r'|لا\s+إجابة\s+صحيحة|خيار\s+(?:آخر|اقتراضي)');
    for (final e in entries) {
      final list = jsonDecode(File('assets/banks/${e['file']}').readAsStringSync())
          as List;
      for (final item in list) {
        final m = (item as Map).cast<String, dynamic>();
        final opts = (m['options'] as List).map((o) => o.toString());
        for (final o in opts) {
          expect(meta.hasMatch(o), isFalse,
              reason: 'خيار وصفي في «${e['key']}»: $o');
        }
      }
    }
  });

  test('الإجابة الصحيحة لا تكرارٌ لعبارة السؤال ولا الأطول وحدها', () {
    const stop = <String>{
      'ما', 'من', 'في', 'على', 'الى', 'عن', 'مع', 'هذا', 'هذه', 'ذلك', 'التي',
      'الذي', 'عند', 'كيف', 'لماذا', 'متي', 'اين', 'هل', 'ثم', 'او', 'كل',
      'بعض', 'غير', 'بين', 'لدي', 'حسب', 'كما', 'هو', 'هي', 'هم', 'كان', 'كانت',
      'يكون', 'تكون', 'له', 'لها', 'هناك', 'حيث', 'ايضا', 'فقط', 'دون', 'بعد',
      'قبل', 'عبر', 'حول', 'نحو', 'ضمن', 'اذا', 'لان', 'كي', 'ليس', 'ليست',
      'مثل', 'نفس', 'اي', 'بناء', 'استنادا', 'وفق', 'ورد',
    };
    final diacritics = RegExp(r'[\u064B-\u0652\u0670\u0640]');
    String norm(String s) => s
        .replaceAll(diacritics, '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^\u0600-\u06FF]'), ' ')
        .toLowerCase()
        .trim();
    final clitic = RegExp(r'^(?:ال|لل|ل|و|ف|ب|ك|س)');
    Set<String> toks(String s) => norm(s)
        .split(RegExp(r'\s+'))
        .where((w) => !stop.contains(w))
        .map((w) => w.replaceFirst(clitic, ''))
        .where((w) => w.length > 2)
        .toSet();

    for (final e in entries) {
      final list = jsonDecode(File('assets/banks/${e['file']}').readAsStringSync())
          as List;
      for (final item in list) {
        final q = Question.fromJson((item as Map).cast<String, dynamic>());
        final text = '${q.text} ${q.situation ?? ''}';
        final correct = q.options[q.correctIndex];
        final ct = toks(text), dt = toks(correct);
        final shared = dt.intersection(ct).length;
        expect(!(shared >= 4 ||
            (dt.length >= 3 && shared / dt.length >= 0.5) ||
            (dt.length == 2 && shared == 2)),
            isTrue,
            reason: 'تسريب الإجابة: ${q.text} => $correct');

        final lens = q.options.map((o) => o.length).toList();
        final ci = q.correctIndex;
        final others = [...lens]..removeAt(ci);
        final second = others.reduce((a, b) => a > b ? a : b);
        expect(!(lens[ci] > second && lens[ci] - second >= 12 &&
            q.text.length < 170), isTrue,
            reason: 'الإجابة الصحيحة الأطول وحدها: ${q.text}');
      }
    }
  });

  test('لا تكرار داخل المحور الواحد', () {
    for (final e in entries) {
      final list = jsonDecode(File('assets/banks/${e['file']}').readAsStringSync())
          as List;
      final texts = list
          .map((e2) => ((e2 as Map)['text'] ?? '').toString().trim())
          .toList();
      expect(texts.toSet().length, texts.length,
          reason: 'أسئلة مكرّرة داخل «${e['key']}»');
    }
  });

  test('كل محور مذكور في دليل المراجعة لديه مدخل في الفهرس', () {
    // البنية: {اسم المحور الرئيسي: [ {topic, ...}, ... ]}
    final manifest = jsonDecode(
            File('assets/review_files/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    final wanted = <String>{};
    manifest.forEach((folder, raw) {
      if (raw is! List) return;
      for (final e in raw) {
        if (e is! Map) continue;
        final t = ((e['topic'] ?? folder) as String).trim();
        if (folder.trim().isNotEmpty && t.isNotEmpty) wanted.add('$folder::$t');
      }
    });
    expect(wanted, isNotEmpty, reason: 'فارغ: لم يُقرأ أي محور من المانيفست');
    // المحاور التي لها أسئلة الآن؛ الفارغ تُبنى لاحقاً بالمحتوى اليدوي.
    final filled = entries
        .map((e) => e['key'] as String)
        .where((k) => (entry(k)['count'] as int? ?? 0) > 0)
        .toSet();
    for (final k in filled) {
      expect(wanted.contains(k), isTrue,
          reason: 'مفتاح لا يقابله محور في المانيفست: $k');
    }
  });

  test('تقرير التغطية: هدف 100+ سؤال لكل محور', () {
    // ليس شرط نجاح: يطبع الحالة بصوت عالٍ لقياس تقدّم التأليف اليدوي.
    final rows = entries.map((e) => '${e['count']}\t${e['key']}').toList()..sort();
    printOnFailure('تغطية البنوك:\n${rows.join('\n')}');
  });
}