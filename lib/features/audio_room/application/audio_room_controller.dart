import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/log/app_log.dart';
import '../config/audio_room_config.dart';
import '../data/demo_link_stub.dart'
    if (dart.library.js_interop) '../data/demo_link_web.dart';
import '../data/room_keep_alive_stub.dart'
    if (dart.library.io) '../data/room_keep_alive_io.dart';
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
    required bool isCoordinator,
  }) : _isCoordinator = isCoordinator;

  /// رمز القاعة (اسم الغرفة في LiveKit).
  final String roomName;

  final String displayName;

  /// الدور قابل للتغيير: أول من يدخل قاعة مفتوحة فارغة يُرقّى منسقاً
  /// تلقائياً حتى لو دخلها كزائر (قاعدة «أول من يدخل يدير»).
  bool _isCoordinator;
  bool get isCoordinator => _isCoordinator;

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

  /// بيانات جلستنا الصادرة من الخادم — التوكن يُرفق مع طلبات الإشراف
  /// (كتم/طرد) ليثبت الخادم أن الطالب منسق.
  String? _sessionToken;

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
  /// طلبات المايك/الكاميرا الجارية: identity الطالب ← اسمه للعرض.
  /// المفتاح هو الهوية (لا الاسم) حتى لا تتداخل طلبات المتشابهين،
  /// ولا يبدو طلب أحدهم وكأنه من الجميع.
  final Map<String, String> _micRequests = {};
  final Map<String, String> _cameraRequests = {};
  List<MapEntry<String, String>> get micRequests =>
      List.unmodifiable(_micRequests.entries);
  List<MapEntry<String, String>> get cameraRequests =>
      List.unmodifiable(_cameraRequests.entries);

  /// هل طلب الزائر فتح مايك/كاميرا المنسق؟ (يُلغى «بانتظار» عند التلبية).
  bool _myMicRequested = false;
  bool _myCameraRequested = false;
  bool get myMicRequested => _myMicRequested;
  bool get myCameraRequested => _myCameraRequested;

  /// إشعار قيادة يُعرض مرة واحدة في الواجهة (ترقية/تسليم).
  String? leaderNotice;

  /// إشعار طرد موجّه للعضو المطرود — تعرضه الشاشة مرة واحدة.
  String? kickNotice;

  /// لحظة انضمامي — تُستخدم في قاعدة «الأقدم يقود» بعد رحيل المنسق.
  int _joinedAtMs = 0;

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
      await _claimCoordinatorIfFirst();
      _applyDefaultPermissions();
      _status = AudioRoomStatus.connected;
      notifyListeners();
      _startDemoSync();
      await _openCoordinatorDevices();
      return;
    }

    try {
      // التوكن يصدره الخادم الخفي — لا توقيع ولا أسرار داخل التطبيق.
      final session = await _fetchSession();
      final room = lk.Room(
        roomOptions:
            const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      await room.connect(session.url, session.token);
      _room = room;
      _sessionToken = session.token;
      _joinedAtMs = DateTime.now().millisecondsSinceEpoch;
      await _claimCoordinatorIfFirst(room);
      await _loadPersistedChat();
      _wireRoomEvents();
      _applyDefaultPermissions();
      _status = AudioRoomStatus.connected;
      notifyListeners();
      // أندرويد: خدمة الواجهة الأمامية تُبقي الصوت حياً عند إغلاق الشاشة.
      await RoomKeepAlive.start(roomName);
      await _openCoordinatorDevices();
    } catch (e) {
      _status = AudioRoomStatus.disconnected;
      _error = e is RoomSessionException ? e.message : e.toString();
      AppLog.error('LiveKit connect failed: $e');
    }
    notifyListeners();
  }

  /// قاعدة «أول من يدخل يدير»: من دخل قاعة مفتوحة لا يوجد فيها أحد
  /// قبلها يصبح منسقها تلقائياً ولو انضم بصفته زائراً.
  Future<void> _claimCoordinatorIfFirst([lk.Room? liveRoom]) async {
    if (_isCoordinator) return;
    final empty = liveRoom == null
        ? true
        : liveRoom.remoteParticipants.isEmpty;
    if (empty) {
      _isCoordinator = true;
      AppLog.info('promoted to coordinator: first in an empty room');
    }
  }

  /// المنسق يدخل ومايكه وكاميرته مفتوحان — ويغلقها متى شاء بالأزرار.
  Future<void> _openCoordinatorDevices() async {
    if (!_isCoordinator) return;
    try {
      if (!_micEnabled) await _setMic(true);
    } catch (_) {}
    try {
      if (!_cameraEnabled && !_cameraFailed) await _setCamera(true);
    } catch (_) {}
    notifyListeners();
  }

  /// يطلب جلسة انضمام (رابط + توكن) من خدمة التوكنات في الخادم.
  Future<_RoomSession> _fetchSession() async {
    const endpoint = AudioRoomConfig.tokenEndpoint;
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'room': roomName,
              'name': displayName,
              'role': isCoordinator ? 'coordinator' : 'member',
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final url = (map['url'] as String?) ?? '';
        final token = (map['token'] as String?) ?? '';
        if (url.isEmpty || token.isEmpty) {
          throw const RoomSessionException('استجابة غير مكتملة من خدمة القاعات');
        }
        return _RoomSession(
          url: url,
          token: token,
          identity: (map['identity'] as String?) ?? displayName,
        );
      }
      String message = 'خدمة القاعات غير متاحة (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['error'] is String) message = err['error'] as String;
      } catch (_) {}
      throw RoomSessionException(message);
    } on RoomSessionException {
      rethrow;
    } on TimeoutException {
      throw const RoomSessionException('انتهت مهلة الاتصال بخدمة القاعات');
    } catch (_) {
      throw const RoomSessionException('تعذر الوصول إلى خدمة القاعات — تحقق من الإنترنت');
    }
  }

  Future<void> disconnect() async {
    _status = AudioRoomStatus.disconnected;
    _micHolderSid = null;
    _cameraHolderSid = null;
    await RoomKeepAlive.stop();
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
      ..on<lk.ParticipantDisconnectedEvent>((event) async {
        final sid = event.participant.sid;
        _participants.remove(sid);
        _handRaised.remove(sid);
        _speaking.remove(sid);
        _muted.remove(sid);
        // قاعدة «الأقدم يقود»: إن رحل المنسق وبقيت أنت وآخرون،
        // يدّعي كل بادٍ القيادة بعد مهلة عشوائية — وأول إعلان يعتمد.
        if (!_isCoordinator &&
            _status == AudioRoomStatus.connected &&
            _room != null &&
            !_participants.values.any((p) => p.isCoordinator)) {
          Future<void>.delayed(
            Duration(milliseconds: 300 + _joinedAtMs % 700),
            () => claimLeadershipAfterDropout(),
          );
        }
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
      identity: p.identity,
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

  // ===== نقل الملفات بين المشاركين (حتى 40MB عبر قناة البيانات) =====

  final Map<String, _IncomingFile> _incomingFiles = {};
  bool _fileSending = false;

  bool get isSendingFile => _fileSending;

  /// يرسل ملفاً لكل من في القاعة مقسماً إلى قطع base64 عبر قناة البيانات.
  Future<void> sendFile(String name, Uint8List bytes) async {
    if (_fileSending || isDemo) return;
    if (bytes.lengthInBytes > 40 * 1024 * 1024) return;
    _fileSending = true;
    notifyListeners();
    try {
      const chunkRaw = 12000;
      final id = 'f${DateTime.now().microsecondsSinceEpoch}';
      final n = (bytes.lengthInBytes / chunkRaw).ceil();
      await _publish(
        RoomDataTopics.file,
        utf8.encode(jsonEncode({
          'a': 'meta',
          'id': id,
          'name': name,
          'size': bytes.lengthInBytes,
          'n': n,
          'sender': displayName,
        })),
      );
      for (var i = 0; i < n; i++) {
        final start = i * chunkRaw;
        final end =
            (start + chunkRaw) < bytes.lengthInBytes ? (start + chunkRaw) : bytes.lengthInBytes;
        await _publish(
          RoomDataTopics.file,
          utf8.encode(jsonEncode({
            'a': 'c',
            'id': id,
            'i': i,
            'd': base64Encode(bytes.sublist(start, end)),
          })),
        );
      }
      await _publish(RoomDataTopics.file,
          utf8.encode(jsonEncode({'a': 'done', 'id': id})));
      _messages.add(RoomChatMessage(
        id: 'lf_$id',
        senderId: _meSid,
        senderName: displayName,
        text: '',
        isMe: true,
        sentAt: DateTime.now(),
        fileBytes: bytes,
        fileName: name,
        fileSize: bytes.lengthInBytes,
      ));
    } finally {
      _fileSending = false;
      notifyListeners();
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
              _refreshSelf();
            } else if (target != null) {
              _muted.add(target);
              _refreshMute(target);
            }
          case 'approveMic':
            // استجابة المنسق لطلب كلمة: الطالب يملك الكلمة حصرياً.
            if (target != null) {
              _micRequests.remove(target);
              final tSid = _sidForIdentity(target);
              if (tSid != null) {
                _handRaised.remove(tSid);
                _refreshHand(tSid);
                _muted.remove(tSid);
                _micHolderSid = tSid;
              }
              if (target == _myIdentity || target == me) {
                _myMicRequested = false;
                _handRaisedLocal = false;
                await _setMic(true);
              } else if (!isCoordinator && me != null) {
                await _setMic(false);
              }
            }
          case 'approveCamera':
            if (target != null) {
              _cameraRequests.remove(target);
              final tSid = _sidForIdentity(target);
              if (tSid != null) {
                _handRaised.remove(tSid);
                _refreshHand(tSid);
                _cameraHolderSid = tSid;
              }
              if (target == _myIdentity || target == me) {
                _myCameraRequested = false;
                _handRaisedLocal = false;
                await _setCamera(true);
              } else if (!isCoordinator &&
                  me != null &&
                  me != tSid &&
                  _cameraEnabled) {
                // قاعدة القاعة: كاميرا واحدة فقط — من ليس صاحبها ينطفئ.
                await _setCamera(false);
              }
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
          case 'transfer':
            // تسليم القيادة صراحة من المنسق إلى عضو محدد.
            if (target != null &&
                (target == _myIdentity || target == me) &&
                !_isCoordinator) {
              _isCoordinator = true;
              leaderNotice = 'أصبحت منسق هذه القاعة 🎖️';
              await _openCoordinatorDevices();
              _broadcastPermissions();
            }
          case 'claim':
            // أحدهم أعلن قيادته بعد رحيل المنسق — إن كنت مُدّعياً
            // أيضاً فأنتذعن لأول إعلان وصلني.
            if (_isCoordinator && target == null) {
              _isCoordinator = false;
              leaderNotice = null;
            }
          case 'kicked':
            // أمر طرد موجّه إليّ — أعرض السبب ثم أغادر القاعة.
            if (target == _myIdentity || target == me) {
              final r = (map?['reason'] as String?)?.trim() ?? '';
              kickNotice = r.isEmpty
                  ? 'تم إخراجك من القاعة'
                  : 'تم إخراجك من القاعة\nالسبب: $r';
            }
        }
        _updateTokens();
        notifyListeners();
      case RoomDataTopics.request:
        final map = _decodeJson(event.data);
        final action = map?['action'];
        // المفتاح هو هوية الطالب — والاسم للعرض فقط.
        final requesterId = '${map?['id'] ?? event.participant?.identity ?? sid ?? 'مجهول'}';
        final requesterName = '${map?['name'] ?? _nameForSid(sid) ?? event.participant?.identity ?? 'مشارك'}';
        switch (action) {
          case 'requestMic':
            _micRequests[requesterId] = requesterName;
          case 'requestCamera':
            _cameraRequests[requesterId] = requesterName;
          case 'cancelMic':
            _micRequests.remove(requesterId);
          case 'cancelCamera':
            _cameraRequests.remove(requesterId);
        }
        notifyListeners();
      case RoomDataTopics.file:
        // إعادة تجميع الملفات الواردة قطعةً قطعة.
        final map = _decodeJson(event.data);
        if (map == null) return;
        final action = '${map['a']}';
        final id = '${map['id'] ?? ''}';
        if (id.isEmpty) return;
        switch (action) {
          case 'meta':
            final size = (map['size'] as num?)?.toInt() ?? 0;
            if (size > 45 * 1024 * 1024) return;
            _incomingFiles[id] = _IncomingFile(
              name: '${map['name'] ?? 'ملف'}',
              size: size,
              chunks: (map['n'] as num?)?.toInt() ?? 0,
              sender:
                  '${map['sender'] ?? _nameForSid(sid) ?? event.participant?.identity ?? 'مشارك'}',
            );
          case 'c':
            final f = _incomingFiles[id];
            if (f == null) return;
            final i = (map['i'] as num?)?.toInt() ?? -1;
            if (i < 0 || i >= f.chunks) return;
            f.parts[i] = '${map['d']}';
            f.got++;
          case 'done':
            final f = _incomingFiles[id];
            if (f == null) return;
            _incomingFiles.remove(id);
            if (f.got < f.chunks || f.chunks <= 0) return;
            final out = BytesBuilder();
            var ok = true;
            for (final part in f.parts) {
              if (part == null) {
                ok = false;
                break;
              }
              out.add(base64Decode(part));
            }
            if (!ok) return;
            final data = out.takeBytes();
            _messages.add(RoomChatMessage(
              id: 'rf_$id',
              senderId: sid ?? 'remote',
              senderName: f.sender,
              text: '',
              isMe: false,
              sentAt: DateTime.now(),
              fileBytes: data,
              fileName: f.name,
              fileSize: f.size,
            ));
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
        unawaited(_persistChat());
    }
  }

  String? _nameForSid(String? sid) {
    if (sid == null) return null;
    return _participants[sid]?.name;
  }

  /// يجد sid المشارك من هويته (identity) — العكس يلزم لأن رسائل
  /// الإشراف تتنقل بالهوية المستقرة بينما الواجهة تعمل بـsid.
  String? _sidForIdentity(String? identity) {
    if (identity == null || identity.isEmpty) return null;
    for (final e in _participants.entries) {
      if (e.value.identity == identity) return e.key;
    }
    return null;
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

  /// (الزائر) يطلب/يلغي طلب الكلمة — يُرفق معه هوية الطالب واسمه
  /// حتى يعرض المنسق الطلب باسم صاحبه ويستجيب له تحديداً.
  Future<void> requestCoordinatorMic() async {
    _myMicRequested = !_myMicRequested;
    _publish(
        RoomDataTopics.request,
        utf8.encode(jsonEncode({
          'action': _myMicRequested ? 'requestMic' : 'cancelMic',
          'id': isDemo ? displayName : _myIdentity,
          'name': displayName,
        })));
    _publishDemoSnapshot();
    notifyListeners();
  }

  /// (الزائر) يطلب/يلغي طلب الكاميرا — فور الطلب تشتغل كاميرته عنده
  /// (معاينة ذاتية)، وعند موافقة المنسق تصبح البثّ الرسمي الوحيد.
  Future<void> requestCoordinatorCamera() async {
    _myCameraRequested = !_myCameraRequested;
    if (!isDemo) {
      try {
        await _setCamera(_myCameraRequested);
      } catch (_) {}
    }
    _publish(
        RoomDataTopics.request,
        utf8.encode(jsonEncode({
          'action': _myCameraRequested ? 'requestCamera' : 'cancelCamera',
          'id': isDemo ? displayName : _myIdentity,
          'name': displayName,
        })));
    _publishDemoSnapshot();
    notifyListeners();
  }

  /// هوية المستخدم المحلي في القاعة الحية.
  String get _myIdentity => _room?.localParticipant?.identity ?? '';

  /// (منسق) يسلّم القيادة لعضو محدد دون مغادرة القاعة.
  Future<void> transferLeadership(String identity) async {
    if (!isCoordinator || isDemo) return;
    if (identity.isEmpty || identity == _myIdentity) return;
    _publish(RoomDataTopics.coordinator,
        utf8.encode(jsonEncode({'action': 'transfer', 'target': identity})));
    _isCoordinator = false;
    leaderNotice = 'سُلّمت القيادة — أنت عضو الآن';
    notifyListeners();
  }

  /// (بعد رحيل المنسق فجأة) إعلان القيادة — أول إعلان يعتمده الباقون.
  Future<void> claimLeadershipAfterDropout() async {
    if (_isCoordinator || isDemo || _room == null) return;
    if (_status != AudioRoomStatus.connected) return;
    if (_participants.values.any((p) => p.isCoordinator)) return;
    _isCoordinator = true;
    leaderNotice = 'أنت المنسق الآن 🎖️ — الأقدم في القاعة';
    _publish(RoomDataTopics.coordinator,
        utf8.encode(jsonEncode({'action': 'claim', 'target': null})));
    await _openCoordinatorDevices();
    _broadcastPermissions();
    notifyListeners();
  }

  /// (المنسق) استجابة لطلب كلمة مشارك محدد — تمنحه هو الكلمة مباشرة
  /// (وليس فتح مايك المنسق)، وتُنزل يده تلقائياً.
  Future<void> approveMicRequest(String identity) async {
    if (!isCoordinator) return;
    _micRequests.remove(identity);
    final tSid = _sidForIdentity(identity);
    if (tSid != null) {
      _handRaised.remove(tSid);
      _refreshHand(tSid);
      _muted.remove(tSid);
      _micHolderSid = tSid;
    }
    _publishCoordinator('approveMic', identity);
    notifyListeners();
  }

  /// (المنسق) استجابة لطلب كاميرا مشارك محدد — مع تسليمها: تُغلق
  /// كاميرا المنسق ليظهر بثّ الطالب وحده في المسرح.
  Future<void> approveCameraRequest(String identity) async {
    if (!isCoordinator) return;
    _cameraRequests.remove(identity);
    final tSid = _sidForIdentity(identity);
    if (tSid != null) {
      _handRaised.remove(tSid);
      _refreshHand(tSid);
      _cameraHolderSid = tSid;
    }
    if (_cameraEnabled && tSid != _meSid) {
      await revokeCamera(_meSid);
    }
    _publishCoordinator('approveCamera', identity);
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
    unawaited(_persistChat());
  }

  // ===== استمرار الرسائل 24 ساعة لكل قاعة =====

  static const Duration _chatTtl = Duration(hours: 24);

  String get _chatKey => 'room_chat_$roomName';

  Future<void> _persistChat() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final cutoff =
          DateTime.now().subtract(_chatTtl).millisecondsSinceEpoch;
      final list = _messages
          .where((m) => !m.isFile && m.sentAt.millisecondsSinceEpoch >= cutoff)
          .toList();
      if (list.length > 300) list.removeRange(0, list.length - 300);
      await sp.setString(
        _chatKey,
        jsonEncode([
          for (final m in list)
            {
              's': m.senderName,
              't': m.text,
              'me': m.isMe,
              'ms': m.sentAt.millisecondsSinceEpoch,
            }
        ]),
      );
    } catch (_) {}
  }

  Future<void> _loadPersistedChat() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_chatKey);
      if (raw == null || raw.isEmpty) return;
      final arr = jsonDecode(raw) as List;
      final cutoff =
          DateTime.now().subtract(_chatTtl).millisecondsSinceEpoch;
      for (final e in arr) {
        if (e is! Map) continue;
        final ms = (e['ms'] as num?)?.toInt() ?? 0;
        if (ms < cutoff) continue;
        _messages.add(RoomChatMessage(
          id: 'p_${ms}_${_messages.length}',
          senderId: 'persist',
          senderName: '${e['s'] ?? 'مشارك'}',
          text: '${e['t'] ?? ''}',
          isMe: e['me'] == true,
          sentAt: DateTime.fromMillisecondsSinceEpoch(ms),
        ));
      }
    } catch (_) {}
  }

  /// كتم مشارك (من قبل المنسق) — إنفاذ مزدوج: عبر قناة البيانات للواجهة
  /// وخادمياً عبر RoomService حتى لا يستطيع تجاوزه.
  Future<void> muteParticipant(String sid) async {
    _muted.add(sid);
    _handRaised.remove(sid);
    _refreshMute(sid);
    _refreshHand(sid);
    _publish(RoomDataTopics.coordinator,
        utf8.encode(jsonEncode({'action': 'mute', 'target': sid})));
    if (isDemo && sid != _meSid) {
      _speaking.remove(sid);
    } else {
      final identity = _participants[sid]?.identity;
      if (identity != null && identity.isNotEmpty) {
        try {
          await _serverAdmin('mute', identity);
        } catch (e) {
          AppLog.error('mute enforcement failed: $e');
        }
      }
    }
    notifyListeners();
  }

  /// طرد مشارك من القاعة (من قبل المنسق) — يُنفَّذ خادمياً عبر
  /// RemoveParticipant مع إشعار موجّه يحمل السبب، ويُحاكى محلياً
  /// في الوضع التجريبي. يرمي استثناء برسالة عربية عند الفشل.
  Future<void> removeParticipant(String sid, {String? reason}) async {
    if (!isCoordinator) return;
    if (isDemo) {
      final gone = _participants.remove(sid);
      _handRaised.remove(sid);
      _speaking.remove(sid);
      _muted.remove(sid);
      if (gone != null) {
        _micRequests.remove(gone.identity);
        _cameraRequests.remove(gone.identity);
      }
    } else {
      final identity = _participants[sid]?.identity;
      if (identity == null || identity.isEmpty) return;
      // إشعار موجّه للمعنيّ بالسبب قبل الخروج القسري.
      await _publishTo(identity, {'action': 'kicked', 'reason': reason});
      await Future.delayed(const Duration(milliseconds: 250));
      await _serverAdmin('remove', identity, reason: reason);
    }
    notifyListeners();
  }

  /// نشر رسالة على قناة المنسق لمشارك محدد بهويته.
  Future<void> _publishTo(
      String identity, Map<String, dynamic> payload) async {
    try {
      await _room?.localParticipant?.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true,
        topic: RoomDataTopics.coordinator,
        destinationIdentities: [identity],
      );
    } catch (_) {}
  }

  /// استدعاء نقطة الإشراف في الخادم الخفي — يرمي استثناء عند فشل
  /// الاستدعاء أو رفض الخادم حتى تعرف الواجهة وتُخبر المنسق.
  Future<void> _serverAdmin(String action, String identity,
      {String? reason}) async {
    const base = AudioRoomConfig.tokenEndpoint;
    if (base.isEmpty || _sessionToken == null) {
      throw Exception('لا يوجد اتصال بالخادم');
    }
    final url = base.endsWith('/token')
        ? base.substring(0, base.length - '/token'.length)
        : base;
    final resp = await http
        .post(
          Uri.parse('$url/admin/$action'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'room': roomName,
            'identity': identity,
            'token': _sessionToken,
            if (reason != null && reason.isNotEmpty) 'reason': reason,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      String msg = 'فشل الإجراء (${resp.statusCode})';
      try {
        final j = jsonDecode(resp.body);
        final e = j['error'];
        final d = j['detail'];
        if (e is String && e.isNotEmpty) msg = e;
        if (d != null && '$d'.isNotEmpty) msg = '$msg ($d)';
      } catch (_) {}
      AppLog.error('server admin $action failed: $msg');
      throw Exception(msg);
    }
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
        _micRequests.remove(gone.identity);
        _cameraRequests.remove(gone.identity);
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

  /// في الوضع التجريبي تُستخدم الاسم نفسه هويةً لمفاتيح الطلبات.
  static void _applyRequest(
      String name, bool requested, Map<String, String> map) {
    if (requested) {
      map[name] = name;
    } else {
      map.remove(name);
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

/// جلسة انضمام صادرة من خدمة التوكنات في الخادم الخفي.
class _RoomSession {
  final String url;
  final String token;
  final String identity;

  const _RoomSession({
    required this.url,
    required this.token,
    required this.identity,
  });
}

/// فشل في الحصول على جلسة من خدمة التوكنات — برسالة عربية جاهزة للعرض.
class RoomSessionException implements Exception {
  final String message;

  const RoomSessionException(this.message);

  @override
  String toString() => message;
}


/// حالة ملف قيد الاستلام من مشارك.
class _IncomingFile {
  _IncomingFile({
    required this.name,
    required this.size,
    required this.chunks,
    required this.sender,
  });

  final String name;
  final int size;
  final int chunks;
  final String sender;
  late final List<String?> parts = List<String?>.filled(chunks, null);
  int got = 0;
}
