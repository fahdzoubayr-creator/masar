import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masar_app/core/services/review_file_service.dart';
import 'package:masar_app/core/services/review_page_images.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/review/presentation/widgets/zoom_controls_overlay.dart';

/// عارض PDF بتمرير عمودي متواصل باليد (سحب الإصبع عبر الصفحات) —
/// مع تكبير/تصغير وإزاحة داخل الصفحة بالقرص والمزدوجة،
/// وأزرار تكبير/تصغير على الشاشة عبر مكوّن [ZoomControlsOverlay] العام.
///
/// الوضعية الأساسية: الصفحات المصوّرة (MuPDF) من Cloud Storage عبر
/// REVIEW_PAGE_BASE — عربية مضمونة بلا أي محرك PDF في المتصفح،
/// وبدون أي اعتماد على سيرفر محلي. عند غياب تلك الخدمة يُعرض المحرك
/// الأصلي (pdfx) فتظل الشاشة مستقلة تماماً.
class PdfViewerScreen extends StatefulWidget {
  final String assetPath;
  final String title;
  /// قائمة اختيارية بكل ملفات المحور — عندها يظهر تنقّل بين الملفات
  /// (سابق/التالي) في شريط العنوان. `assetPath` هو الملف الأول.
  final List<String> assetPaths;

  const PdfViewerScreen({
    super.key,
    required this.assetPath,
    required this.title,
    this.assetPaths = const [],
  });

  /// هل الشاشة تعرض أكثر من ملف (وضع القراءة المتسلسلة)؟
  bool get hasMultiple => assetPaths.length > 1;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;

  PdfControllerPinch? _controller;
  ReviewPagesMeta? _imgMeta;
  int _page = 1;
  int? _pagesCount;
  Object? _error;
  bool _opening = true;
  bool _imageFallback = false;
  double _zoomRatio = 1.0;
  final ScrollController _imgScroll = ScrollController();
  final TransformationController _imgTc = TransformationController();

  // فهرس الملف الحالي ضمن قائمة المحور (0 = الملف المفرد).
  int _fileIndex = 0;
  String _currentPath = '';
  bool _openingFile = false;

  /// عدد الملفات المعروضة (1 إذا كان ملفًا مفردًا).
  int get _fileCount => widget.hasMultiple ? widget.assetPaths.length : 1;

  /// مسار الملف الحالي فعليًا.
  String get _path =>
      widget.hasMultiple ? widget.assetPaths[_fileIndex] : widget.assetPath;

