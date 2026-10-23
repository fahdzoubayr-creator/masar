import 'package:flutter/material.dart';
import 'package:masar_app/features/audio_room/presentation/screens/audio_room_lobby_screen.dart';
import 'package:masar_app/features/history/presentation/screens/history_screen.dart';
import 'package:masar_app/features/home/presentation/screens/jawaaher_game_screen.dart';
import 'package:masar_app/features/mindmaps/presentation/screens/mind_maps_screen.dart';
import 'package:masar_app/features/quiz/presentation/screens/quiz_picker_screen.dart';
import 'package:masar_app/features/review/presentation/screens/review_space_screen.dart';

/// فضاءات لوحة التحضير — معرّف ثابت لكل بطاقة يسمح بتمرير البطاقة
/// المقصودة عبر واجهة التسجيل ثم فتحها تلقائياً (دون اعتماد دائري).
enum DashboardSpace {
  review,
  quiz,
  jawaaher,
  history,
  mindMaps,
  liveRoom,
}

/// اسم التخزين لكل فضاء (يُمرَّر كنص عبر [DummyAuthScreen.nextSpace]).
extension DashboardSpaceId on DashboardSpace {
  String get id => name;

  static DashboardSpace? fromId(String? id) {
    if (id == null) return null;
    for (final s in DashboardSpace.values) {
      if (s.name == id) return s;
    }
    return null;
  }

  /// الشاشة الموافقة للفضاء.
  Widget build() {
    switch (this) {
      case DashboardSpace.review:
        return const ReviewSpaceScreen();
      case DashboardSpace.quiz:
        return const QuizPickerScreen();
      case DashboardSpace.jawaaher:
        return const JawaaherGameScreen();
      case DashboardSpace.history:
        return const HistoryScreen();
      case DashboardSpace.mindMaps:
        return const MindMapsScreen();
      case DashboardSpace.liveRoom:
        return const AudioRoomLobbyScreen();
    }
  }
}
