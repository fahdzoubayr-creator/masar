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
    if (raw is! List || raw.isEmpty || jobId is! String) {
      throw Exception('START_EMPTY');
    }
    final first = raw
        .cast<Map<String, dynamic>>()
        .map(Question.fromJson)
        .toList();
    return ProgressiveStart(jobId, first);
  }

  /// ينتظر أسئلة الخلفية (Polling) حتى جاهزيتها أو انتهاء المهلة.
  static Future<List<Question>> restWhenReady(
    String jobId, {
    Duration timeout = const Duration(minutes: 8),
  }) async {
    if (jobId.isEmpty) return const <Question>[];
    final deadline = DateTime.now().add(timeout);
    final uri = Uri.base.resolve('/api/quiz/job/$jobId');
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final resp = await http.get(uri).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final d = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
          if (d['state'] == 'done') {
            final raw = d['questions'];
            if (raw is! List) return const <Question>[];
            return raw
                .cast<Map<String, dynamic>>()
                .map(Question.fromJson)
                .toList();
          }
        } else if (resp.statusCode == 404) {
          return const <Question>[];
        }
      } catch (_) {
        // شبكة عابرة — نواصل المحاولة حتى المهلة.
      }
    }
    return const <Question>[];
  }

  /// يولّد من عدة ملفات بالتتابع حتى بلوغ [target] سؤالاً — يتخطى ما يفشل.
  static Future<List<Question>> fromPdfs(
    List<String> assetPaths, {
    required String subject,
    int target = 70,
  }) async {
    final out = <Question>[];
    for (final p in assetPaths) {
      if (out.length >= target) break;
      try {
        out.addAll(await fromPdf(p, subject: subject));
      } catch (_) {
        // تخطَّ الملف الفاشل وواصل مع البقية.
      }
    }
    return out.length > target ? out.sublist(0, target) : out;
  }
}
