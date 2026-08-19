import 'package:flutter/material.dart';

import 'package:livekit_client/livekit_client.dart' as lk;

import '../../config/audio_room_config.dart';
import '../../application/audio_room_controller.dart';
import '../../domain/audio_room_models.dart';
import '../widgets/room_chat_bubble.dart';
import '../widgets/room_palette.dart';

/// قاعة احتراف بنمط Inspeak (صوت وصورة): شريط علوي + شبكة فيديو للحاضرين
/// بأعلى الشاشة + قائمة أعضاء + شات + تحكم سفلي (المايك، الكاميرا، رفع اليد،
/// خانة الرسالة). الصوت والفيديو عبر LiveKit أو وضع تجريبي عند غياب بياناته.
class AudioRoomScreen extends StatefulWidget {
  const AudioRoomScreen({
    super.key,
    required this.room,
    required this.displayName,
    required this.isCoordinator,
    this.roomName = '',
  });

  /// رمز القاعة (اسم الغرفة في LiveKit).
  final String room;

  /// اسم القاعة كما سُجّلت في قائمة القاعات — يُعرض في الشريط العلوي.
  final String roomName;

  final String displayName;
  final bool isCoordinator;

  @override
  State<AudioRoomScreen> createState() => _AudioRoomScreenState();
}

