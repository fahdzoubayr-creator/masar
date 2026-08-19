import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masar_app/core/services/session_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/audio_room/config/audio_room_config.dart';
import 'package:masar_app/features/audio_room/data/room_store.dart';
import 'package:masar_app/features/audio_room/presentation/screens/audio_room_screen.dart';

/// شاشة القاعات — بنمط بسيط وجذاب (مثل تطبيقات المحادثة الصوتية):
/// - تنشئ قاعة فتصبح منسقها وتملك رمز انضمام خاصاً بها.
/// - تنضم إلى قاعة برمز شاركه منسقها.
/// - قاعاتك تبقى ظاهرة بالترتيب أسفل الشاشة وتدخلها بلمسة واحدة.
/// البثّ نفسه يعمل عبر LiveKit للصوت في الخلفية فقط.
class AudioRoomLobbyScreen extends StatefulWidget {
  const AudioRoomLobbyScreen({super.key});

  @override
  State<AudioRoomLobbyScreen> createState() => _AudioRoomLobbyScreenState();
}

class _AudioRoomLobbyScreenState extends State<AudioRoomLobbyScreen>
    with WidgetsBindingObserver {
  /// رموز القاعات التي أنشأها هذا التطبيق (هذه النافذة/الجهاز) — صاحبها
  /// منسق؛ أما من يدخلها بالرمز فهو حاضر. لا تُخزّن خارج الذاكرة حتى يبقى
  /// الرمز شيئاً يُشارك خارجياً فقط.
  static final Set<String> _created = {};

  String _userName = '';
  List<MasarRoom> _rooms = [];
  bool _loading = true;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// عند العودة إلى هذه النافذة (من أخرى) تُحدَّث قائمة القاعات فوراً —
  /// حتى تظهر أي قاعة أُنشئت في نافذة أخرى (التخزين مشترك على الجهاز).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadRooms();
    }
  }

  Future<void> _init() async {
    final name = await SessionService.resolveUserName();
    final rooms = await RoomStore.load();
    if (!mounted) return;
    setState(() {
      _userName = name;
      _rooms = rooms;
      _loading = false;
    });
  }

  Future<void> _reloadRooms() async {
    final rooms = await RoomStore.load();
    if (!mounted) return;
    setState(() => _rooms = rooms);
  }

  String get _displayName => _userName.isEmpty ? 'مشارك' : _userName;

  // ===== إنشاء قاعة (المستخدم يصبح منسقها) =====

  Future<void> _createRoom() async {
    final nameController = TextEditingController();
    var isPublic = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgSurface,
          title: const Text('إنشاء قاعة جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أنت من ينشئ القاعة فتصبح منسقها — اختر نوعها: خاصة برمز، أو مفتوحة يجدها الجميع في القائمة.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 40,
                style: const TextStyle(color: AppColors.cream),
                decoration: InputDecoration(
                  labelText: 'اسم القاعة',
                  hintText: 'مثال: مراجعة اختبار الكفاءة',
                  labelStyle: const TextStyle(color: AppColors.muted),
                  hintStyle: const TextStyle(color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.cream.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.cream.withValues(alpha: 0.15)),
                  ),
                ),
                onSubmitted: (_) => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 6),
              _RoomTypeSelector(
                value: isPublic,
                onChanged: (v) => setDialogState(() => isPublic = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgDeep,
              ),
              child: const Text('إنشاء القاعة'),
            ),
          ],
        ),
      ),
    );
    final roomName = nameController.text.trim();
    nameController.dispose();
    if (result != true || !mounted) return;

    final room = MasarRoom(
      code: isPublic
          ? AudioRoomConfig.generateOpenRoomCode(roomName)
          : AudioRoomConfig.generateRoomId(),
      name: roomName,
      role: MasarRoomRole.coordinator,
      isPublic: isPublic,
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );
    _created.add(room.code);
    final rooms = await RoomStore.upsert(room);
    if (!mounted) return;
    setState(() => _rooms = rooms);

    if (isPublic) {
      final enter = await _showOpenRoomCreated(room);
      if (enter == true && mounted) {
        await _enterRoom(room);
      }
    } else {
      final enter = await _showShareCode(room);
      if (enter == true && mounted) {
        await _enterRoom(room, skipCode: true);
      }
    }
  }

  Future<bool?> _showOpenRoomCreated(MasarRoom room) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('قاعتك مفتوحة للجميع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ستظهر قاعتك في قسم «قاعات مفتوحة» ليدخلها أي أحد بضغطة واحدة — دون رمز.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (room.name.isNotEmpty) ...[
              Text(room.name,
                  textAlign: TextAlign.center,
                  style: AppTheme.displayFont(size: 15)),
              const SizedBox(height: 6),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.ok.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ok.withValues(alpha: 0.45)),
              ),
              child: const Text(
                'للجميع — بدون رمز',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.ok, height: 1.5),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'بصفتك المنسق، أنت من يتحكم في الكتم والطرد.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bgDeep,
            ),
            child: const Text('دخول القاعة'),
          ),
        ],
      ),
    );
  }

  // ===== عرض رمز القاعة للمشاركة =====

  Future<bool?> _showShareCode(MasarRoom room) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('قاعتك جاهزة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'شارك رمز الانضمام مع الحاضرين ليدخلوا إلى قاعتك:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (room.name.isNotEmpty) ...[
              Text(room.name,
                  textAlign: TextAlign.center,
                  style: AppTheme.displayFont(size: 15)),
              const SizedBox(height: 6),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
              ),
              child: SelectableText(
                room.code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.goldSoft, height: 1.5),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'بصفتك المنسق، أنت من يتحكم في الكتم والطرد.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: room.code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ رمز القاعة')),
              );
            },
            child: const Text('نسخ الرمز'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bgDeep,
            ),
            child: const Text('دخول القاعة'),
          ),
        ],
      ),
    );
  }

  // ===== دخول القاعة =====

  /// يدخل قاعة مفتوحة بضغطة واحدة (بدون رمز) — يبقى دور المستخدم منسقاً
  /// إن كانت قاعة أنشأها بنفسه، وإلا يصبح حاضراً.
  Future<void> _enterPublicRoom(String code, String name) async {
    if (_launching) return;
    MasarRoom? existing;
    for (final r in _rooms) {
      if (r.code == code) {
        existing = r;
        break;
      }
    }
    if (existing == null) {
      final room = MasarRoom(
        code: code,
        name: name,
        role: MasarRoomRole.member,
        isPublic: true,
        createdAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
      );
      final rooms = await RoomStore.upsert(room);
      if (!mounted) return;
      setState(() => _rooms = rooms);
      await _enterRoom(room);
    } else {
      await _enterRoom(existing);
    }
  }

  /// يدخل قاعة من القائمة. القاعة الخاصة برمز تُسأل عن الرمز أولاً — والرمز
  /// يحصل عليه الحاضر خارجياً من المنسق ولا يظهر في التطبيق أبداً. من أنشأ
  /// القاعة (في هذه النافذة) يبقى منسقاً، ومن دخل بالرمز يكون حاضراً.
  Future<void> _enterRoom(MasarRoom room, {bool skipCode = false}) async {
    if (_launching) return;
    if (!room.isPublic && !skipCode) {
      final ok = await _requestRoomCode(room);
      if (!ok || !mounted) return;
    }
    final isCoordinator = _created.contains(room.code);
    setState(() => _launching = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AudioRoomScreen(
            room: room.code,
            roomName: room.name,
            displayName: _displayName,
            isCoordinator: isCoordinator,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _launching = false);
        await _reloadRooms();
      }
    }
  }

  /// نافذة طلب رمز القاعة الخاصة — ترفض الدخول إن لم يُطابق الرمز المخزّن.
  Future<bool> _requestRoomCode(MasarRoom room) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('قاعة خاصة برمز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (room.name.isNotEmpty) ...[
              Text(room.name,
                  textAlign: TextAlign.center,
                  style: AppTheme.displayFont(size: 14.5)),
              const SizedBox(height: 6),
            ],
            const Text(
              'أدخل الرمز الذي حصلت عليه من المنسق — خارج التطبيق.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              style: const TextStyle(color: AppColors.cream),
              decoration: InputDecoration(
                labelText: 'رمز القاعة',
                labelStyle: const TextStyle(color: AppColors.muted),
                filled: true,
                fillColor: AppColors.cream.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppColors.cream.withValues(alpha: 0.15)),
                ),
              ),
              onSubmitted: (v) =>
                  Navigator.of(context).pop(AudioRoomConfig.sanitizeRoom(v)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context)
                .pop(AudioRoomConfig.sanitizeRoom(controller.text)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bgDeep,
            ),
            child: const Text('دخول'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return false;
    if (code == null || code.isEmpty) return false;
    if (code != room.code) {
      _showSnack('رمز غير صحيح — تأكد من الرمز الذي شاركه المنسق.');
      return false;
    }
    return true;
  }

  Future<void> _removeRoom(MasarRoom room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('إزالة القاعة'),
        content: Text(
          'هل تريد إزالة «${room.name.isEmpty ? room.code : room.name}» من قائمتك؟',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إزالة',
                style: TextStyle(color: AppColors.err)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final rooms = await RoomStore.remove(room.code);
    if (!mounted) return;
    setState(() => _rooms = rooms);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ===== البناء =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgDeep, Color(0xFF0A2A2A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reloadRooms,
                  color: AppColors.goldSoft,
                  backgroundColor: AppColors.bgSurface,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCreateCard(),
                        const SizedBox(height: 20),
                        _buildOpenRoomsSection(),
                        const SizedBox(height: 20),
                        _buildRoomsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.goldSoft, size: 22),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('القاعات', style: AppTheme.displayFont(size: 18)),
                const Text(
                  'صوت مباشر داخل التطبيق — بدون مغادرة',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard() {
    return _buildActionCard(
      icon: Icons.add_rounded,
      title: 'إنشاء قاعة',
      subtitle: 'تصبح منسقها وتشارك رمز الانضمام مع الحاضرين',
      onTap: _createRoom,
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.bgSurface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cream.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.goldSoft, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTheme.displayFont(
                            size: 14.5, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: AppColors.goldSoft, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomsSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.goldSoft),
        ),
      );
    }
    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('قاعاتك',
            style: AppTheme.displayFont(size: 14, weight: FontWeight.w700)),
        Text('${_rooms.length}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
    if (_rooms.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bgSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.cream.withValues(alpha: 0.10)),
            ),
            child: const Column(
              children: [
                Icon(Icons.people_alt_outlined,
                    color: AppColors.muted, size: 30),
                SizedBox(height: 8),
                Text(
                  'لا توجد قاعات بعد — أنشئ قاعة جديدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 10),
        ..._rooms.map((room) => _buildRoomTile(room)),
        if (_launching) ...[
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(color: AppColors.goldSoft),
          ),
        ],
      ],
    );
  }

  // ===== القاعات المفتوحة للجميع =====

  Widget _buildOpenRoomsSection() {
    const fixed = AudioRoomConfig.publicRooms;
    final locallyPublic = _rooms.where((r) => r.isPublic).toList();
    final merged = <String, ({String name, String icon})>{};
    for (final room in locallyPublic) {
      merged[room.code] = (
        name: room.name.isEmpty ? AudioRoomConfig.friendlyRoomLabel(room.code) : room.name,
        icon: '🟢',
      );
    }
    for (final room in fixed) {
      merged[room.code] = (name: room.name, icon: room.icon);
    }
    if (merged.isEmpty) return const SizedBox.shrink();

    final entries = merged.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.public_rounded, size: 16, color: AppColors.ok),
            const SizedBox(width: 6),
            Text('قاعات مفتوحة للجميع',
                style:
                    AppTheme.displayFont(size: 14, weight: FontWeight.w700)),
            const Spacer(),
            Text('${entries.length}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 10),
        ...entries.map((entry) => _buildPublicRoomTile(entry)),
      ],
    );
  }

  Widget _buildPublicRoomTile(
      MapEntry<String, ({String name, String icon})> entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.bgSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _enterPublicRoom(entry.key, entry.value.name),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.ok.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.ok.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Text(entry.value.icon,
                      style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.displayFont(size: 13.5),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'دخول مباشر — بدون رمز',
                        style:
                            TextStyle(fontSize: 10.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded,
                    color: AppColors.ok, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomTile(MasarRoom room) {
    final isCoordinator = room.isCoordinator;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.bgSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _enterRoom(room),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.cream.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isCoordinator ? AppColors.gold : AppColors.ok)
                        .withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCoordinator
                        ? Icons.mic_rounded
                        : Icons.headphones_rounded,
                    color: isCoordinator ? AppColors.goldSoft : AppColors.ok,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name.isEmpty ? 'قاعة بدون اسم' : room.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.displayFont(size: 14),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (room.isPublic) ...[
                            const Icon(Icons.public_rounded,
                                size: 12, color: AppColors.ok),
                            const SizedBox(width: 4),
                          ] else ...[
                            const Icon(Icons.lock_outline_rounded,
                                size: 12, color: AppColors.goldSoft),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              room.isPublic
                                  ? 'قاعة مفتوحة للجميع — دخول مباشر'
                                  : 'قاعة خاصة برمز — الرمز من المنسق',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isCoordinator ? AppColors.gold : AppColors.ok)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isCoordinator ? 'منسق' : 'حاضر',
                    style: TextStyle(
                        fontSize: 10,
                        color: isCoordinator ? AppColors.goldSoft : AppColors.ok),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeRoom(room),
                  icon: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.muted),
                  tooltip: 'إزالة القاعة',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// مُحدد نوع القاعة عند الإنشاء: خاصة برمز / مفتوحة للجميع.
class _RoomTypeSelector extends StatelessWidget {
  const _RoomTypeSelector({required this.value, required this.onChanged});

  /// `true` = مفتوحة للجميع، `false` = خاصة برمز.
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _option(
          selected: !value,
          icon: Icons.lock_outline_rounded,
          title: 'قاعة خاصة برمز',
          subtitle: 'ينضم إليها من شاركته الرمز فقط',
          onTap: () => onChanged(false),
        ),
        const SizedBox(height: 8),
        _option(
          selected: value,
          icon: Icons.public_rounded,
          title: 'قاعة مفتوحة للجميع',
          subtitle: 'تظهر في قسم «قاعات مفتوحة» — يدخلها أي أحد بدون رمز',
          onTap: () => onChanged(true),
        ),
      ],
    );
  }

  Widget _option({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppColors.gold : AppColors.muted;
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.14)
          : AppColors.cream.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : AppColors.cream.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20, color: selected ? AppColors.goldSoft : AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.goldSoft
                                : AppColors.cream)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.muted)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
