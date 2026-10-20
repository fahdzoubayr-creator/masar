import 'package:flutter/material.dart';
import 'package:masar_app/core/services/session_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/widgets/app_logo_header.dart';
import 'package:masar_app/features/audio_room/config/audio_room_config.dart';
import 'package:url_launcher/url_launcher.dart';

import 'jawaaher_frame_stub.dart'
    if (dart.library.js_interop) 'jawaaher_frame_web.dart' as frame;

/// «جواهر الكفاءة» — لعبة المراحل والمنافسة بين الزملاء.
///
/// على الويب تُعرض اللعبة مضمَّنة داخل الشاشة (iframe بنفس أصل التطبيق)
/// ومعها هوية المسجّل الأول (?u=<الاسم>) فيتعرّف عليها خادم اللعبة
/// تلقائيًا — دون أي تسجيل داخل اللعبة. خارج الويب تُفتح في المتصفح.
class JawaaherGameScreen extends StatefulWidget {
  const JawaaherGameScreen({super.key});

  @override
  State<JawaaherGameScreen> createState() => _JawaaherGameScreenState();
}

class _JawaaherGameScreenState extends State<JawaaherGameScreen> {
  String? _name;
  bool _opening = false;
  bool _booted = false;
  String? _error;
  Widget? _embedded;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final name = await SessionService.resolveUserName();
    if (!mounted) return;
    final embedded = frame.buildJawaaherFrame(name);
    setState(() {
      _name = name;
      _embedded = embedded;
      _booted = true;
    });
    if (embedded == null) await _open();
  }

  String get _gameUrl {
    final name = Uri.encodeComponent(_name ?? '');
    return '${AudioRoomConfig.apiBase}/jawaaher/?u=$name';
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final opened = await launchUrl(
        Uri.parse(_gameUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() => _error = 'تعذّر فتح الرابط تلقائيًا — أعد المحاولة');
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'تعذّر فتح الرابط — تأكد من تشغيل الخادم أولًا');
      }
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final embedded = _embedded;
    if (embedded != null) return _buildEmbedded(embedded);
    return _buildLauncher();
  }

  /// مسار الويب: اللعبة مضمَّنة داخل الشاشة مع شريط علوي خفيف.
  Widget _buildEmbedded(Widget embedded) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.goldSoft, size: 18),
                    tooltip: 'رجوع',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'جواهر الكفاءة',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold),
                        ),
                        Text(
                          'هويتك: ${_name ?? "…"}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _opening ? null : _open,
                    icon: const Icon(Icons.open_in_new_rounded,
                        color: AppColors.goldSoft, size: 18),
                    tooltip: 'فتح في تبويب جديد',
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.err, height: 1.4),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: embedded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// مسار خارج الويب: بطاقة تعريف + زر الفتح في المتصفح الخارجي.
  Widget _buildLauncher() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: !_booted
            ? const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.gold),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.goldSoft, size: 18),
                        tooltip: 'رجوع',
                        constraints: const BoxConstraints(
                            minWidth: 44, minHeight: 44),
                      ),
                    ),
                    const AppLogoHeader(
                      title: 'جواهر الكفاءة',
                      subtitle: 'تحدّي المراحل — منافسة حيّة بين الزملاء',
                      logoSize: 64,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _row(Icons.person_pin_circle_rounded,
                              'هويتك: ${_name ?? "…"}'),
                          const SizedBox(height: 8),
                          _row(Icons.sync_alt_rounded,
                              'يتم تعريفك في اللعبة تلقائيًا بتسجيلك الأول هنا'),
                          const SizedBox(height: 8),
                          _row(Icons.groups_rounded,
                              'تقدّمك يظهر لزملائك حسب خصوصيتك في اللعبة'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: const Color(0xFF06201F),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: _opening ? null : _open,
                        icon: _opening
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF06201F)),
                              )
                            : const Icon(Icons.sports_esports_rounded,
                                size: 18),
                        label: Text(
                          _opening ? 'جارٍ الفتح…' : 'افتح اللعبة',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.err,
                            height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      _gameUrl,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted, height: 1.5),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.goldSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.cream, height: 1.4),
          ),
        ),
      ],
    );
  }
}
