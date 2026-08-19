import 'package:flutter/material.dart';
import 'package:masar_app/core/services/session_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/widgets/app_logo_header.dart';
import 'package:masar_app/core/widgets/page_transitions.dart';
import 'package:masar_app/features/branching/presentation/screens/branching_screen.dart';
import 'package:masar_app/features/home/presentation/screens/home_dashboard_screen.dart';

class DummyAuthScreen extends StatefulWidget {
  final String? trackTitle;
  const DummyAuthScreen({super.key, this.trackTitle});

  @override
  State<DummyAuthScreen> createState() => _DummyAuthScreenState();
}

class _DummyAuthScreenState extends State<DummyAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _submitted = false;
  String? _levelLabel;

  static const _levelLabels = {
    'primary': 'التعليم الابتدائي',
    'middle': 'التعليم الإعدادي',
    'high': 'التعليم الثانوي التأهيلي',
  };

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    final level = await SessionService.getLevel();
    if (!mounted) return;
    setState(() => _levelLabel = _levelLabels[level]);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _enter({String? name}) async {
    await SessionService.setLoggedIn(name: name);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(const HomeDashboardScreen()),
      (route) => false,
    );
  }

  void _goBack() {
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(const BranchingScreen()),
      (route) => false,
    );
  }

  Future<void> _register() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    await _enter(name: _nameCtrl.text);
  }

  Future<void> _skip() async {
    await _enter();
  }

  Future<void> _socialLogin(String provider) async {
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : 'مستخدم $provider';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('دخول تجريبي عبر $provider — الربط الرسمي قريباً'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
    await _enter(name: name);
  }

  Widget _socialButton({
    required String provider,
    required Color color,
    required Widget child,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
            color: AppColors.goldSoft.withValues(alpha: 0.4), width: 1),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _socialLogin(provider),
      child: Tooltip(message: 'الدخول عبر $provider', child: child),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.goldSoft, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: AppColors.cream),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.goldSoft, size: 18),
                    tooltip: 'رجوع',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ),
                const AppLogoHeader(
                  title: 'إنشاء حساب تجريبي',
                  subtitle: 'سجّل بياناتك للتحضير — تسجيل مؤقت للمعاينة',
                  logoSize: 64,
                ),
                const SizedBox(height: 16),
                if (widget.trackTitle != null || _levelLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.trackTitle != null)
                          _infoChip(Icons.route_outlined,
                              'المسلك: ${widget.trackTitle}'),
                        if (_levelLabel != null)
                          _infoChip(
                              Icons.school_rounded, 'السلك: $_levelLabel'),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                _field(
                  ctrl: _nameCtrl,
                  hint: 'الاسم الكامل',
                  icon: Icons.person_outline_rounded,
                  type: TextInputType.name,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'أدخل اسمك الكامل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _field(
                  ctrl: _contactCtrl,
                  hint: 'رقم الهاتف أو البريد الإلكتروني',
                  icon: Icons.contact_mail_outlined,
                  type: TextInputType.text,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'أدخل رقم هاتفك أو بريدك';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _field(
                  ctrl: _passwordCtrl,
                  hint: 'كلمة المرور',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: _obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  onSuffixTap: () => setState(() => _obscure = !_obscure),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF06201F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: _register,
                    child: const Text('تسجيل والدخول',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: AppColors.muted, thickness: 0.5, height: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('أو',
                          style:
                              TextStyle(fontSize: 10, color: AppColors.muted)),
                    ),
                    Expanded(
                        child: Divider(
                            color: AppColors.muted, thickness: 0.5, height: 1)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _socialButton(
                        provider: 'Google',
                        color: const Color(0xFF4285F4),
                        child: const Text('G',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _socialButton(
                        provider: 'Facebook',
                        color: const Color(0xFF1877F2),
                        child: const Icon(Icons.facebook_rounded, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _socialButton(
                        provider: 'Apple',
                        color: AppColors.cream,
                        child: const Text('A',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'الدخول عبر هذه الحسابات تسجيل تجريبي — الربط الرسمي قريباً',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldSoft,
                      side: BorderSide(
                          color: AppColors.goldSoft.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _skip,
                    child: const Text('دخول تجريبي — تخطي التسجيل',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'هذه بيانات مؤقتة للمعاينة فقط، وسيرتبط الحساب لاحقاً بالنظام الرسمي.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10.5, color: AppColors.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType? type,
    bool obscure = false,
    IconData? suffix,
    VoidCallback? onSuffixTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: AppColors.cream, fontSize: 13),
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
        prefixIcon: suffix != null
            ? GestureDetector(
                onTap: onSuffixTap,
                child: Icon(suffix, color: AppColors.muted, size: 18),
              )
            : null,
        suffixIcon: Icon(icon, color: AppColors.muted, size: 18),
        filled: true,
        fillColor: AppColors.bgSurface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.err, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.err, width: 1.2),
        ),
        errorStyle:
            const TextStyle(fontSize: 10, color: AppColors.err, height: 1.2),
      ),
    );
  }
}
