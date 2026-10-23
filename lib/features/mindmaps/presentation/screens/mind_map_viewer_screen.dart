import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/mindmaps/data/mind_map_catalog.dart';
import 'package:masar_app/features/review/presentation/widgets/zoom_controls_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

/// عارض الخطاطة الذهنية — تكبير/تصغير وتحريك، مع التنقّل بين الخطاطات.
///
/// التكبير ممكن بقرصين/إصبعين (InteractiveViewer) وأيضاً بأزرار
/// [ZoomControlsOverlay] العائمة أسفل اليمين، مع عرض النسبة المئوية.
class MindMapViewerScreen extends StatefulWidget {
  final MindMapItem item;
  final List<MindMapItem> siblings;

  const MindMapViewerScreen({
    super.key,
    required this.item,
    required this.siblings,
  });

  @override
  State<MindMapViewerScreen> createState() => _MindMapViewerScreenState();
}

class _MindMapViewerScreenState extends State<MindMapViewerScreen> {
  static const double _minScale = 0.5;
  static const double _maxScale = 6.0;

  late final PageController _pages = PageController();
  late int _index = _initialIndex();
  final TransformationController _transform = TransformationController();
  double _zoomRatio = 1.0;

  int _initialIndex() {
    final i = widget.siblings.indexWhere((e) => e.id == widget.item.id);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _pages.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.siblings.length) return;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  /// تكبير/تصغير حول مركز العرض مع الحفاظ على موضع المحتوى.
  void _zoomBy(double factor) {
    final m = _transform.value;
    final current = m.row0[0] == 0 ? 1.0 : m.row0[0];
    final next = (current * factor).clamp(_minScale, _maxScale);
    final k = next / current;
    _transform.value = Matrix4(
      next, 0, 0, 0,
      0, next, 0, 0,
      0, 0, 1, 0,
      m.row0[3] * k, m.row1[3] * k, 0, 1,
    );
    setState(() => _zoomRatio = next);
  }

  void _resetZoom() {
    _transform.value = Matrix4.identity();
    setState(() => _zoomRatio = 1.0);
  }

  void _syncZoom() {
    final s = _transform.value.row0[0];
    if ((s - _zoomRatio).abs() > 0.001 && mounted) {
      setState(() => _zoomRatio = s);
    }
  }

  /// فتح الخطاطة بدقّتها الكاملة في تبويب متصفح جديد — على الويب فقط.
  ///
  /// على الهاتف لا فائدة من ذلك (التطبيق نفسه هو العارض)، لذا الزر
  /// يظهر حصراً لمَن فتح التطبيق على الويب.
  Future<void> _openInBrowser(MindMapItem item) async {
    final url = MindMapCatalog.webViewerUrl(item);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر فتح المتصفح — أعد المحاولة'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر فتح الملف في المتصفح'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.siblings;
    final current = items.isEmpty
        ? widget.item
        : items[_index.clamp(0, items.length - 1)];
    return Scaffold(
      backgroundColor: const Color(0xFF08110F),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(current, items.length),
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pages,
                    itemCount: items.length,
                    onPageChanged: (i) {
                      setState(() => _index = i);
                      _transform.value = Matrix4.identity();
                      _zoomRatio = 1.0;
                    },
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return InteractiveViewer(
                        transformationController: _transform,
                        minScale: _minScale,
                        maxScale: _maxScale,
                        onInteractionEnd: (_) => _syncZoom(),
                        child: Center(
                          child: Image.asset(
                            it.file,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stack) => const Center(
                              child: Icon(Icons.broken_image_rounded,
                                  color: AppColors.muted, size: 40),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  ZoomControlsOverlay(
                    zoomRatio: _zoomRatio,
                    onZoomIn: () => _zoomBy(1.25),
                    onZoomOut: () => _zoomBy(0.8),
                    onReset: _resetZoom,
                  ),
                ],
              ),
            ),
            _bottomBar(current, items.length),
          ],
        ),
      ),
    );
  }

  Widget _topBar(MindMapItem current, int total) {
    return Container(
      color: kIsWeb ? const Color(0xCC08110F) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.goldSoft, size: 20),
            tooltip: 'رجوع',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  current.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream,
                    height: 1.3,
                  ),
                ),
                if (total > 1)
                  Text(
                    '${_index + 1} / $total',
                    style:
                        const TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.zoom_out_map_rounded,
                color: AppColors.goldSoft, size: 21),
            tooltip: 'إعادة الضبط',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          // على الويب: فتح الخطاطة في تبويب متصفح جديد (بدقّة كاملة).
          if (kIsWeb)
            IconButton(
              onPressed: () => _openInBrowser(current),
              icon: const Icon(Icons.open_in_new_rounded,
                  color: AppColors.goldSoft, size: 20),
              tooltip: 'فتح في المتصفح',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(MindMapItem current, int total) {
    return Container(
      color: kIsWeb ? const Color(0xCC08110F) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // «السابقة» — chevron_left تنعكس في RTL فتشير يمينًا.
          IconButton(
            onPressed: _index > 0 ? () => _step(-1) : null,
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppColors.goldSoft, size: 30),
            tooltip: 'السابقة',
            constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
          ),
          Expanded(
            child: Text(
              current.source.isEmpty ? current.title : current.source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
          // «التالية» — chevron_right تنعكس في RTL فتشير يسارًا.
          IconButton(
            onPressed: _index < total - 1 ? () => _step(1) : null,
            icon: const Icon(Icons.chevron_right_rounded,
                color: AppColors.goldSoft, size: 30),
            tooltip: 'التالية',
            constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
          ),
        ],
      ),
    );
  }
}
