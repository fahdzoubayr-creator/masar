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

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        subject: j['subject'] as String? ?? '',
        level: j['level'] as String?,
        text: j['text'] as String? ?? '',
        options: (j['options'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        correctIndex: j['correctIndex'] as int? ?? 0,
        explanation: j['explanation'] as String? ?? '',
        source: j['source'] as String?,
        situation: j['situation'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'subject': subject,
        if (level != null) 'level': level,
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
        if (source != null) 'source': source,
        if (situation != null) 'situation': situation,
      };
}
