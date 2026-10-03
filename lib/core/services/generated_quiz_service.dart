import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/review_file_service.dart';

/// نتيجة بدء التوليد المتدرج: دفعة أولى فورية + معرف مهمة الخلفية.
class ProgressiveStart {
  final String jobId;
  final List<Question> first;
  ProgressiveStart(this.jobId, this.first);
}

/// كويز مولّد آلياً من محتوى ملف الدرس (PDF) عبر السيرفر و Groq.
class GeneratedQuizService {
  GeneratedQuizService._();

  /// يولّد (أو يعيد من التخزين المؤقت) 70 سؤالاً من ملف الدرس.
  /// يرمي استثناء عند الفشل — على المستدعي التراجع لبنك الموضوع.
  static Future<List<Question>> fromPdf(
    String assetPath, {
    required String subject,
    String? sourceName,
    String? sub,
  }) async {
    // بلا تخزين بين المحاولات: كل إعادة اختبار = بذرة جديدة وأسئلة تتجدد.
    final uri = Uri.base.resolve('/api/quiz/generate-from-pdf');
    final resp = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'path': assetPath,
            'url': ReviewFileService.urlFor(assetPath),
            'subject': subject,
            if (sub != null && sub.isNotEmpty) 'sub': sub,
            if (sourceName != null && sourceName.isNotEmpty)
              'sourceName': sourceName,
          }),
        )
        .timeout(const Duration(minutes: 8));

    if (resp.statusCode != 200) {
      throw Exception(
          'GENERATE_HTTP_${resp.statusCode}: ${utf8.decode(resp.bodyBytes)}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final raw = data['questions'];
    if (raw is! List || raw.isEmpty) {
      throw Exception('GENERATE_EMPTY');
    }
    return raw
        .cast<Map<String, dynamic>>()
        .map(Question.fromJson)
        .toList();
  }

  /// التوليد المتدرج: دفعة أولى (4 أسئلة) خلال ثوانٍ، والباقي يُستكمل بالخلفية.
  static Future<ProgressiveStart> startProgressive(
    String assetPath, {
    required String subject,
    String? sourceName,
    String? sub,
  }) async {
    final uri = Uri.base.resolve('/api/quiz/start-from-pdf');
    final resp = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'path': assetPath,
            'url': ReviewFileService.urlFor(assetPath),
            'subject': subject,
            if (sub != null && sub.isNotEmpty) 'sub': sub,
            if (sourceName != null && sourceName.isNotEmpty)
              'sourceName': sourceName,
          }),
        )
        .timeout(const Duration(minutes: 2));
    if (resp.statusCode != 200) {
      throw Exception(
          'START_HTTP_${resp.statusCode}: ${utf8.decode(resp.bodyBytes)}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final raw = data['questions'];
    final jobId = data['jobId'];
    // السيرفر يردّ فوراً بمعرّف المهمة فقط، وقد تكون الدفعة الأولى فارغة.
    if (jobId is! String || jobId.isEmpty) {
      throw Exception('START_EMPTY');
    }
    final first = raw is List
        ? raw.cast<Map<String, dynamic>>().map(Question.fromJson).toList()
        : <Question>[];
    return ProgressiveStart(jobId, first);
  }

  /// ينتظر أسئلة الخلفية (Polling) حتى جاهزيتها أو انتهاء المهلة.
  ///
  /// لا تُرجع قائمة فارغة لمجرد أن الحالة «working» — بل تستمر حتى
  /// الوصول إلى done أو 404 أو انتهاء المهلة، وإلا تعلّق الكويز على 4 أسئلة.
  static Future<List<Question>> restWhenReady(
    String jobId, {
    Duration timeout = const Duration(minutes: 10),
  }) async {
    if (jobId.isEmpty) return const <Question>[];
    final deadline = DateTime.now().add(timeout);
    final uri = Uri.base.resolve('/api/quiz/job/$jobId');

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final resp = await http.get(uri).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final d = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
          final state = d['state'];
          final raw = d['questions'];

          if (raw is List && raw.isNotEmpty) {
            final qs = raw
                .cast<Map<String, dynamic>>()
                .map(Question.fromJson)
                .toList();
            // done => انتهى. غير ذلك => ما زال يولّد، نتابع الانتظار.
            if (state == 'done') return qs;
            if (state == 'error') return qs;
          }

          if (state == 'done' || state == 'error') {
            return const <Question>[];
          }
          // state == 'working' => نكمل الانتظار.
        } else if (resp.statusCode == 404) {
          return const <Question>[];
        }
      } catch (_) {
        // شبكة عابرة — نواصل المحاولة حتى المهلة.
      }
    }
    return const <Question>[];
  }

  /// لقطة فورية: يعيد ما وصل من التوليد حتى الآن دون انتظار.
  ///
  /// تُستدعى كل ثانيتين أثناء العرض، فيبدأ المستخدم فور وصول أول دفعة
  /// بدل انتظار اكتمال المهمة.
  static Future<List<Question>> pollSnapshot(String jobId) async {
    if (jobId.isEmpty) return const <Question>[];
    final uri = Uri.base.resolve('/api/quiz/job/$jobId');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return const <Question>[];
      final d = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final raw = d['questions'];
      if (raw is! List || raw.isEmpty) return const <Question>[];
      return raw.cast<Map<String, dynamic>>().map(Question.fromJson).toList();
    } catch (_) {
      return const <Question>[];
    }
  }

  /// هل ما زالت مهمة التوليد تعمل؟
  static Future<bool> jobWorking(String jobId) async {
    if (jobId.isEmpty) return false;
    final uri = Uri.base.resolve('/api/quiz/job/$jobId');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return false;
      final d = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      return d['state'] == 'working';
    } catch (_) {
      return false;
    }
  }

  /// يولّد من عدة ملفات بالتتابع حتى بلوغ [target] سؤالاً — يتخطى ما يفشل.
  static Future<List<Question>> fromPdfs(
    List<String> assetPaths, {
    required String subject,
    int target = 50,
    List<String?>? sourceNames,
    String? sub,
  }) async {
    final out = <Question>[];
    for (var i = 0; i < assetPaths.length; i++) {
      final p = assetPaths[i];
      if (out.length >= target) break;
      try {
        out.addAll(await fromPdf(p,
            subject: subject,
            sub: sub,
            sourceName: sourceNames != null && i < sourceNames.length
                ? sourceNames[i]
                : null));
      } catch (_) {
        // تخطَّ الملف الفاشل وواصل مع البقية.
      }
    }
    return out.length > target ? out.sublist(0, target) : out;
  }
}
