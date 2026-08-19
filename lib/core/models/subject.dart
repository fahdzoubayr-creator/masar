class Subject {
  final String name;
  final String icon; // رمز تعبيري مؤقت — يمكن استبداله بأيقونات حقيقية لاحقاً
  final String meta;
  final List<String>? levels; // null = مادة مشتركة بدون مستويات (كل الأساتذة يجتازونها)

  const Subject({
    required this.name,
    required this.icon,
    required this.meta,
    this.levels,
  });

  bool get hasLevels => levels != null && levels!.isNotEmpty;
}
