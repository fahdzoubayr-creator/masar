class TopicAttempt {
  final int bestPercentage;
  final int attempts;
  final DateTime? lockedUntil;
  final List<Map<String, dynamic>> history;

  const TopicAttempt({
    required this.bestPercentage,
    required this.attempts,
    required this.lockedUntil,
    required this.history,
  });

  Map<String, dynamic> toJson() => {
        'best': bestPercentage,
        'attempts': attempts,
        'lockedUntil': lockedUntil?.toIso8601String(),
        'history': history,
      };

  factory TopicAttempt.fromJson(Map<String, dynamic> json) => TopicAttempt(
        bestPercentage: json['best'] as int,
        attempts: json['attempts'] as int,
        lockedUntil: json['lockedUntil'] == null
            ? null
            : DateTime.tryParse(json['lockedUntil'] as String),
        history: (json['history'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}
