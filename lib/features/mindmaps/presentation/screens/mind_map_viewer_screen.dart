import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/mindmaps/data/mind_map_catalog.dart';

/// عارض الخطاطة الذهنية — تكبير/تصغير وتحريك، مع التنقّل بين الخطاطات.
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
  late final PageController _pages = PageController();
  late int _index = _initialIndex();
  final TransformationController _transform = TransformationController();

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

  @override
  Widget build(BuildContext context) {
    final items = widget.siblings;
    final current = items.isEmpty ? widget.item : items[_index.clamp(0, items.length - 1)];
    return Scaffold(
      backgroundColor: const Color(0xFF08110F),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(current, items.length),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: items.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _transform.value = Matrix4.identity();
                },
                itemBuilder: (context, i) {
                  final it = items[i];
                  return InteractiveViewer(
                    transformationController: _transform,
                    minScale: 0.6,
                    maxScale: 6,
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
            ),
            _bottomBar(current, items.length),
          ],
        ),
      ),
    );
  }

  Widget _topBar(MindMapItem current, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.goldSoft, size: 18),
            tooltip: 'رجوع',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _transform.value = Matrix4.identity(),
            icon: const Icon(Icons.zoom_out_map_rounded,
                color: AppColors.goldSoft, size: 19),
            tooltip: 'إعادة الضبط',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(MindMapItem current, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _index > 0 ? () => _step(-1) : null,
            icon: const Icon(Icons.chevron_right_rounded,
                color: AppColors.goldSoft, size: 26),
            tooltip: 'السابقة',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Expanded(
            child: Text(
              current.source.isEmpty ? current.title : current.source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ),
          IconButton(
            onPressed:
                _index < total - 1 ? () => _step(1) : null,
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppColors.goldSoft, size: 26),
            tooltip: 'التالية',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}
