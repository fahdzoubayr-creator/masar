import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:masar_app/core/services/review_file_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/review/presentation/widgets/zoom_controls_overlay.dart';

/// عارض PDF بتمرير عمودي متواصل باليد (سحب الإصبع عبر الصفحات) —
/// مع تكبير/تصغير وإزاحة داخل الصفحة بالقرص والمزدوجة،
/// وأزرار تكبير/تصغير على الشاشة عبر مكوّن [ZoomControlsOverlay] العام.
class PdfViewerScreen extends StatefulWidget {
  final String assetPath;
  final String title;
  const PdfViewerScreen({super.key, required this.assetPath, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;

  PdfControllerPinch? _controller;
  int _page = 1;
  int? _pagesCount;
  Object? _error;
  bool _opening = true;
  double _zoomRatio = 1.0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onZoomChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final bytes = await ReviewFileService.readAsset(widget.assetPath);
      final doc = await PdfDocument.openData(bytes);
      final controller = PdfControllerPinch(
        document: Future<PdfDocument>.value(doc),
        initialPage: 1,
      );
      controller.addListener(_onZoomChanged);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _pagesCount = doc.pagesCount;
        _opening = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _opening = false;
      });
    }
  }

  void _onZoomChanged() {
    if (!mounted) return;
    setState(() => _zoomRatio = _controller!.zoomRatio);
  }

  Future<void> _go(int target) async {
    final controller = _controller;
    final count = _pagesCount ?? 1;
    if (controller == null) return;
    final clamped = target.clamp(1, count);
    await controller.animateToPage(
      pageNumber: clamped,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _zoomBy(double factor) {
    final controller = _controller;
    if (controller == null) return;
    final m = controller.value;
    final next = (m.row0[0] * factor).clamp(_minScale, _maxScale);
    final k = next / m.row0[0];
    controller.value = Matrix4(
      next, 0, 0, 0,
      0, next, 0, 0,
      0, 0, 1, 0,
      m.row0[3] * k, m.row1[3] * k, 0, 1,
    );
  }

  void _resetZoom() {
    final controller = _controller;
    if (controller == null) return;
    try {
      final target = controller.calculatePageFitMatrix(pageNumber: controller.page);
      if (target == null) return;
      controller.goTo(
        destination: target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232B38),
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_controller != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '$_page / $_pagesCount',
                  style: const TextStyle(fontSize: 13, color: AppColors.goldSoft),
                ),
              ),
            ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody()),
            if (_controller != null && !_opening && _error == null)
              ZoomControlsOverlay(
                zoomRatio: _zoomRatio,
                onZoomIn: () => _zoomBy(1.25),
                onZoomOut: () => _zoomBy(0.8),
                onReset: _resetZoom,
              ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown) {
      _go(_page + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      _go(_page - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _go(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _go(_pagesCount ?? 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 52, color: AppColors.err),
              const SizedBox(height: 16),
              const Text('تعذّر فتح هذا الملف',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cream)),
              const SizedBox(height: 8),
              Text('$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted, height: 1.6)),
            ],
          ),
        ),
      );
    }

    if (_opening || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    return PdfViewPinch(
      controller: _controller!,
      scrollDirection: Axis.vertical,
      minScale: _minScale,
      maxScale: _maxScale,
      backgroundDecoration: const BoxDecoration(color: Color(0xFF232B38)),
      onPageChanged: (page) {
        if (mounted && page != _page) {
          setState(() => _page = page);
        }
      },
    );
  }
}
