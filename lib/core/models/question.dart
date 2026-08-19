class Question {
  final String subject;
  final String? level; // null لمواد بدون مستويات (علوم التربية، التشريع)
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  /// إحالة مصدر الجواب في المرجع (مثل: «دليل الأستاذ(ة) — ص 12»).
  /// يُعرض في الكويز فقط عند إجابة المستخدم خطأً.
  final String? source;

  /// وضعية مشكلة مهنية أو سياق تشريعي/ديداكتيكي يسبق السؤال.
  /// عند وجودها، تُعرض كفقرة منفصلة أعلى السؤال في شاشة الكويز.
  final String? situation;

  const Question({
    required this.subject,
    this.level,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.source,
    this.situation,
  });
}
