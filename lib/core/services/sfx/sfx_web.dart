import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'sfx.dart';

/// تشغيل المؤثرات على الويب عبر WebAudio — سياق دائم واحد وتخزين مؤقت
/// للمخازن المفكوكة؛ المسار القياسي ثم البديل حسب نسخة Flutter.
final Map<Sfx, web.AudioBuffer> _cache = {};
web.AudioContext? _ctx;

/// أصوات صُدَّت بسياسة التشغيل الذاتي وتنتظر أول تفاعل ليُطلقها،
/// مع طابع زمني: ما تجاوز مهلته يُهمَل بدل أن ينفجر متأخراً في وقت غريب.
final List<(Sfx, DateTime)> _pendingAutoplay = [];
const _pendingTtl = Duration(milliseconds: 2200);
bool _unlockHooked = false;

web.AudioContext get _audio => _ctx ??= web.AudioContext();

Future<void> _load(Sfx s) async {
  if (_cache.containsKey(s)) return;
  // path_unlock uses .mpeg extension; others use .wav.
  final ext = s == Sfx.path_unlock ? 'mpeg' : 'wav';
  for (final base in const ['assets/assets/sounds/', 'assets/sounds/']) {
    try {
      final resp = await web.window
          .fetch(Uri.base.resolve('$base${s.name}.$ext').toString().toJS)
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
    if (_audio.state == 'suspended') {
      // متصفح بلا تفاعل سابق: نؤجّل الصوت إلى أول لمسة بدل إسقاطه.
      _pendingAutoplay.add((s, DateTime.now()));
      _hookUnlock();
      keepFlushingPending();
      return;
    }
    _start(b);
  });
}

void _start(web.AudioBuffer b) {
  final src = _audio.createBufferSource();
  src.buffer = b;
  final g = _audio.createGain();
  g.gain.value = 0.9;
  src.connect(g);
  g.connect(_audio.destination);
  src.start();
}

/// صوت فتح المسار — يشغّل ملف path_unlock.mpeg.
void playRisingSfx() {
  _load(Sfx.path_unlock).then((_) {
    final b = _cache[Sfx.path_unlock];
    if (b == null) return;
    if (_audio.state == 'suspended') {
      _audio.resume();
    }
    _start(b);
  });
}

/// يفكّ تعليق السياق عند أول تفاعل ثم يُطلق ما انتظر من الأصوات.
/// يُسجَّل مرة واحدة فقط لكل صفحة.
void _hookUnlock() {
  if (_unlockHooked) return;
  _unlockHooked = true;
  final handler = ((web.Event _) {
    _audio.resume().toDart.then((_) => _flushPending());
  }).toJS;
  web.document.addEventListener('pointerdown', handler);
  web.document.addEventListener('keydown', handler);
}

void _flushPending() {
  final now = DateTime.now();
  final due = <Sfx>[];
  _pendingAutoplay.retainWhere((e) {
    if (now.difference(e.$2) <= _pendingTtl) {
      due.add(e.$1);
      return false;
    }
    return true; // منتهي الصلاحية: يُحذف بصمت
  });
  for (final s in due) {
    final b = _cache[s];
    if (b != null) _start(b);
  }
}

/// استئناف استباقي لسياق الصوت — يُستدعى مع أول تفاعل ممكن.
void primeAudio() {
  if (_audio.state == 'suspended') {
    _audio.resume();
    _hookUnlock();
    keepFlushingPending();
  }
}

/// تحميل مسبق صامت لكل المؤثرات عند إقلاع التطبيق.
void preloadSfx() {
  for (final s in Sfx.values) {
    _load(s);
  }
}

/// مهلة أمان تُفرغ الانتظار إن عاد السياق للعمل وحده (سياسات بعض المتصفحات).
Timer? _watchdog;

void keepFlushingPending() {
  _watchdog?.cancel();
  _watchdog = Timer.periodic(const Duration(milliseconds: 400), (t) {
    if (_pendingAutoplay.isEmpty) {
      t.cancel();
      return;
    }
    _flushPending();
    if (_pendingAutoplay.isEmpty || _audio.state == 'running') {
      t.cancel();
    }
  });
}
