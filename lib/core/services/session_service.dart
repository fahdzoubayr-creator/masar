import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _key = 'logged_in_v1';
  static const _nameKey = 'user_name_v1';
  static const _verifiedKey = 'user_verified_v1';
  static const _guestNameKey = 'guest_name_v1';
  static const _monitorKey = 'monitor_v1';
  static const _levelKey = 'school_level_v1';
  static const _specKey = 'specialization_v1';
  static const _trackKey = 'track_v1';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// حالة توثيق الحساب — تُستخدم كبوابة للجلسات المباشرة.
  /// الافتراضي حالياً `true` ليُتاح الدخول للجميع حتى ربطه لاحقاً بنظام PPR.
  static Future<bool> isVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_verifiedKey) ?? true;
  }

  static Future<void> setVerified(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_verifiedKey, value);
  }

  static Future<void> setLoggedIn({String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    if (name != null && name.trim().isNotEmpty) {
      await prefs.setString(_nameKey, name.trim());
    }
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  /// يعيد اسم المستخدم المسجّل إن وُجد، وإلا ينشئ اسماً افتراضياً فريداً
  /// ويثبّته لهذا الجهاز/المتصفح حتى يبقى ثابتاً (دون أي خانة تسجيل).
  static Future<String> resolveUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getString(_nameKey);
    if (registered != null && registered.trim().isNotEmpty) {
      return registered.trim();
    }
    var guest = prefs.getString(_guestNameKey);
    if (guest == null || guest.trim().isEmpty) {
      guest = 'زائر-${Random().nextInt(900000) + 100000}';
      await prefs.setString(_guestNameKey, guest);
    }
    return guest;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_nameKey);
  }

  /// حالة المراقب (صلاحية كاملة) — يفعّلها المالك من إعدادات القاعة.
  static Future<bool> isMonitor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_monitorKey) ?? false;
  }

  static Future<void> setMonitor(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitorKey, enabled);
  }

  static Future<void> setLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_levelKey, level);
  }

  static Future<String?> getLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_levelKey);
  }

  /// المرحلة التعليمية المعيارية المستخدمة لعزل قاعات الجلسات:
  /// 'primary' (ابتدائي) | 'middle' (إعدادي) | 'secondary' (ثانوي).
  /// تعيد null إن لم تُحدَّد مرحلة للمستخدم (كالمشاهد/المراقب) فيرى كل القاعات.
  static Future<String?> resolveStage() async {
    switch (await getLevel()) {
      case 'primary':
        return 'primary';
      case 'middle':
        return 'middle';
      case 'high':
      case 'secondary':
        return 'secondary';
      default:
        return null;
    }
  }

  static Future<void> setSpecialization(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_specKey, value);
  }

  static Future<String?> getSpecialization() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_specKey);
  }

  static Future<void> setTrack(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trackKey, value);
  }

  static Future<String?> getTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_trackKey);
  }
}
