import 'package:flutter/foundation.dart';

/// مواضيع قناة البيانات داخل قاعة LiveKit — نمرر من خلالها أحداث اليد
/// والكتم والشات، لأن الصوت نفسه يمر عبر قناة الصوت المباشرة.
abstract class RoomDataTopics {
  static const String chat = 'masar_chat';
  static const String hand = 'masar_hand';
  static const String coordinator = 'masar_coordinator';
  static const String request = 'masar_request';
  static const String file = 'masar_file';
}

/// مشارك داخل القاعة الصوتية (صوت وصورة).
@immutable
class RoomParticipant {
  /// المعرف الفريد للمشارك (sid في LiveKit / معرف محلي في الوضع التجريبي).
  final String id;

  /// هوية المشارك في LiveKit (identity) — تُستخدم في طلبات الإشراف
  /// خادمياً (كتم/طرد) لأن RoomService يستهدفها لا الـ sid.
  final String identity;

  final String name;
  final bool isMe;

  /// هل يمتلك المايك الآن (غير مكتوم)؟
  final bool micEnabled;

  /// هل كاميرته مفتوحة الآن (يبث صورته)؟
  final bool cameraEnabled;

  /// هل يحمل «الكلمة» الآن (يُسمح له وحده بالكلام)؟
  final bool hasMic;

  /// هل يحمل صلاحية الكاميرا الآن (يُسمح له وحده ببثّ الصورة)؟
  final bool hasCamera;

  /// هل رفع يده ليطلب الكلمة؟
  final bool handRaised;

  /// هل يتحدث في هذه اللحظة؟
  final bool isSpeaking;

  /// هل المستخدم نفسه منسق القاعة؟
  final bool isCoordinator;

  /// لحظة انضمامه للقاعة (ميلّي ثانية) — أساس ترتيب الأقدمية
  /// في خلافة التنسيق عند مغادرة المنسق دون تعيين.
  final int joinedAtMs;

  const RoomParticipant({
    required this.id,
    this.identity = '',
    required this.name,
    this.isMe = false,
    this.micEnabled = false,
    this.cameraEnabled = false,
    this.hasMic = false,
    this.hasCamera = false,
    this.handRaised = false,
    this.isSpeaking = false,
    this.isCoordinator = false,
    this.joinedAtMs = 0,
  });

  RoomParticipant copyWith({
    String? identity,
    String? name,
    bool? isMe,
    bool? micEnabled,
    bool? cameraEnabled,
    bool? hasMic,
    bool? hasCamera,
    bool? handRaised,
    bool? isSpeaking,
    bool? isCoordinator,
    int? joinedAtMs,
  }) {
    return RoomParticipant(
      id: id,
      identity: identity ?? this.identity,
      name: name ?? this.name,
      isMe: isMe ?? this.isMe,
      micEnabled: micEnabled ?? this.micEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      hasMic: hasMic ?? this.hasMic,
      hasCamera: hasCamera ?? this.hasCamera,
      handRaised: handRaised ?? this.handRaised,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isCoordinator: isCoordinator ?? this.isCoordinator,
      joinedAtMs: joinedAtMs ?? this.joinedAtMs,
    );
  }
}

/// رسالة داخل شات القاعة.
@immutable
class RoomChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;

  /// هل بُعثت من المستخدم نفسه؟
  final bool isMe;

  final DateTime sentAt;

  /// ملف مرفق (نقل الملفات بين المشاركين) — null للرسائل النصية.
  final Uint8List? fileBytes;
  final String? fileName;
  final int? fileSize;

  bool get isFile => fileBytes != null;

  const RoomChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.isMe,
    required this.sentAt,
    this.fileBytes,
    this.fileName,
    this.fileSize,
  });
}
