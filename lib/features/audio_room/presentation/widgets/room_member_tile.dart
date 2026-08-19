import 'package:flutter/material.dart';

import '../../domain/audio_room_models.dart';
import 'room_palette.dart';

/// صف مشارك في قائمة الأعضاء: صورة رمزية + الاسم + الدور + الشارات
/// (🔇 مكتوم / ✋ رافع اليد / 🎙️ صاحب الكلمة / 📹 صاحب الكاميرا) وحلقة
/// خضراء عند الكلام. زر الكتم يظهر للمنسق فقط.
class RoomMemberTile extends StatelessWidget {
  const RoomMemberTile({
    super.key,
    required this.participant,
    this.isCoordinatorView = false,
    this.onMute,
  });

  final RoomParticipant participant;
  final bool isCoordinatorView;
  final VoidCallback? onMute;

  @override
  Widget build(BuildContext context) {
    final p = participant;
    final canMute = isCoordinatorView && !p.isMe;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: RoomPalette.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RoomPalette.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _Avatar(participant: p),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: p.isMe ? FontWeight.w700 : FontWeight.w600,
                          color: p.isMe ? RoomPalette.green : RoomPalette.text,
                        ),
                      ),
                    ),
                    if (p.isCoordinator) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: RoomPalette.amber.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'منسق',
                          style: TextStyle(
                            fontSize: 9,
                            color: RoomPalette.amber,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (p.isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: RoomPalette.green.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'أنت',
                          style: TextStyle(
                            fontSize: 9,
                            color: RoomPalette.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _status(p),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: p.hasMic || p.hasCamera
                        ? RoomPalette.green
                        : (p.micEnabled ? RoomPalette.muted : RoomPalette.red),
                  ),
                ),
              ],
            ),
          ),
          _Badges(participant: p),
          if (canMute) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onMute,
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              tooltip: 'كتم',
              icon: Icon(
                p.micEnabled ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: p.micEnabled ? RoomPalette.red : RoomPalette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _status(RoomParticipant p) {
    if (p.hasMic && p.hasCamera) return 'يملك الكلمة والكاميرا';
    if (p.hasMic) return 'يملك الكلمة';
    if (p.hasCamera) return 'يبثّ الكاميرا';
    return p.micEnabled ? 'المايك مفتوح' : 'المايك مكتوم';
  }
}

/// شارات الحالة: 🔇 مكتوم، ✋ رافع اليد، 🎙️ صاحب الكلمة، 📹 صاحب الكاميرا.
class _Badges extends StatelessWidget {
  const _Badges({required this.participant});

  final RoomParticipant participant;

  @override
  Widget build(BuildContext context) {
    final p = participant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!p.micEnabled)
          _chip(icon: Icons.mic_off_rounded, color: RoomPalette.red),
        if (p.handRaised)
          _chip(icon: Icons.back_hand_rounded, color: RoomPalette.amber),
        if (p.hasMic)
          _chip(icon: Icons.record_voice_over_rounded, color: RoomPalette.green),
        if (p.hasCamera)
          _chip(icon: Icons.videocam_rounded, color: RoomPalette.green),
      ],
    );
  }

  Widget _chip({required IconData icon, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(left: 3),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }
}

/// صورة رمزية دائرية بحلقة خضراء نابضة عند الكلام.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.participant});

  final RoomParticipant participant;

  static const List<Color> _palette = [
    Color(0xFF5b8def),
    Color(0xFFef8354),
    Color(0xFF8a63d2),
    Color(0xFF3fb99a),
    Color(0xFFd65db1),
    Color(0xFFf0932b),
  ];

  Color get _color {
    final p = participant;
    final hash = p.name.codeUnits.fold<int>(
        0, (h, c) => (h * 31 + c) & 0x7FFFFFFF);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final p = participant;
    final speaking = p.isSpeaking && p.micEnabled;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: speaking ? RoomPalette.green : RoomPalette.border,
          width: speaking ? 2.5 : 1,
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: RoomPalette.green.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: CircleAvatar(
        backgroundColor: _color.withValues(alpha: 0.85),
        child: Text(
          p.name.isNotEmpty ? p.name.characters.first : '؟',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
