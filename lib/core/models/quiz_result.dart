class QuizResult {
  final String subject;
  final int score;
  final int total;
  final int percentage;
  final DateTime date;

  /// نوع الاختبار: «اختبار تدريبي»، «كويز المحور الفرعي»، «الاختبارات العامة»
  final String? testType;

  /// المحور (المادة) مثل: «اللغة العربية»، «علوم التربية والبيداغوجيا»
  final String? axis;

  /// المحور الفرعي مثل: «التخطيط والتدبير لأنشطة التعلم»
  final String? subAxis;

  const QuizResult({
    required this.subject,
    required this.score,
    required this.total,
    required this.percentage,
    required this.date,
    this.testType,
    this.axis,
    this.subAxis,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'score': score,
        'total': total,
        'percentage': percentage,
        'date': date.toIso8601String(),
        if (testType != null) 'testType': testType,
        if (axis != null) 'axis': axis,
        if (subAxis != null) 'subAxis': subAxis,
      };

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        subject: json['subject'] as String,
        score: json['score'] as int,
        total: json['total'] as int,
        percentage: json['percentage'] as int,
        date: DateTime.parse(json['date'] as String),
        testType: json['testType'] as String?,
        axis: json['axis'] as String?,
        subAxis: json['subAxis'] as String?,
      );
}
