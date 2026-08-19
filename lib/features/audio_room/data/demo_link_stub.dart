/// بديل فارغ للمنصات غير الويب — لا مزامنة بين النوافذ خارج المتصفح.
class DemoLink {
  DemoLink._();

  static String get windowId => 'me';
  static void publish(String prefix, String payload) {}
  static List<String> readAll(String prefix) => const [];
  static void subscribe(String prefix, void Function(String payload) onData) {}
  static void unsubscribe() {}
}