class _AudioRoomScreenState extends State<AudioRoomScreen> {
  late final AudioRoomController _controller;
  final TextEditingController _input = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _giveVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AudioRoomController(
      roomName: widget.room,
      displayName: widget.displayName,
      isCoordinator: widget.isCoordinator,
    );
    _controller.connect();
  }

  @override
  void dispose() {
    _controller.disconnect();
    _controller.dispose();
    _input.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await _controller.sendChat(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.jumpTo(0);
      }
    });
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RoomPalette.surface,
        title: const Text('مغادرة القاعة؟',
            style: TextStyle(color: RoomPalette.text)),
        content: const Text(
          'ستخرج من القاعة الصوتية.',
          style: TextStyle(color: RoomPalette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('البقاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('مغادرة',
                style: TextStyle(color: RoomPalette.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.disconnect();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoomPalette.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildBody()),
                    _buildControlBar(),
                  ],
                ),
                // لوحة «الأعضاء ومنح الصلاحيات» — تظهر في المقدمة فوق الجميع
                // ولا تُفتح إلا بالضغط على الزر (حتى لا تغطي الدردشة).
                if (_giveVisible)
                  Positioned(
                    top: 58,
                    bottom: 84,
                    right: 10,
                    width: MediaQuery.sizeOf(context).width >= 760 ? 320 : 280,
                    child: _GivePanel(
                      controller: _controller,
                      onClose: () => setState(() => _giveVisible = false),
                    ),
                  ),
                if (_controller.connecting) const _ConnectingOverlay(),
                if (_controller.error != null) _buildErrorOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== الشريط العلوي =====

  Widget _buildTopBar() {
    final count = _controller.participants.length;
    final coordinatorName = _controller.coordinatorName;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: RoomPalette.surface.withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(color: RoomPalette.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: RoomPalette.green.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.record_voice_over_rounded,
                color: RoomPalette.green, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.roomName.isNotEmpty
                      ? widget.roomName
                      : AudioRoomConfig.friendlyRoomLabel(widget.room),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoomPalette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 12, color: RoomPalette.amber),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        coordinatorName ?? 'منسق القاعة',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5, color: RoomPalette.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: RoomPalette.bg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RoomPalette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_alt_rounded,
                    size: 13, color: RoomPalette.muted),
                const SizedBox(width: 4),
                Text('$count',
                    style: const TextStyle(
                        color: RoomPalette.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _controller.isDemo
                  ? RoomPalette.amber.withValues(alpha: 0.16)
                  : RoomPalette.green.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _controller.modeLabel,
              style: TextStyle(
                fontSize: 10,
                color: _controller.isDemo
                    ? RoomPalette.amber
                    : RoomPalette.green,
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => setState(() => _giveVisible = !_giveVisible),
                tooltip: 'الأعضاء ومنح الصلاحيات',
                icon: Icon(
                  Icons.group_rounded,
                  color: _giveVisible ? RoomPalette.green : RoomPalette.text,
                  size: 22,
                ),
              ),
              if (_controller.micRequests.isNotEmpty ||
                  _controller.cameraRequests.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 4,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: RoomPalette.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _leave,
            tooltip: 'مغادرة',
            icon: const Icon(Icons.close_rounded,
                color: RoomPalette.muted, size: 22),
          ),
        ],
      ),
    );
  }

  // ===== الجسم: مسرح الكاميرا في الأعلى + الشات بملء العرض =====
  // (قائمة الأعضاء والإعطاء في لوحة منفصلة تُفتح بالزر حتى لا تغطي الدردشة.)

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Column(
          children: [
            _buildVideoSection(wide: wide),
            Expanded(child: _buildChat()),
          ],
        );
      },
    );
  }

  /// مسرح كاميرا صاحب الصورة (المنسق افتراضياً) في أعلى الشاشة،
  /// وبعده شريط منخفض لبقية الكاميرات إن وُجدت. كاميرا واحدة في القاعة
  /// وفق نظام الصلاحيات، لذا يظهر المنسق غالباً.
  Widget _buildVideoSection({required bool wide}) {
    final videos = _controller.videoParticipants;
    if (videos.isEmpty) {
      return _buildCameraPlaceholder();
    }
    final holderSid = _controller.cameraHolderSid;
    final ordered = [...videos]..sort((a, b) {
        if (a.id == holderSid) return -1;
        if (b.id == holderSid) return 1;
        return 0;
      });
    final main = ordered.first;
    final rest = ordered.skip(1).toList();
    final tileWidth = wide ? 150.0 : 104.0;
    final tileHeight = wide ? 104.0 : 136.0;
    final stageHeight = wide ? 290.0 : 210.0;
    return Container(
      decoration: BoxDecoration(
        color: RoomPalette.deep.withValues(alpha: 0.6),
        border: const Border(bottom: BorderSide(color: RoomPalette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: SizedBox(
              height: stageHeight,
              width: double.infinity,
              child: _VideoTile(
                participant: main,
                track: _controller.cameraTrackOf(main.id),
                speaking: main.isSpeaking,
              ),
            ),
          ),
          if (rest.isNotEmpty)
            SizedBox(
              height: tileHeight + 14,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                itemCount: rest.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final p = rest[index];
                  return SizedBox(
                    width: tileWidth,
                    child: _VideoTile(
                      participant: p,
                      track: _controller.cameraTrackOf(p.id),
                      speaking: p.isSpeaking,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// مكان كاميرا المنسق في الأعلى حتى قبل فتحها — يوضح للزائر أين ستظهر.
  Widget _buildCameraPlaceholder() {
    final coordinatorName = _controller.coordinatorName;
    final String message;
    if (_controller.isCoordinator) {
      message = _controller.cameraFailed
          ? 'تعذّر فتح الكاميرا — اسمح بإذن الكاميرا في المتصفح ثم اضغط زر الكاميرا'
          : 'كاميرتك ستظهر هنا — افتحها من زر الكاميرا بالأسفل';
    } else if (coordinatorName != null) {
      message = 'كاميرا المنسق ($coordinatorName) ستظهر هنا عند تشغيلها';
    } else {
      message = 'كاميرا المنسق ستظهر هنا عند تشغيلها';
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: RoomPalette.deep.withValues(alpha: 0.6),
        border: const Border(bottom: BorderSide(color: RoomPalette.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_off_rounded,
              size: 16, color: RoomPalette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11,
                color: _controller.isCoordinator && _controller.cameraFailed
                    ? RoomPalette.red
                    : RoomPalette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    final messages = _controller.messages;
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    'لا رسائل بعد — اكتب أول رسالة أو ارفع يدك للكلمة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: RoomPalette.muted),
                  ),
                )
              : ListView.builder(
                  controller: _chatScroll,
                  reverse: true,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => RoomChatBubble(
                    message: messages[messages.length - 1 - index],
                  ),
                ),
        ),
      ],
    );
  }

  // ===== شريط التحكم السفلي =====

  Widget _buildControlBar() {
    final speaking = _controller.micEnabled && _controller.isMeSpeaking;
    final canMic = _controller.canSpeak;
    final canCam = _controller.canUseCamera;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: RoomPalette.surface.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: RoomPalette.border)),
      ),
      child: Row(
        children: [
          _MicButton(
            active: _controller.micEnabled,
            speaking: speaking,
            enabled: canMic,
            requesting: !_controller.isCoordinator,
            requestPending: _controller.myMicRequested,
            holder: _controller.micHolderName,
            onPressed: _controller.toggleMic,
            onRequest: _controller.requestCoordinatorMic,
          ),
          const SizedBox(width: 10),
          _CameraButton(
            active: _controller.cameraEnabled,
            enabled: canCam,
            requesting: !_controller.isCoordinator,
            requestPending: _controller.myCameraRequested,
            holder: _controller.cameraHolderName,
            onPressed: _controller.toggleCamera,
            onRequest: _controller.requestCoordinatorCamera,
          ),
          const SizedBox(width: 10),
          if (!_controller.isCoordinator) ...[
            _HandButton(
              active: _controller.handRaised,
              onPressed: _controller.toggleHand,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: _input,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: RoomPalette.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'اكتب رسالة إلى الحاضرين...',
                hintStyle:
                    const TextStyle(color: RoomPalette.muted, fontSize: 12),
                filled: true,
                fillColor: RoomPalette.bg.withValues(alpha: 0.7),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      BorderSide(color: RoomPalette.border.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      BorderSide(color: RoomPalette.border.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: RoomPalette.green),
                ),
                suffixIcon: IconButton(
                  onPressed: _send,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: RoomPalette.green,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: RoomPalette.bg.withValues(alpha: 0.92),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: RoomPalette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RoomPalette.red),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: RoomPalette.red, size: 40),
                  const SizedBox(height: 12),
                  const Text('تعذّر الاتصال بالقاعة',
                      style: TextStyle(
                          color: RoomPalette.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    _controller.error ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, color: RoomPalette.muted),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _controller.connect(),
                    style: FilledButton.styleFrom(
                        backgroundColor: RoomPalette.green,
                        foregroundColor: RoomPalette.bg),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== أزرار التحكم =====

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.active,
    required this.speaking,
    required this.enabled,
    required this.requesting,
    required this.requestPending,
    required this.onPressed,
    this.onRequest,
    this.holder,
  });

  final bool active;
  final bool speaking;
  final bool enabled;

  /// الوضع «اطلب من المنسق» — عندما لا يملك الزائر الكلمة.
  final bool requesting;
  final bool requestPending;
  final String? holder;
  final VoidCallback onPressed;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final requestingMode = requesting && !enabled;
    final pending = requestingMode && requestPending;
    final Color color = pending
        ? RoomPalette.amber
        : !enabled
            ? RoomPalette.muted
            : (active ? RoomPalette.green : RoomPalette.red);
    final String label = requestingMode
        ? (pending ? 'بانتظار فتح مايك المنسق' : 'اطلب فتح مايك المنسق')
        : !enabled
            ? (holder != null ? 'الكلمة مع $holder' : 'لا تملك الكلمة')
            : (speaking
                ? 'أنت تتحدث'
                : (active ? 'المايك مفتوح' : 'المايك مكتوم'));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: requestingMode ? onRequest : (enabled ? onPressed : null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pending
                  ? color.withValues(alpha: 0.22)
                  : color.withValues(alpha: active ? 0.95 : 0.22),
              border: Border.all(color: color, width: 2),
              boxShadow: speaking
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: Icon(
              requestingMode
                  ? (pending
                      ? Icons.hourglass_top_rounded
                      : Icons.mic_none_rounded)
                  : !enabled
                      ? Icons.lock_rounded
                      : (active ? Icons.mic_rounded : Icons.mic_off_rounded),
              color: requestingMode
                  ? color
                  : !enabled
                      ? RoomPalette.muted
                      : (active ? RoomPalette.bg : color),
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: pending
                ? RoomPalette.amber
                : (speaking ? RoomPalette.green : RoomPalette.muted),
          ),
        ),
      ],
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({
    required this.active,
    required this.enabled,
    required this.requesting,
    required this.requestPending,
    required this.onPressed,
    this.onRequest,
    this.holder,
  });

  final bool active;
  final bool enabled;

  /// الوضع «اطلب من المنسق» — عندما لا يملك الزائر صلاحية الكاميرا.
  final bool requesting;
  final bool requestPending;
  final String? holder;
  final VoidCallback onPressed;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final requestingMode = requesting && !enabled;
    final pending = requestingMode && requestPending;
    final Color color = active ? RoomPalette.green : RoomPalette.muted;
    final String label = requestingMode
        ? (pending ? 'بانتظار فتح كاميرا المنسق' : 'اطلب فتح كاميرا المنسق')
        : !enabled
            ? (holder != null ? 'الكاميرا مع $holder' : 'لا تملك الكاميرا')
            : (active ? 'الكاميرا مفتوحة' : 'تشغيل الكاميرا');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: requestingMode ? onRequest : (enabled ? onPressed : null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pending
                  ? RoomPalette.amber.withValues(alpha: 0.25)
                  : active
                      ? RoomPalette.green.withValues(alpha: 0.95)
                      : RoomPalette.bg.withValues(alpha: 0.7),
              border: Border.all(
                color: pending
                    ? RoomPalette.amber
                    : active
                        ? RoomPalette.green
                        : RoomPalette.border,
                width: 2,
              ),
            ),
            child: Icon(
              requestingMode
                  ? (pending
                      ? Icons.hourglass_top_rounded
                      : Icons.videocam_outlined)
                  : !enabled
                      ? Icons.lock_rounded
                      : (active
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded),
              color: requestingMode
                  ? (pending ? RoomPalette.amber : RoomPalette.muted)
                  : !enabled
                      ? RoomPalette.muted
                      : (active ? RoomPalette.bg : color),
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: pending
                ? RoomPalette.amber
                : active
                    ? RoomPalette.green
                    : RoomPalette.muted,
          ),
        ),
      ],
    );
  }
}

