class Question {
  final String id;
  final String subject;
  final String? level;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String? source;
  final String? situation;

  const Question({
    required this.id,
    required this.subject,
    this.level,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.source,
    this.situation,
  });

  factory Question.fromJson(Map<String, dynamic> j) {
    // توليد معرف فريد من نص السؤال + الموضوع
    final text = j['text'] as String? ?? '';
    final subject = j['subject'] as String? ?? '';
    final id = j['id'] as String? ?? '${subject}_$text'.hashCode.toString();

    return Question(
      id: id,
      subject: subject,
      level: j['level'] as String?,
      text: text,
      options: (j['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctIndex: j['correctIndex'] as int? ?? 0,
      explanation: j['explanation'] as String? ?? '',
      source: j['source'] as String?,
      situation: j['situation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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
