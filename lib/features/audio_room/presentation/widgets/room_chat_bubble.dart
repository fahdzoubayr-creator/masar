import 'package:flutter/material.dart';

import '../../domain/audio_room_models.dart';
import 'room_palette.dart';

/// فقاعة رسالة في شات القاعة: الاسم بلون مميز + الوقت + النص.
class RoomChatBubble extends StatelessWidget {
  const RoomChatBubble({super.key, required this.message});

  final RoomChatMessage message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.isMe;
    final time =
        '${m.sentAt.hour.toString().padLeft(2, '0')}:${m.sentAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine
              ? RoomPalette.green.withValues(alpha: 0.14)
              : RoomPalette.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
          border: Border.all(
            color: mine
                ? RoomPalette.green.withValues(alpha: 0.35)
                : RoomPalette.border.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    m.senderName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: mine
                          ? RoomPalette.green
                          : _nameColor(m.senderName),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: const TextStyle(
                      fontSize: 9.5, color: RoomPalette.muted),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              m.text,
              style: const TextStyle(
                fontSize: 13,
                color: RoomPalette.text,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _nameColor(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    const palette = [
      Color(0xFF5b8def),
      Color(0xFFef8354),
      Color(0xFF8a63d2),
      Color(0xFF3fb99a),
      Color(0xFFd65db1),
      Color(0xFFf0932b),
    ];
    return palette[h % palette.length];
  }
}
