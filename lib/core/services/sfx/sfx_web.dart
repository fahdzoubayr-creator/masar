import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'sfx.dart';

/// تشغيل المؤثرات على الويب عبر WebAudio — سياق دائم واحد وتخزين مؤقت
/// للمخازن المفكوكة؛ المسار القياسي ثم البديل حسب نسخة Flutter.
final Map<Sfx, web.AudioBuffer> _cache = {};
web.AudioContext? _ctx;

web.AudioContext get _audio => _ctx ??= web.AudioContext();

Future<void> _load(Sfx s) async {
  if (_cache.containsKey(s)) return;
  for (final base in const ['assets/assets/sounds/', 'assets/sounds/']) {
    try {
      final resp = await web.window
          .fetch(Uri.base.resolve('$base${s.name}.wav').toString().toJS)
          .toDart;
      if (resp.status == 200) {
        final buf = await resp.arrayBuffer().toDart;
        _cache[s] = await _audio.decodeAudioData(buf).toDart;
        return;
      }
    } catch (_) {
      // نجرّب المسار البديل ثم نستسلم بصمت — الصوت ترف لا عطل.
    }
  }
}

void playSfx(Sfx s) {
  _load(s).then((_) {
    final b = _cache[s];
    if (b == null) return;
    if (_audio.state == 'suspended') _audio.resume();
    final src = _audio.createBufferSource();
    src.buffer = b;
    final g = _audio.createGain();
    g.gain.value = 0.9;
    src.connect(g);
    g.connect(_audio.destination);
    src.start();
  });
}

/// تحميل مسبق صامت لكل المؤثرات عند إقلاع التطبيق.
void preloadSfx() {
  for (final s in Sfx.values) {
    _load(s);
  }
}
