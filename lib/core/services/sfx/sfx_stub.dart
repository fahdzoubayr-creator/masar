import 'package:audioplayers/audioplayers.dart';
import 'sfx.dart';

/// تشغيل المؤثرات خارج الويب (أندرويد/سطح المكتب) من الأصول المحلية.
final Map<Sfx, AudioPlayer> _players = {
  for (final s in Sfx.values) s: AudioPlayer(),
};

void playSfx(Sfx s) {
  _players[s]!.play(AssetSource('sounds/${s.name}.wav'));
}

/// لا حاجة لتحميل مسبق خارج الويب — الأصول محلية فوراً.
void preloadSfx() {}
