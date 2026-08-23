import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/audio_room_config.dart';

/// قاعة كما يعرفها دليل الخادم.
class DirectoryRoom {
  final String id;
  final String name;
  final String creatorName;
  final String access; // 'public' أو 'code'

  /// عدد الحاضرين فعلياً الآن (من خادم البث) — 0 عند تعذّر الجلب.
  final int participants;

  /// رمز الدعوة — يظهر فقط لمنشئ القاعة أو منسقيها (يعيده الخادم لهم).
  final String? inviteCode;

  const DirectoryRoom({
    required this.id,
    required this.name,
    required this.creatorName,
    required this.access,
    this.participants = 0,
    this.inviteCode,
  });

  factory DirectoryRoom.fromJson(Map<String, Object?> json) => DirectoryRoom(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        creatorName: '${json['creatorName'] ?? ''}',
        access: '${json['access'] ?? 'public'}',
        participants: (json['participants'] as num?)?.toInt() ?? 0,
        inviteCode: json['inviteCode'] as String?,
      );
}

/// جسر نحو واجهة القاعات في الخادم — يتيح لكل الأجهزة رؤية القاعات
/// المنشورة نفسها في قسم «قاعات مفتوحة»، بدل الاعتماد على التخزين
/// المحلي لكل جهاز على حدة.
class RoomDirectoryService {
  static const Duration _timeout = Duration(seconds: 8);

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AudioRoomConfig.apiBase}$path')
          .replace(queryParameters: query);

  /// حذف قاعة من الدليل — عند التراجع عن إنشاء أو مغادرة المنسق
  /// بخيار الحذف. الخادم يشترط اسم المنشئ، ويقبل المعرّف الداخلي أو
  /// كود الدعوة أو الاسم؛ وإن فشل الكود نعيد المحاولة بالاسم.
  static Future<void> unpublish(
    String code, {
    String? name,
    String? creatorName,
  }) async {
    final query = (creatorName == null || creatorName.isEmpty)
        ? null
        : {'name': creatorName};
    Future<void> del(String key) async {
      try {
        await http
            .delete(_uri('/api/rooms/${Uri.encodeComponent(key)}', query))
            .timeout(_timeout);
      } catch (_) {
        // أفضل جهد — القاعة ستنقضي من تلقاء نفسها بلا نشاط.
      }
    }

    await del(code);
    final n = name?.trim() ?? '';
    if (n.isNotEmpty && n.toLowerCase() != code.trim().toLowerCase()) {
      await del(n);
    }
  }

  /// كل القاعات المنشورة على الخادم (العامة + الخاصة بقفل).
  /// [viewerName] يجعل الخادم يكشف رموز دعوة قاعات هذا المنشئ.
  static Future<List<DirectoryRoom>> fetchRooms({String? viewerName}) async {
    final res = await http
        .get(_uri('/api/rooms',
            (viewerName == null || viewerName.isEmpty) ? null : {'name': viewerName}))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('فشل جلب القاعات (HTTP ${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, Object?>;
    final list = (body['rooms'] as List<Object?>?) ?? const [];
    return list
        .map((e) =>
            DirectoryRoom.fromJson(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  /// يتحقق من رمز دعوة قاعة خاصة ويعيد بياناتها إن كان الرمز صحيحاً.
  static Future<DirectoryRoom> findByCode(String code) async {
    final res = await http
        .get(_uri('/api/rooms/by-code', {'code': code}))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = 'فشل التحقق من الرمز (HTTP ${res.statusCode})';
      throw Exception(msg);
    }
    final body = jsonDecode(res.body) as Map<String, Object?>;
    final room = body['room'] as Map<Object?, Object?>?;
    if (room == null) throw Exception('استجابة غير متوقعة من الخادم');
    return DirectoryRoom.fromJson(Map<String, Object?>.from(room));
  }

  /// ينشر القاعة على دليل الخادم بعد إنشائها محلياً، ويعيد رمز الدعوة
  /// الرسمي للقاعات الخاصة (null للمفتوحة أو عند تعذر النشر).
  /// الاسم المكرر (409) مقبول — نعيد رمزها من الدليل بصفته منشئها.
  static Future<String?> publish({
    required String name,
    required String creatorName,
    required bool isPublic,
  }) async {
    final res = await http
        .post(
          _uri('/api/rooms'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'creatorName': creatorName,
            'access': isPublic ? 'public' : 'code',
          }),
        )
        .timeout(_timeout);
    if (res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, Object?>;
      final room = body['room'] as Map<Object?, Object?>?;
      return room?['inviteCode'] as String?;
    }
    if (res.statusCode == 409) {
      // القاعة منشورة سابقاً — اجلب رمزها (الخادم يكشفه لمنشئها).
      final rooms = await fetchRooms(viewerName: creatorName);
      for (final r in rooms) {
        if (r.name.trim().toLowerCase() == name.trim().toLowerCase()) {
          return r.inviteCode;
        }
      }
      return null;
    }
    throw Exception('فشل نشر القاعة (HTTP ${res.statusCode})');
  }
}