/// بلاطة فيديو لحاضر واحد — تعرض بثّه الحقيقي أو صورة رمزية بديلة
/// (في الوضع التجريبي أو قبل وصول البثّ).
class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.participant,
    required this.track,
    required this.speaking,
  });

  final RoomParticipant participant;
  final lk.VideoTrack? track;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RoomPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: speaking ? RoomPalette.green : RoomPalette.border,
          width: speaking ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null)
            lk.VideoTrackRenderer(
              track!,
              fit: lk.VideoViewFit.cover,
              placeholderBuilder: (_) => _placeholder(),
            )
          else
            _placeholder(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: Colors.black.withValues(alpha: 0.55),
              child: Row(
                children: [
                  if (!participant.micEnabled) ...[
                    const Icon(Icons.mic_off_rounded,
                        size: 12, color: RoomPalette.red),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      participant.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoomPalette.text,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    final color =
        participant.isCoordinator ? RoomPalette.amber : RoomPalette.green;
    final initial = participant.name.trim().isEmpty
        ? '؟'
        : participant.name.trim().characters.first;
    return ColoredBox(
      color: RoomPalette.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color),
              ),
              child: Text(
                initial,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                participant.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: RoomPalette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandButton extends StatelessWidget {
  const _HandButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = active ? RoomPalette.amber : RoomPalette.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? RoomPalette.amber.withValues(alpha: 0.95)
                  : RoomPalette.bg.withValues(alpha: 0.7),
              border: Border.all(
                color: active ? RoomPalette.amber : RoomPalette.border,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.back_hand_rounded,
              color: active ? RoomPalette.bg : color,
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          active ? 'رفعت يدك' : 'رفع اليد',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: active ? RoomPalette.amber : RoomPalette.muted,
          ),
        ),
      ],
    );
  }
}

