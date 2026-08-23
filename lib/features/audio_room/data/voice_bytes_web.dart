// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

/// على الويب: نتيجة التسجيل رابط blob — نجلب محتواه.
Future<Uint8List?> readRecordedBytes(String source) async {
  final completer = Completer<Uint8List?>();
  final req = html.HttpRequest()
    ..open('GET', source)
    ..responseType = 'arraybuffer';
  req.onLoadEnd.listen((_) {
    if (req.status == 200 && req.response != null) {
      completer.complete(Uint8List.view(req.response as ByteBuffer));
    } else {
      completer.complete(null);
    }
  });
  req.onError.listen((_) => completer.complete(null));
  req.send('');
  return completer.future;
}