  @override
  void initState() {
    super.initState();
    _imgScroll.addListener(_onImageScroll);
    _currentPath = widget.assetPath;
    _open();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onZoomChanged);
    _controller?.dispose();
    _imgScroll.removeListener(_onImageScroll);
    _imgScroll.dispose();
    _imgTc.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    // 1) الصفحات المصوّرة من السحابة (عربية مضمونة) برفق دون أي سيرفر محلي.
    if (ReviewPageImages.enabled) {
      final meta = await ReviewPageImages.fetchMeta(_path);
      if (meta != null) {
        if (!mounted) return;
        setState(() {
          _imgMeta = meta;
          _pagesCount = meta.pages;
          _opening = false;
        });
        return;
      }
    }
    // 2) التراجع: المحرك الأصلي (pdfx).
    try {
      final bytes = await ReviewFileService.readAsset(_path);
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
        _openingFile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _opening = false;
        _openingFile = false;
      });
    }
  }

  /// الانتقال إلى ملف آخر من قائمة المحور (وضع القراءة المتسلسلة).
  Future<void> _openFileAt(int index) async {
    if (!widget.hasMultiple) return;
    if (index < 0 || index >= widget.assetPaths.length) return;
    if (index == _fileIndex && (_controller != null || _imgMeta != null)) return;
    final path = widget.assetPaths[index];
    if (_controller != null) {
      _controller!.removeListener(_onZoomChanged);
      _controller!.dispose();
    }
    setState(() {
      _fileIndex = index;
      _currentPath = path;
      _controller = null;
      _imgMeta = null;
      _pagesCount = null;
      _error = null;
      _page = 1;
      _imageFallback = false;
      _opening = true;
      _openingFile = true;
      _zoomRatio = 1.0;
    });
    if (_imgScroll.hasClients) _imgScroll.jumpTo(0);
    _imgTc.value = Matrix4.identity();
    await _open();
  }

  void _nextFile() {
    if (!widget.hasMultiple) return;
    _openFileAt(_fileIndex + 1);
  }

  void _prevFile() {
    if (!widget.hasMultiple) return;
    _openFileAt(_fileIndex - 1);
  }

  /// ينتقل من وضعية الصور إلى المحرك الأصلي عند فشل الصورة الأولى.
  Future<void> _switchToPdfFallback() async {
    if (_imageFallback || _controller != null) return;
    _imageFallback = true;
    final meta = _imgMeta;
    if (meta == null) return;
    try {
      final bytes = await ReviewFileService.readAsset(_path);
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
        _imgMeta = null;
        _controller = controller;
        _pagesCount = doc.pagesCount;
        _page = 1;
      });
    } catch (_) {
      // تُبقى وضعية الصور وعرض صفحاتها المتاحة.
    }
  }

  /// فتح الملف على المتصفح (ويب بشاشة عريضة فقط): صفحة عرض كبيرة
  /// بصفحات PNG المعالَجة بـMuPDF فيرجع العرض كبيرًا والعربية سليمة.
  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(ReviewFileService.viewerUrlFor(_path));
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الملف على المتصفح')),
      );
    }
  }

  void _onZoomChanged() {
    if (!mounted) return;
    setState(() => _zoomRatio = _controller!.zoomRatio);
  }

  void _onImageScroll() {
    final meta = _imgMeta;
    if (meta == null || !mounted) return;
    final width = MediaQuery.sizeOf(context).width;
    // عرض كل صفحة = عرض الشاشة، ارتفاعها = العرض ÷ نسبة أبعادها (+ هامش 8).
    double y = 0;
    var idx = 0;
    for (; idx < meta.pages - 1; idx++) {
      final s = meta.natural[idx];
      final h = (s.height / s.width) * width + 8;
      if (_imgScroll.offset < y + h) break;
      y += h;
    }
    final next = idx + 1;
    if (next != _page) setState(() => _page = next);
  }

  Future<void> _go(int target) async {
    final count = _pagesCount ?? 1;
    final controller = _controller;
    if (controller != null) {
      final clamped = target.clamp(1, count);
      await controller.animateToPage(
        pageNumber: clamped,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }
    final meta = _imgMeta;
    if (meta == null) return;
    final width = MediaQuery.sizeOf(context).width;
    var y = 0.0;
    final to = target.clamp(1, meta.pages) - 1;
    for (var i = 0; i < to && i < meta.natural.length; i++) {
      final s = meta.natural[i];
      y += (s.height / s.width) * width + 8;
    }
    _imgScroll.animateTo(
      y.clamp(0, _imgScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _zoomBy(double factor) {
    final controller = _controller;
    if (controller != null) {
      final m = controller.value;
      final next = (m.row0[0] * factor).clamp(_minScale, _maxScale);
      final k = next / m.row0[0];
      controller.value = Matrix4(
        next, 0, 0, 0,
        0, next, 0, 0,
        0, 0, 1, 0,
        m.row0[3] * k, m.row1[3] * k, 0, 1,
      );
      return;
    }
    if (_imgMeta != null) {
      final m = _imgTc.value;
      final next = (m.row0[0] * factor).clamp(_minScale, _maxScale);
      final k = next / m.row0[0];
      _imgTc.value = Matrix4(
        next, 0, 0, 0,
        0, next, 0, 0,
        0, 0, 1, 0,
        m.row0[3] * k, m.row1[3] * k, 0, 1,
      );
      setState(() => _zoomRatio = next);
    }
  }

  void _resetZoom() {
    final controller = _controller;
    if (controller != null) {
      try {
        final target = controller.calculatePageFitMatrix(pageNumber: controller.page);
        if (target == null) return;
        controller.goTo(
          destination: target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } catch (_) {}
      return;
    }
    if (_imgMeta != null) {
      _imgTc.value = Matrix4.identity();
      setState(() => _zoomRatio = 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // على الويب بشاشة عريضة نظهر زر "افتح الملف على المتصفح"؛
    // وعلى الهاتف (شاشة ضيقة أو نسخة غير ويب) نخفيه.
    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width > 600;
    return Scaffold(
      // الخلفية الموحدة تُقدَّم من main.dart — لا طبقة معتمة هنا.
      appBar: AppBar(
        title: Text(
          widget.hasMultiple
              ? '${widget.title} · ${_fileIndex + 1}/$_fileCount'
              : widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: widget.hasMultiple
            ? IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.goldSoft, size: 18),
                tooltip: 'رجوع',
              )
            : null,
        actions: [
          // تنقّل بين ملفات المحور: prev (يمين) ← current ← next (يسار).
          if (widget.hasMultiple) ...[
            IconButton(
              onPressed: _openingFile || _fileIndex == 0 ? null : _prevFile,
              icon: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.goldSoft, size: 18),
              tooltip: 'الملف السابق',
            ),
            IconButton(
              onPressed:
                  _openingFile || _fileIndex >= _fileCount - 1 ? null : _nextFile,
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.goldSoft, size: 18),
              tooltip: 'الملف التالي',
            ),
          ],
          if (isDesktop)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_new,
                      size: 15, color: AppColors.goldSoft),
                  label: const Text(
                    'افتح الملف على المتصفح',
                    style: TextStyle(fontSize: 12, color: AppColors.goldSoft),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                  ),
                ),
              ),
            ),
          if ((_controller != null || _imgMeta != null) && _pagesCount != null)
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
            if (widget.hasMultiple && _error != null && _fileIndex < _fileCount - 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: _nextFile,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    label: const Text('الملف التالي'),
                  ),
                ),
              ),
            if (!_opening && _error == null && (_controller != null || _imgMeta != null))
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
              Text(
                widget.hasMultiple && _fileIndex < _fileCount - 1
                    ? 'تعذّر فتح هذا الملف — انتقل للملف التالي'
                    : 'تعذّر فتح هذا الملف',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream),
              ),
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

    if (_opening || (_controller == null && _imgMeta == null)) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    final meta = _imgMeta;
    if (meta != null) return _buildImagePages(meta);

    return PdfViewPinch(
      controller: _controller!,
      scrollDirection: Axis.vertical,
      minScale: _minScale,
      maxScale: _maxScale,
      // لا غطاء خلفي: تُعرض الخلفية الموحّدة حول صفحات PDF مباشرة.
      onPageChanged: (page) {
        if (mounted && page != _page) {
          setState(() => _page = page);
        }
      },
    );
  }

  /// تمرير الصفحات المصوّرة: صورة كاملة العرض لكل صفحة داخل
  /// InteractiveViewer للتكبير/التصغير بنفس إبهامات وضعية pdfx.
  Widget _buildImagePages(ReviewPagesMeta meta) {
    return ListView.builder(
      controller: _imgScroll,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: meta.pages,
      itemBuilder: (context, index) {
        final s = meta.natural[index];
        final aspect = s.width <= 0 || s.height <= 0 ? 1.0 : s.width / s.height;
        final url = ReviewPageImages.pageUrl(_path, index + 1);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InteractiveViewer(
            transformationController: _imgTc,
            minScale: _minScale,
            maxScale: _maxScale,
            clipBehavior: Clip.none,
            boundaryMargin: const EdgeInsets.all(80),
            onInteractionUpdate: (d) {
              if (mounted && (d.scale - _zoomRatio).abs() > 0.001) {
                setState(() => _zoomRatio = d.scale);
              }
            },
            child: AspectRatio(
              aspectRatio: aspect,
              child: Image.network(
                url.toString(),
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSync) {
                  if (wasSync || frame != null) return child;
                  return const ColoredBox(
                    color: Color(0xFF232B38),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) {
                  if (index == 0) {
                    // الخدمة غير متاحة — نرجع إلى المحرك الأصلي مرة واحدة.
                    Future.microtask(_switchToPdfFallback);
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Icon(Icons.broken_image_outlined,
                          color: AppColors.muted),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}