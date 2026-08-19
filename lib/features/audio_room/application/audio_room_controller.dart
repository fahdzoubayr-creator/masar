import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../core/log/app_log.dart';
import '../config/audio_room_config.dart';
import '../data/demo_link_stub.dart'
    if (dart.library.js_interop) '../data/demo_link_web.dart';
import '../domain/audio_room_models.dart';

/// حالة الاتصال بالقاعة.
enum AudioRoomStatus { connecting, connected, disconnected }

/// يتحكم في جلسة القاعة (صوت وصورة):
/// - اتصال LiveKit حقيقي (مايك + كاميرا) عند توفر البيانات.
/// - وضع تجريبي محلي عند غيابها: يحاكي الحاضرين والكلام واليد والشات والفيديو.
///
/// أحداث اليد والكتم والشات تُمرر عبر قناة بيانات LiveKit، والصوت والفيديو عبر
/// قنوات الوسائط المباشرة. الواجهة تستمع إلى هذا المُتحكم عبر [ChangeNotifier].
class AudioRoomController extends ChangeNotifier {
  AudioRoomController({
    required this.roomName,
    required this.displayName,
    required this.isCoordinator,
  });

  /// رمز القاعة (اسم الغرفة في LiveKit).
  final String roomName;

  final String displayName;
  final bool isCoordinator;

  AudioRoomStatus _status = AudioRoomStatus.disconnected;
  AudioRoomStatus get status => _status;
  bool get connecting => _status == AudioRoomStatus.connecting;
  bool get connected => _status == AudioRoomStatus.connected;

  /// هل نعمل في الوضع التجريبي (بدون بيانات LiveKit)؟
  bool get isDemo => !AudioRoomConfig.isConfigured;

  /// وصف يُعرض للمستخدم (مثل سبب عدم الاتصال).
  String get modeLabel => isDemo ? 'وضع تجريبي' : 'مباشر';

  String? _error;
  String? get error => _error;

  lk.Room? _room;
  final Map<String, RoomParticipant> _participants = {};
  final List<RoomChatMessage> _messages = [];
  final Set<String> _handRaised = {};
  final Set<String> _speaking = {};
  final Set<String> _muted = {};

  bool _micEnabled = false;
  bool get micEnabled => _micEnabled;

  bool _cameraEnabled = false;
  bool get cameraEnabled => _cameraEnabled;

  /// هل فشل فتح الكاميرا في الوضع التجريبي (رفض الإذن أو لا كاميرا)؟
  bool _cameraFailed = false;
  bool get cameraFailed => _cameraFailed;

  /// في الوضع التجريبي نلتقط المايك والكاميرا محلياً عبر flutter_webrtc
  /// حتى تبقى تجربة التحكم (وخاصة الكاميرا) حقيقية دون خادم.
  lk.LocalVideoTrack? _demoCameraTrack;
  lk.LocalAudioTrack? _demoMicTrack;

  /// دقة الكاميرا الافتراضية 480p/SD لخفّة البثّ وتقليل استهلاك البيانات.
  static const lk.CameraCaptureOptions cameraSdOptions = lk.CameraCaptureOptions(
    cameraPosition: lk.CameraPosition.front,
    params: lk.VideoParametersPresets.h480_43,
  );

  /// من يحمل «الكلمة» الآن (يُسمح له وحده بالكلام) — المنسق افتراضياً.
  String? _micHolderSid;
  String? get micHolderSid => _micHolderSid;
  String? get micHolderName => _participants[_micHolderSid]?.name;

  /// من يحمل صلاحية الكاميرا الآن (كاميرا واحدة فقط في القاعة) — المنسق افتراضياً.
  String? _cameraHolderSid;
  String? get cameraHolderSid => _cameraHolderSid;
  String? get cameraHolderName => _participants[_cameraHolderSid]?.name;

  /// هل يُسمح للمستخدم المحلي بالكلام الآن؟
  bool get canSpeak => isCoordinator || _micHolderSid == _meSid;

  /// هل يُسمح للمستخدم المحلي ببثّ صورته الآن؟
  bool get canUseCamera => isCoordinator || _cameraHolderSid == _meSid;

  bool _handRaisedLocal = false;
  bool get handRaised => _handRaisedLocal;

