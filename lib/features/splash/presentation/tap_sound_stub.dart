import 'package:audioplayers/audioplayers.dart';

/// نقرة الضغط خارج الويب (أندرويد/سطح المكتب) — تشغيل ملف الأصل المولد.
final AudioPlayer _tapPlayer = AudioPlayer();

void playTapSound() {
  _tapPlayer.play(AssetSource('sounds/button_tap.wav'));
}
