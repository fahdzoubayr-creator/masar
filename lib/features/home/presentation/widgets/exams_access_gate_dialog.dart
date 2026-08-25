import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// رابط صفحة التطبيق على فيسبوك — يُفتح من بوابة الامتحانات التجريبية.
const String kMasarFacebookUrl =
    'https://web.facebook.com/profile.php?id=61593778769894&locale=fr_FR';

/// كود فتح فضاء الامتحانات التجريبية — يُنشر على صفحة الفايسبوك.
const String kExamsAccessCode = 'MASAR2026';

/// بوابة دخول فضاء الامتحانات التجريبية.
/// تعرض رسالة الانضمام لصفحة الفايسبوك + خانة إدخال كود الدخول.
/// تُعيد [true] فقط إذا نجح المستخدم في إدخال الكود الصحيح.
Future<bool> showExamsAccessGateDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _ExamsAccessGateDialog(),
  );
  return result ?? false;
}

class _ExamsAccessGateDialog extends StatefulWidget {
  const _ExamsAccessGateDialog();

  @override
  State<_ExamsAccessGateDialog> createState() => _ExamsAccessGateDialogState();
}

class _ExamsAccessGateDialogState extends State<_ExamsAccessGateDialog> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _codeMatches(String input) {
    final normalized = input.trim().toUpperCase().replaceAll(
          RegExp(r'[\s\-_]'),
          '',
        );
    return normalized == kExamsAccessCode;
  }

  void _verify() {
    if (_checking) return;
    FocusScope.of(context).unfocus();
    setState(() => _checking = true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_codeMatches(_codeController.text)) {
        playSfx(Sfx.success);
        Navigator.of(context).pop(true);
      } else {
        playSfx(Sfx.error);
        setState(() {
          _checking = false;
          _error = 'الكود غير صحيح — تأكد من نسخه من صفحة الفايسبوك كما هو';
        });
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    _codeController.text = text;
    _codeController.selection = TextSelection.collapsed(offset: text.length);
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _openFacebookPage() async {
    playSfx(Sfx.tap);
    final uri = Uri.parse(kMasarFacebookUrl);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showOpenFailure();
    } catch (_) {
      if (mounted) _showOpenFailure();
    }
  }

  void _showOpenFailure() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'تعذّر فتح الرابط تلقائياً — افتحه يدوياً:\n$kMasarFacebookUrl',
            style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.cream),
          ),
          backgroundColor: AppColors.bgDeep,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgCard, AppColors.bgSurface],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'للاستفادة من محتوى هذا الفضاء، انضم إلى مجموعة '
                        'الدعوة عبر صفحة التطبيق على فيسبوك',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.65,
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFacebookButton(),
                      const SizedBox(height: 8),
                      Text(
                        'ستجد كود الدخول في منشور مثبّت أعلى الصفحة — '
                        'انسخه ثم ألصقه في الخانة أسفله',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          height: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDivider(),
                      const SizedBox(height: 14),
                      _buildCodeField(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: _error == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                key: const ValueKey('gate-error'),
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: AppColors.err, size: 15),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.tajawal(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.err,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _buildVerifyButton(),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text('ليس الآن',
                            style: GoogleFonts.tajawal(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA8842F), Color(0xFF6E5520)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x59FF8A3C), blurRadius: 16),
              ],
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 10),
          Text('الامتحانات التجريبية',
              style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text('فضاء مميز — الدخول بكود الانضمام',
              style: GoogleFonts.tajawal(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _buildFacebookButton() {
    return Material(
      color: const Color(0xFF1877F2),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: _openFacebookPage,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.facebook_rounded, color: Colors.white, size: 21),
              const SizedBox(width: 9),
              Text('صفحة التطبيق على فيسبوك',
                  style: GoogleFonts.tajawal(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded,
                  color: Colors.white70, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
              color: AppColors.gold.withValues(alpha: 0.25),
              thickness: 0.7,
              height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('أدخل الكود',
              style: GoogleFonts.tajawal(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldSoft)),
        ),
        Expanded(
          child: Divider(
              color: AppColors.gold.withValues(alpha: 0.25),
              thickness: 0.7,
              height: 1),
        ),
      ],
    );
  }

  Widget _buildCodeField() {
    return TextField(
      controller: _codeController,
      focusNode: _focusNode,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: (_) => _verify(),
      textCapitalization: TextCapitalization.characters,
      textAlign: TextAlign.center,
      style: GoogleFonts.tajawal(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
        color: AppColors.cream,
      ),
      cursorColor: AppColors.goldSoft,
      decoration: InputDecoration(
        hintText: 'XXXXXXXX',
        hintStyle: GoogleFonts.tajawal(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
          color: AppColors.muted.withValues(alpha: 0.5),
        ),
        counterText: '',
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 46, vertical: 14),
        filled: true,
        fillColor: AppColors.cream.withValues(alpha: 0.07),
        suffixIcon: IconButton(
          onPressed: _pasteFromClipboard,
          tooltip: 'لصق من الحافظة',
          icon: Icon(Icons.content_paste_rounded,
              size: 18, color: AppColors.goldSoft.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.goldSoft, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.err, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.err, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Material(
      borderRadius: BorderRadius.circular(13),
      child: Ink(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gold, AppColors.goldSoft],
          ),
        ),
        child: InkWell(
          onTap: _verify,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: _checking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Color(0xFF3B2E12)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_open_rounded,
                          color: Color(0xFF3B2E12), size: 18),
                      const SizedBox(width: 8),
                      Text('تحقق وافتح الفضاء',
                          style: GoogleFonts.tajawal(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF3B2E12))),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
