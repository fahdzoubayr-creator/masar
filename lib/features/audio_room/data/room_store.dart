import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// دور المستخدم في القاعة.
enum MasarRoomRole { coordinator, member }

/// قاعة جلسات محفوظة على الجهاز — تُنشأ (المستخدم يصبح منسقاً) أو
/// يُنضم إليها برمز القاعة (مشارك) أو تُدخل من القاعات المفتوحة.
///
/// [isPublic] تعني قاعة «مفتوحة للجميع»: تظهر في قسم القاعات المفتوحة
/// ويدخلها أي أحد بضغطة واحدة دون إدخال رمز.
class MasarRoom {
  final String code;
  final String name;
  final MasarRoomRole role;
  final bool isPublic;
  final DateTime createdAt;
  DateTime lastUsedAt;

  MasarRoom({
    required this.code,
    required this.name,
    required this.role,
    this.isPublic = false,
    required this.createdAt,
    required this.lastUsedAt,
  });

  bool get isCoordinator => role == MasarRoomRole.coordinator;

  MasarRoom copyWith({DateTime? lastUsedAt}) => MasarRoom(
        code: code,
        name: name,
        role: role,
        isPublic: isPublic,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  Map<String, Object?> toJson() => {
        'code': code,
        'name': name,
        'role': role.name,
        'isPublic': isPublic,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  factory MasarRoom.fromJson(Map<String, Object?> json) => MasarRoom(
        code: json['code'] as String,
        name: (json['name'] as String?) ?? (json['code'] as String),
        role: json['role'] == MasarRoomRole.coordinator.name
            ? MasarRoomRole.coordinator
            : MasarRoomRole.member,
        isPublic: json['isPublic'] == true,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// تخزين قائمة قاعات المستخدم محلياً (shared_preferences) حتى تبقى
/// ظاهرة بالترتيب داخل شاشة القاعات، ويمكن الدخول إليها بلمسة واحدة.
class RoomStore {
  RoomStore._();

  static const String _key = 'masar_rooms_v1';

  static Future<List<MasarRoom>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => MasarRoom.fromJson(Map<String, Object?>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<MasarRoom> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(rooms.map((r) => r.toJson()).toList()));
  }

  /// يضيف قاعة جديدة (أو يحدّثها) ويضعها في أعلى القائمة.
  static Future<List<MasarRoom>> upsert(MasarRoom room) async {
    final rooms = await load();
    final index = rooms.indexWhere((r) => r.code == room.code);
    final updated = room.copyWith(lastUsedAt: DateTime.now());
    if (index >= 0) {
      rooms[index] = updated;
    } else {
      rooms.insert(0, updated);
    }
    await _save(rooms);
    return rooms;
  }

  /// يحدّث تاريخ آخر دخول لقاعة قائمة.
  static Future<void> touch(String code) async {
    final rooms = await load();
    final index = rooms.indexWhere((r) => r.code == code);
    if (index < 0) return;
    rooms[index] = rooms[index].copyWith(lastUsedAt: DateTime.now());
    await _save(rooms);
  }

  static Future<List<MasarRoom>> remove(String code) async {
    final rooms = await load();
    rooms.removeWhere((r) => r.code == code);
    await _save(rooms);
    return rooms;
  }
}
