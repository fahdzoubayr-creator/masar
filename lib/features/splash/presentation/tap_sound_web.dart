import 'package:web/web.dart' as web;

/// نقرة الضغط على الويب — تُولَّد لحظياً عبر WebAudio دون ملف أو شبكة،
/// وتعمل من أول لمسة لأنها تُستدعى داخل حدث مستخدم حقيقي.
void playTapSound() {
  final ctx = web.AudioContext();
  final osc = ctx.createOscillator();
  final gain = ctx.createGain();

  // نبضة 1900Hz تتلاشى أُسّياً خلال ~120ms مع دفأة خفيفة — نفس شخصية
  // نقرة button_tap.wav لكنها متزامنة تماماً مع اللمس.
  osc.frequency.value = 1900;
  final t = ctx.currentTime;
  const peak = 0.32;
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(peak, t + 0.008);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);

  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(t);
  osc.stop(t + 0.13);

  // نغمة دفأة منخفضة ثانية تعطي امتلاءً للنقرة.
  final warmth = ctx.createOscillator();
  final wGain = ctx.createGain();
  warmth.frequency.value = 260;
  wGain.gain.setValueAtTime(peak * 0.45, t);
  wGain.gain.exponentialRampToValueAtTime(0.0001, t + 0.09);
  warmth.connect(wGain);
  wGain.connect(ctx.destination);
  warmth.start(t);
  warmth.stop(t + 0.1);

  // إغلاق السياق بعد انتهاء النقرة لتفادي تراكم سياقات صوتية.
  ctx.close();
}
