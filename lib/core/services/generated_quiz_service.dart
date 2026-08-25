import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:masar_app/core/models/question.dart';

/// كويز مولّد آلياً من محتوى ملف الدرس (PDF) عبر السيرفر و Groq.
class GeneratedQuizService {
  GeneratedQuizService._();

  static final Map<String, List<Question>> _mem = {};

  /// يولّد (أو يعيد من التخزين المؤقت) 70 سؤالاً من ملف الدرس.
  /// يرمي استثناء عند الفشل — على المستدعي التراجع لبنك الموضوع.
  static Future<List<Question>> fromPdf(
    String assetPath, {
    required String subject,
  }) async {
    final cached = _mem[assetPath];
    if (cached != null) return cached;

    final uri = Uri.base.resolve('/api/quiz/generate-from-pdf');
    final resp = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'path': assetPath, 'subject': subject}),
        )
        .timeout(const Duration(minutes: 8));

    if (resp.statusCode != 200) {
      throw Exception('GENERATE_HTTP_${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final raw = data['questions'];
    if (raw is! List || raw.isEmpty) {
      throw Exception('GENERATE_EMPTY');
    }
    final questions = raw
        .cast<Map<String, dynamic>>()
        .map(Question.fromJson)
        .toList();
    _mem[assetPath] = questions;
    return questions;
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