/// لوحة «منح الصلاحيات» — تُفتح بزر «منح» في الشريط العلوي وتنبثق قليلاً
/// نحو اليمين حتى لا تغطي الدردشة. كل اسم أمامه رمز المايك والكاميرا:
/// من يرفع يده يظهر بارزاً، والمنسق يمنحه بزرّ بجانب اسمه مباشرة.
class _GivePanel extends StatelessWidget {
  const _GivePanel({required this.controller, required this.onClose});

  final AudioRoomController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isCoordinator = controller.isCoordinator;
    final members = controller.participants;
    final micHolder = controller.micHolderName;
    final camHolder = controller.cameraHolderName;

    final ordered = [...members]..sort((a, b) {
        if (a.handRaised != b.handRaised) return a.handRaised ? -1 : 1;
        if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Container(
      decoration: BoxDecoration(
        color: RoomPalette.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RoomPalette.green.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 14, spreadRadius: 2),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            color: RoomPalette.green.withValues(alpha: 0.12),
            child: Row(
              children: [
                const Icon(Icons.group_rounded,
                    size: 16, color: RoomPalette.green),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'الأعضاء ومنح الصلاحيات',
                    style: TextStyle(
                      fontSize: 13,
                      color: RoomPalette.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${members.length}',
                  style: const TextStyle(fontSize: 11, color: RoomPalette.muted),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded,
                      size: 17, color: RoomPalette.muted),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'إغلاق',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _pill(
                  icon: Icons.record_voice_over_rounded,
                  text: micHolder != null ? 'الكلمة مع $micHolder' : 'لا أحد يتكلم',
                  color: micHolder != null ? RoomPalette.green : RoomPalette.muted,
                ),
                _pill(
                  icon: Icons.videocam_rounded,
                  text: camHolder != null ? 'الكاميرا مع $camHolder' : 'لا أحد يبثّ',
                  color: camHolder != null ? RoomPalette.green : RoomPalette.muted,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: RoomPalette.border),
          if (isCoordinator &&
              (controller.micRequests.isNotEmpty ||
                  controller.cameraRequests.isNotEmpty)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RoomPalette.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: RoomPalette.amber.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'طلبات فتح أجهزة المنسق',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: RoomPalette.amber,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (controller.micRequests.isNotEmpty)
                      _requestRow(
                        icon: Icons.record_voice_over_rounded,
                        label:
                            'المايك: ${controller.micRequests.join('، ')}',
                        onOpen: controller.openMyMic,
                      ),
                    if (controller.cameraRequests.isNotEmpty)
                      _requestRow(
                        icon: Icons.videocam_rounded,
                        label:
                            'الكاميرا: ${controller.cameraRequests.join('، ')}',
                        onOpen: controller.openMyCamera,
                      ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final p in ordered)
                  _giveRow(
                    p: p,
                    enabled: isCoordinator && !p.isMe,
                    onMute: () => controller.muteParticipant(p.id),
                    onMic: () => p.hasMic
                        ? controller.revokeMic(p.id)
                        : controller.grantMic(p.id),
                    onCamera: () => p.hasCamera
                        ? controller.revokeCamera(p.id)
                        : controller.grantCamera(p.id),
                  ),
              ],
            ),
          ),
          if (isCoordinator) ...[
            const Divider(height: 1, color: RoomPalette.border),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'كمنسق: سلّم لمن يرفع يده — ومن تمنحه يتكلم أو يبثّ وحده، ويسحبها الآخرون تلقائياً.',
                style: TextStyle(fontSize: 10, color: RoomPalette.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _giveRow({
    required RoomParticipant p,
    required bool enabled,
    required VoidCallback onMute,
    required VoidCallback onMic,
    required VoidCallback onCamera,
  }) {
    final isSelf = p.isMe;
    final nameColor =
        isSelf ? RoomPalette.green : (p.isCoordinator ? RoomPalette.amber : RoomPalette.text);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: p.handRaised
            ? RoomPalette.amber.withValues(alpha: 0.12)
            : RoomPalette.bg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: p.handRaised
              ? RoomPalette.amber.withValues(alpha: 0.6)
              : RoomPalette.border.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (p.handRaised) ...[
                  const Icon(Icons.back_hand_rounded,
                      size: 14, color: RoomPalette.amber),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: nameColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (enabled)
            IconButton(
              onPressed: onMute,
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              tooltip: p.micEnabled ? 'كتم' : 'إلغاء الكتم',
              icon: Icon(
                p.micEnabled ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: p.micEnabled ? RoomPalette.red : RoomPalette.muted,
              ),
            ),
          IconButton(
            onPressed: enabled ? onMic : null,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: p.hasMic ? 'سحب الكلمة' : 'منح الكلمة',
            icon: Icon(
              p.hasMic
                  ? Icons.record_voice_over_rounded
                  : Icons.mic_none_rounded,
              color: p.hasMic ? RoomPalette.green : RoomPalette.muted,
            ),
          ),
          IconButton(
            onPressed: enabled ? onCamera : null,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: p.hasCamera ? 'سحب الكاميرا' : 'منح الكاميرا',
            icon: Icon(
              p.hasCamera ? Icons.videocam_rounded : Icons.videocam_outlined,
              color: p.hasCamera ? RoomPalette.green : RoomPalette.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestRow({
    required IconData icon,
    required String label,
    required VoidCallback onOpen,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: RoomPalette.amber),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: RoomPalette.text),
            ),
          ),
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 30),
              foregroundColor: RoomPalette.green,
              backgroundColor: RoomPalette.green.withValues(alpha: 0.12),
            ),
            child: const Text('فتح', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ConnectingOverlay extends StatelessWidget {
  const _ConnectingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: RoomPalette.bg.withValues(alpha: 0.85),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: RoomPalette.green),
              SizedBox(height: 14),
              Text(
                'جاري الانضمام إلى القاعة...',
                style: TextStyle(color: RoomPalette.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