  /// طلبات الحاضرين فتحَ مايك/كاميرا المنسق (أسماء مقدمي الطلبات).
  final Set<String> _micRequests = {};
  final Set<String> _cameraRequests = {};
  List<String> get micRequests => List.unmodifiable(_micRequests);
  List<String> get cameraRequests => List.unmodifiable(_cameraRequests);

  /// هل طلب الزائر فتح مايك/كاميرا المنسق؟ (يُلغى «بانتظار» عند التلبية).
  bool _myMicRequested = false;
  bool _myCameraRequested = false;
  bool get myMicRequested => _myMicRequested;
  bool get myCameraRequested => _myCameraRequested;

  List<RoomParticipant> get participants {
    final list = _participants.values.toList()
      ..sort((a, b) {
        if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
        if (a.isCoordinator != b.isCoordinator) return a.isCoordinator ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return list;
  }

  /// اسم منسق القاعة (صاحب شارة «منسق») — يظهر تحت اسم القاعة في الأعلى.
  String? get coordinatorName {
    for (final p in _participants.values) {
      if (p.isCoordinator) return p.name;
    }
    return isCoordinator ? displayName : null;
  }

  /// المشاركون الذين يبثّون صورهم الآن (الكاميرا مفتوحة) — تُعرض شبكتهم
  /// في أعلى شاشة القاعة.
  List<RoomParticipant> get videoParticipants =>
      participants.where((p) => p.cameraEnabled).toList();

  /// من رفعوا أيديهم (باستثناء المستخدم) — يُعرضون في قسم «يطلبون الكلمة».
  List<RoomParticipant> get handRaisedParticipants =>
      participants.where((p) => p.handRaised && !p.isMe).toList();

  /// هل يتحدث المستخدم نفسه الآن؟
  bool get isMeSpeaking =>
      participants.any((p) => p.isMe && p.isSpeaking && p.micEnabled);

  List<RoomChatMessage> get messages => List.unmodifiable(_messages);

  // ===== دورة الحياة =====

  Future<void> connect() async {
    if (_status == AudioRoomStatus.connected ||
        _status == AudioRoomStatus.connecting) {
      return;
    }
    _status = AudioRoomStatus.connecting;
    _error = null;
    notifyListeners();

    if (isDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (_status != AudioRoomStatus.connecting) return;
      _startDemo();
      _applyDefaultPermissions();
      _status = AudioRoomStatus.connected;
      notifyListeners();
      _startDemoSync();
      if (isCoordinator) {
        await _setCamera(true);
      }
      return;
    }

    try {
      final token = _buildToken();
      final room = lk.Room(
        roomOptions:
            const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      await room.connect(AudioRoomConfig.livekitUrl, token);
      _room = room;
      _wireRoomEvents();
      _applyDefaultPermissions();
      _status = AudioRoomStatus.connected;
      notifyListeners();
      if (isCoordinator) {
        await _setCamera(true);
      }
    } catch (e) {
      _status = AudioRoomStatus.disconnected;
      _error = e.toString();
      AppLog.error('LiveKit connect failed: $e');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _status = AudioRoomStatus.disconnected;
    _micHolderSid = null;
    _cameraHolderSid = null;
    _publishDemoLeave();
    DemoLink.unsubscribe();
    await _stopDemoDevices();
    try {
      await _room?.disconnect();
    } catch (_) {}
    _room = null;
    notifyListeners();
  }

  Future<void> _stopDemoDevices() async {
    await _demoCameraTrack?.dispose();
    _demoCameraTrack = null;
    await _demoMicTrack?.dispose();
    _demoMicTrack = null;
  }

  /// يولّد توكن الدخول HS256 من مفتاح API وسره — بنفس صيغة LiveKit.
  String _buildToken() {
    final now = DateTime.now().toUtc();
    final payload = <String, Object?>{
      'exp': now.add(const Duration(hours: 6)).millisecondsSinceEpoch ~/ 1000,
      'nbf': now.millisecondsSinceEpoch ~/ 1000,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'iss': AudioRoomConfig.apiKey,
      'sub': '${displayName}_${now.millisecondsSinceEpoch}',
      'name': displayName,
      'metadata': jsonEncode({'role': isCoordinator ? 'coordinator' : 'member'}),
      'video': {
        'room': AudioRoomConfig.liveKitRoomName(roomName),
        'roomJoin': true,
        'canPublish': true,
        'canSubscribe': true,
        'canPublishData': true,
      },
    };
    return jwt.JWT(payload, header: const {'alg': 'HS256', 'typ': 'JWT'})
        .sign(jwt.SecretKey(AudioRoomConfig.apiSecret),
            algorithm: jwt.JWTAlgorithm.HS256)
        .toString();
  }

  // ===== أحداث LiveKit =====

  void _wireRoomEvents() {
    final room = _room;
    if (room == null) return;

    _syncAllParticipants();

    room.events
      ..on<lk.ParticipantConnectedEvent>((event) {
        _syncAllParticipants();
        // وصول منضم جديد → نخبره من يملك الكلمة والكاميرا.
        if (isCoordinator) _broadcastPermissions();
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        final sid = event.participant.sid;
        _participants.remove(sid);
        _handRaised.remove(sid);
        _speaking.remove(sid);
        _muted.remove(sid);
        notifyListeners();
      })
      ..on<lk.ActiveSpeakersChangedEvent>((event) {
        _speaking
          ..clear()
          ..addAll(event.speakers.map((p) => p.sid));
        _syncAllParticipants();
      })
      ..on<lk.TrackPublishedEvent>((event) {
        _syncAllParticipants();
      })
      ..on<lk.TrackUnpublishedEvent>((event) {
        _syncAllParticipants();
      })
      ..on<lk.TrackSubscribedEvent>((event) {
        _syncAllParticipants();
      })
      ..on<lk.TrackUnsubscribedEvent>((event) {
        _syncAllParticipants();
      })
      ..on<lk.TrackMutedEvent>((event) {
        if (event.publication.source == lk.TrackSource.microphone) {
          _muted.add(event.participant.sid);
        }
        _updateParticipant(event.participant);
        notifyListeners();
      })
      ..on<lk.TrackUnmutedEvent>((event) {
        if (event.publication.source == lk.TrackSource.microphone) {
          _muted.remove(event.participant.sid);
        }
        _updateParticipant(event.participant);
        notifyListeners();
      })
      ..on<lk.DataReceivedEvent>((event) async {
        await _onDataReceived(event);
      });
  }

  void _syncAllParticipants() {
    final room = _room;
    if (room == null) return;

    final local = room.localParticipant;
    if (local != null) _updateParticipant(local);

    for (final p in room.remoteParticipants.values) {
      _updateParticipant(p);
    }
    notifyListeners();
  }

  void _updateParticipant(lk.Participant p) {
    final micOn = _muted.contains(p.sid)
        ? false
        : p.isMicrophoneEnabled();
    _participants[p.sid] = RoomParticipant(
      id: p.sid,
      name: p.name.isNotEmpty ? p.name : p.identity,
      isMe: p.sid == _room?.localParticipant?.sid,
      micEnabled: micOn,
      cameraEnabled: p.isCameraEnabled(),
      hasMic: _micHolderSid == p.sid,
      hasCamera: _cameraHolderSid == p.sid,
      handRaised: _handRaised.contains(p.sid),
      isSpeaking: _speaking.contains(p.sid),
      isCoordinator: _roleFromMetadata(p.metadata) == 'coordinator',
    );
  }

  /// يعيد بثّ الكاميرا الحقيقي للمشارك إذا كانت مفتوحة ومشتركة،
  /// وإلا `null` (تُعرض بلاطة بديلة بصورته الرمزية).
  lk.VideoTrack? cameraTrackOf(String sid) {
    if (isDemo && sid == _meSid) {
      return _demoCameraTrack;
    }
    final room = _room;
    if (room == null) return null;
    final participants = <lk.Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
    for (final p in participants) {
      if (p.sid != sid) continue;
      if (!p.isCameraEnabled()) return null;
      final track = p.getTrackPublicationBySource(lk.TrackSource.camera)?.track;
      return track is lk.VideoTrack ? track : null;
    }
    return null;
  }

  String _roleFromMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return 'member';
    try {
      final map = jsonDecode(metadata) as Map<String, dynamic>;
      return (map['role'] as String?) ?? 'member';
    } catch (_) {
      return 'member';
    }
  }

  Future<void> _onDataReceived(lk.DataReceivedEvent event) async {
    final sid = event.participant?.sid;
    switch (event.topic) {
      case RoomDataTopics.hand:
        final action = utf8.decode(event.data);
        if (sid == null) return;
        if (action == 'raise') {
          _handRaised.add(sid);
        } else {
          _handRaised.remove(sid);
        }
        _refreshHand(sid);
        notifyListeners();
      case RoomDataTopics.coordinator:
        final map = _decodeJson(event.data);
        final action = map?['action'];
        final target = map?['target'] as String?;
        final me = _room?.localParticipant?.sid;
        switch (action) {
          case 'mute':
            if (target == me) {
              await _setMic(false);
              _handRaisedLocal = false;
              _refreshHand('self');
            } else if (target != null) {
              _muted.add(target);
              _refreshMute(target);
            }
          case 'grant':
            if (target != null) {
              _muted.remove(target);
              _micHolderSid = target;
              if (target == me) {
                await _setMic(true);
              } else if (me != null && !isCoordinator) {
                await _setMic(false);
              }
            }
          case 'revoke':
            if (target == me) await _setMic(false);
            if (_micHolderSid == target) _micHolderSid = null;
          case 'grantCamera':
            if (target != null) {
              _cameraHolderSid = target;
              if (target == me) {
                await _setCamera(true);
              } else if (me != null && !isCoordinator) {
                await _setCamera(false);
              }
            }
          case 'revokeCamera':
            if (target == me) await _setCamera(false);
            if (_cameraHolderSid == target) _cameraHolderSid = null;
          case 'micFulfilled':
            _myMicRequested = false;
            _refreshSelf();
          case 'cameraFulfilled':
            _myCameraRequested = false;
            _refreshSelf();
        }
        _updateTokens();
        notifyListeners();
      case RoomDataTopics.request:
        final map = _decodeJson(event.data);
        final action = map?['action'];
        final requester = _nameForSid(sid) ??
            event.participant?.identity ??
            'مشارك';
        switch (action) {
          case 'requestMic':
            _micRequests.add(requester);
          case 'requestCamera':
            _cameraRequests.add(requester);
          case 'cancelMic':
            _micRequests.remove(requester);
          case 'cancelCamera':
            _cameraRequests.remove(requester);
        }
        notifyListeners();
      case RoomDataTopics.chat:
        final map = _decodeJson(event.data);
        final text = (map?['text'] as String?)?.trim();
        if (text == null || text.isEmpty) return;
        _messages.add(RoomChatMessage(
          id: 'lk_${_messages.length}_${DateTime.now().microsecondsSinceEpoch}',
          senderId: sid ?? 'remote',
          senderName: map?['sender'] ?? _nameForSid(sid) ?? 'مشارك',
          text: text,
          isMe: false,
          sentAt: DateTime.now(),
        ));
        notifyListeners();
    }
  }

  String? _nameForSid(String? sid) {
    if (sid == null) return null;
    return _participants[sid]?.name;
  }

  Map<String, dynamic>? _decodeJson(List<int> data) {
    try {
      return jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _refreshHand(String sid) {
    final p = _participants[sid];
    if (p == null) return;
    _participants[sid] = p.copyWith(handRaised: _handRaised.contains(sid));
  }

  void _refreshMute(String sid) {
    final p = _participants[sid];
    if (p == null) return;
    _participants[sid] = p.copyWith(micEnabled: false);
  }

  // ===== إجراءات المستخدم =====

  /// تشغيل/إيقاف المايك.
  ///
  /// - المنسق: الزر يمنح/يسحب الكلمة لنفسه.
  /// - الحاضر: لا يتكلم إلا إذا ملك الكلمة (وإلا الزر مقفل).
  Future<void> toggleMic() async {
    final me = _meSid;
    if (isCoordinator) {
      if (_micEnabled) {
        await revokeMic(me);
      } else {
        await grantMic(me);
      }
    } else {
      if (_micHolderSid != me) return;
      await _setMic(!_micEnabled);
    }
  }

  Future<void> _setMic(bool enable) async {
    _micEnabled = enable;
    if (isDemo) {
      if (enable) {
        if (_demoMicTrack == null) {
          try {
            _demoMicTrack = await lk.LocalAudioTrack.create();
          } catch (_) {
            _micEnabled = false;
          }
        }
        _speakDemo(_meSid);
      } else {
        await _demoMicTrack?.dispose();
        _demoMicTrack = null;
        _speaking.remove(_meSid);
      }
    } else {
      try {
        await _room?.localParticipant?.setMicrophoneEnabled(enable);
      } catch (_) {}
    }
    _refreshSelf();
    _publishDemoSnapshot();
    notifyListeners();
  }

  /// تشغيل/إيقاف الكاميرا (صوت وصورة).
  ///
  /// - المنسق: الزر يمنح/يسحب الكاميرا لنفسه (كاميرا واحدة فقط في القاعة).
  /// - الحاضر: لا يبثّ صورته إلا إذا ملك صلاحية الكاميرا (وإلا الزر مقفل).
  Future<void> toggleCamera() async {
    final me = _meSid;
    if (isCoordinator) {
      if (_cameraEnabled) {
        await revokeCamera(me);
      } else {
        await grantCamera(me);
      }
    } else {
      if (_cameraHolderSid != me) return;
      await _setCamera(!_cameraEnabled);
    }
  }

  Future<void> _setCamera(bool enable) async {
    _cameraEnabled = enable;
    if (isDemo) {
      if (enable) {
        if (_demoCameraTrack == null) {
          try {
            _cameraFailed = false;
            _demoCameraTrack =
                await lk.LocalVideoTrack.createCameraTrack(cameraSdOptions);
          } catch (_) {
            _cameraEnabled = false;
            _cameraFailed = true;
          }
        }
      } else {
        _cameraFailed = false;
        await _demoCameraTrack?.dispose();
        _demoCameraTrack = null;
      }
    } else {
      try {
        await _room?.localParticipant?.setCameraEnabled(
          enable,
          cameraCaptureOptions: cameraSdOptions,
        );
      } catch (_) {}
    }
    _refreshSelf();
    _publishDemoSnapshot();
    notifyListeners();
  }

  /// رفع/إنزال اليد.
  Future<void> toggleHand() async {
    _handRaisedLocal = !_handRaisedLocal;
    _publish(
        RoomDataTopics.hand, utf8.encode(_handRaisedLocal ? 'raise' : 'lower'));
    _refreshSelf();
    _publishDemoSnapshot();
    notifyListeners();
  }

  /// (الزائر) يطلب/يلغي طلب فتح مايك المنسق.
  Future<void> requestCoordinatorMic() async {
    _myMicRequested = !_myMicRequested;
    _publish(
        RoomDataTopics.request,
        utf8.encode(
            jsonEncode({'action': _myMicRequested ? 'requestMic' : 'cancelMic'})));
    _publishDemoSnapshot();
    notifyListeners();
  }

  /// (الزائر) يطلب/يلغي طلب فتح كاميرا المنسق.
  Future<void> requestCoordinatorCamera() async {
    _myCameraRequested = !_myCameraRequested;
    _publish(
        RoomDataTopics.request,
        utf8.encode(jsonEncode(
            {'action': _myCameraRequested ? 'requestCamera' : 'cancelCamera'})));
    _publishDemoSnapshot();
    notifyListeners();
  }

  /// (المنسق) يفتح مايكه فوراً تلبيةً لطلبات الحاضرين.
  Future<void> openMyMic() async {
    if (!isCoordinator) return;
    _micRequests.clear();
    _publishCoordinator('micFulfilled', null);
    await grantMic(_meSid);
  }

  /// (المنسق) يفتح كاميرته فوراً تلبيةً لطلبات الحاضرين.
  Future<void> openMyCamera() async {
    if (!isCoordinator) return;
    _cameraRequests.clear();
    _publishCoordinator('cameraFulfilled', null);
    await grantCamera(_meSid);
  }

  /// إرسال رسالة في الشات.
  Future<void> sendChat(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final me = _meSid;
    _messages.add(RoomChatMessage(
      id: 'local_${_messages.length}_${DateTime.now().microsecondsSinceEpoch}',
      senderId: me,
      senderName: displayName,
      text: clean,
      isMe: true,
      sentAt: DateTime.now(),
    ));
    _publish(RoomDataTopics.chat,
        utf8.encode(jsonEncode({'text': clean, 'sender': displayName})));
    notifyListeners();
  }

  /// كتم مشارك (من قبل المنسق).
  Future<void> muteParticipant(String sid) async {
    _muted.add(sid);
    _handRaised.remove(sid);
    _refreshMute(sid);
    _refreshHand(sid);
    _publish(RoomDataTopics.coordinator,
        utf8.encode(jsonEncode({'action': 'mute', 'target': sid})));
    if (isDemo && sid != _meSid) {
      _speaking.remove(sid);
    }
    notifyListeners();
  }

  Future<void> _publish(String topic, List<int> data) async {
    try {
      await _room?.localParticipant
          ?.publishData(data, reliable: true, topic: topic);
    } catch (_) {}
  }

  Future<void> _publishCoordinator(String action, String? target) =>
      _publish(RoomDataTopics.coordinator,
          utf8.encode(jsonEncode({'action': action, 'target': target})));

  /// يضبط الصلاحيات الافتراضية عند الدخول: المنسق يملك الكلمة والكاميرا،
  /// والحاضر لا يملك شيئاً حتى يُمنح.
  void _applyDefaultPermissions() {
    final me = _meSid;
    if (isCoordinator) {
      _micHolderSid = me;
      _cameraHolderSid = me;
    } else {
      _micHolderSid = null;
      _cameraHolderSid = null;
    }
    _updateTokens();
    if (!isDemo) _broadcastPermissions();
  }

  /// يُعيد بثّ من يملك الكلمة والكاميرا (للقادمين الجدد).
  void _broadcastPermissions() {
    final mh = _micHolderSid;
    final ch = _cameraHolderSid;
    if (mh != null) _publishCoordinator('grant', mh);
    if (ch != null) _publishCoordinator('grantCamera', ch);
  }

  /// يحدّث شارات «الكلمة» و«الكاميرا» لكل الحاضرين حسب المالك الحالي.
  void _updateTokens() {
    final isDemoMode = isDemo;
    for (final entry in _participants.entries.toList()) {
      final p = entry.value;
      _participants[p.id] = p.copyWith(
        hasMic: _micHolderSid == p.id,
        hasCamera: _cameraHolderSid == p.id,
        // في الوضع التجريبي نعكس الصلاحية على أجهزة الحاضرين الوهميين
        // مباشرة (مكتومون/كاميراتهم مطفأة ما لم يملكوا الصلاحية).
        micEnabled: isDemoMode && !p.isMe
            ? (_micHolderSid == p.id)
            : p.micEnabled,
        cameraEnabled: isDemoMode && !p.isMe
            ? (_cameraHolderSid == p.id)
            : p.cameraEnabled,
      );
    }
  }

  // ===== نظام تمرير الكلمة والكاميرا =====

  /// (المنسق) يمنح الكلمة لمشارك — فيصبح وحده القادر على الكلام.
  Future<void> grantMic(String sid) async {
    if (!isCoordinator) return;
    _muted.remove(sid);
    final previous = _micHolderSid;
    if (previous != null && previous != sid) {
      await _publishCoordinator('revoke', previous);
      if (previous == _meSid) await _setMic(false);
    }
    _micHolderSid = sid;
    await _publishCoordinator('grant', sid);
    if (sid == _meSid) {
      _micRequests.clear();
      await _setMic(true);
    }
    _updateTokens();
    notifyListeners();
  }

  /// (المنسق) يسحب الكلمة من مشارك — فيصمت ولا يتكلم أحد.
  Future<void> revokeMic(String sid) async {
    if (!isCoordinator) return;
    await _publishCoordinator('revoke', sid);
    if (_micHolderSid == sid) {
      _micHolderSid = null;
      if (sid == _meSid) await _setMic(false);
    }
    _updateTokens();
    notifyListeners();
  }

  /// (المنسق) يمنح الكاميرا لمشارك — كاميرا واحدة فقط: تتوقف كاميرا
  /// صاحبها السابق (المنسق غالباً) وتُفتح كاميرا المشارك الجديد.
  Future<void> grantCamera(String sid) async {
    if (!isCoordinator) return;
    final previous = _cameraHolderSid;
    if (previous != null && previous != sid) {
      await _publishCoordinator('revokeCamera', previous);
      if (previous == _meSid) await _setCamera(false);
    }
    _cameraHolderSid = sid;
    await _publishCoordinator('grantCamera', sid);
    if (sid == _meSid) {
      _cameraRequests.clear();
      await _setCamera(true);
    }
    _updateTokens();
    notifyListeners();
  }

  /// (المنسق) يسحب الكاميرا من مشارك — لا يبث أحد صورته بعد.
  Future<void> revokeCamera(String sid) async {
    if (!isCoordinator) return;
    await _publishCoordinator('revokeCamera', sid);
    if (_cameraHolderSid == sid) {
      _cameraHolderSid = null;
      if (sid == _meSid) await _setCamera(false);
    }
    _updateTokens();
    notifyListeners();
  }

  // ===== الوضع التجريبي =====

  String get _meSid => _room?.localParticipant?.sid ?? 'me';

  void _startDemo() {
    final me = RoomParticipant(
      id: _meSid,
      name: displayName,
      isMe: true,
      isCoordinator: isCoordinator,
      cameraEnabled: _cameraEnabled,
    );
    _participants.clear();
    _participants[me.id] = me;
  }

  // ===== مزامنة الوضع التجريبي بين النوافذ (localStorage) =====
  // كل نافذة تنشر حالتها (جهازها وطلباتها) في مفتاحها الخاص، وتقرأ بقية
  // النوافذ التحديثات فوراً — حتى يمكن تجربة «منسق + زائر» دون LiveKit.

  String get _demoRoomKey =>
      'masar_demo_${AudioRoomConfig.liveKitRoomName(roomName)}';

  String? _lastDemoSnapshot;

  void _startDemoSync() {
    if (!isDemo) return;
    DemoLink.subscribe(_demoRoomKey, _onDemoData);
    for (final payload in DemoLink.readAll(_demoRoomKey)) {
      _onDemoData(payload);
    }
    _publishDemoSnapshot();
  }

  void _publishDemoSnapshot() {
    if (!isDemo || _status != AudioRoomStatus.connected) return;
    final payload = jsonEncode({
      'w': DemoLink.windowId,
      'kind': isCoordinator ? 'coordinator' : 'member',
      'name': displayName,
      'mic': _micEnabled,
      'camera': _cameraEnabled,
      'hand': _handRaisedLocal,
      'micReq': _myMicRequested,
      'camReq': _myCameraRequested,
    });
    if (payload == _lastDemoSnapshot) return;
    _lastDemoSnapshot = payload;
    DemoLink.publish(_demoRoomKey, payload);
  }

  void _publishDemoLeave() {
    if (!isDemo) return;
    DemoLink.publish(
        _demoRoomKey, jsonEncode({'w': DemoLink.windowId, 'left': true}));
  }

  void _onDemoData(String payload) {
    Map<String, dynamic> map;
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final winId = map['w'] as String?;
    if (winId == null || winId == DemoLink.windowId) return;

    if (map['left'] == true) {
      final gone = _participants.remove(winId);
      if (gone != null) {
        _micRequests.remove(gone.name);
        _cameraRequests.remove(gone.name);
      }
      notifyListeners();
      return;
    }

    final kind = map['kind'] as String?;
    final name = (map['name'] as String?) ?? 'مشارك';
    final isCoordinatorPeer = kind == 'coordinator';
    final mic = map['mic'] == true;
    final camera = map['camera'] == true;

    _participants[winId] = RoomParticipant(
      id: winId,
      name: name,
      isMe: false,
      isCoordinator: isCoordinatorPeer,
      micEnabled: mic,
      cameraEnabled: camera,
      hasMic: isCoordinatorPeer ? mic : false,
      hasCamera: isCoordinatorPeer ? camera : false,
      handRaised: map['hand'] == true,
      isSpeaking: false,
    );

    if (isCoordinator) {
      if (!isCoordinatorPeer) {
        _applyRequest(name, map['micReq'] == true, _micRequests);
        _applyRequest(name, map['camReq'] == true, _cameraRequests);
      }
    } else if (isCoordinatorPeer) {
      // تلبية الطلب: المنسق فتح جهازه — يُلغى «بانتظار» تلقائياً.
      if (mic && _myMicRequested) {
        _myMicRequested = false;
        _refreshSelf();
      }
      if (camera && _myCameraRequested) {
        _myCameraRequested = false;
        _refreshSelf();
      }
    }
    notifyListeners();
  }

  static void _applyRequest(String name, bool requested, Set<String> set) {
    if (requested) {
      set.add(name);
    } else {
      set.remove(name);
    }
  }

  void _speakDemo(String sid) {
    _speaking.add(sid);
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      _speaking.remove(sid);
      notifyListeners();
    });
  }

  void _refreshSelf() {
    final me = _participants[_meSid];
    if (me == null) return;
    _participants[_meSid] = me.copyWith(
      micEnabled: _micEnabled,
      cameraEnabled: _cameraEnabled,
      handRaised: _handRaisedLocal,
      isSpeaking: _speaking.contains(_meSid),
    );
  }

  @override
  void dispose() {
    _stopDemoDevices();
    _room?.dispose();
    super.dispose();
  }
}
