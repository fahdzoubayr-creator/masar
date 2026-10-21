import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/widgets/app_logo_header.dart';
import 'package:masar_app/features/mindmaps/data/mind_map_catalog.dart';
import 'package:masar_app/features/mindmaps/presentation/screens/mind_map_viewer_screen.dart';

/// فضاء «خرائط الذهنية» — معرض الخطاطات الذهنية مرتّباً في محاور.
class MindMapsScreen extends StatefulWidget {
  const MindMapsScreen({super.key});

  @override
  State<MindMapsScreen> createState() => _MindMapsScreenState();
}

class _MindMapsScreenState extends State<MindMapsScreen> {
  List<MindMapCategory> _categories = const <MindMapCategory>[];
  List<MindMapItem> _items = const <MindMapItem>[];
  bool _loading = true;
  String _query = '';
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await MindMapCatalog.categories();
    final items = await MindMapCatalog.items();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _items = items;
      _activeCategory = cats.isNotEmpty ? cats.first.id : null;
      _loading = false;
    });
  }

  List<MindMapItem> get _visible {
    final q = _query.trim();
    return _items.where((e) {
      final inCategory =
          _activeCategory == null || e.categoryId == _activeCategory;
      if (!inCategory) return false;
      if (q.isEmpty) return true;
      return e.title.contains(q);
    }).toList();
  }

  void _open(MindMapItem item, List<MindMapItem> siblings) {
    playSfx(Sfx.select);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MindMapViewerScreen(
          item: item,
          siblings: siblings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.goldSoft, size: 18),
                  tooltip: 'رجوع',
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ),
              AppLogoHeader(
                title: 'خرائط ذهنية',
                subtitle: _loading
                    ? 'جارٍ تحميل الخطاطات…'
                    : '${_items.length} خطاطة ذهنية في ${_categories.length} محاور',
                logoSize: 58,
              ),
              const SizedBox(height: 12),
              _searchField(),
              const SizedBox(height: 10),
              if (!_loading) _categoryStrip(),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.goldSoft),
                      )
                    : visible.isEmpty
                        ? const _EmptyState()
                        : GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: visible.length,
                            itemBuilder: (context, i) => _MindMapCard(
                              item: visible[i],
                              onTap: () => _open(visible[i], visible),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(color: AppColors.cream, fontSize: 13),
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        decoration: const InputDecoration(
          icon: Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
          hintText: 'ابحث في الخطاطات…',
          hintStyle: TextStyle(fontSize: 12, color: AppColors.muted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _categoryStrip() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _categories[i];
          final active = c.id == _activeCategory;
          final count = _items.where((e) => e.categoryId == c.id).length;
          return InkWell(
            onTap: () => setState(() => _activeCategory = c.id),
            borderRadius: BorderRadius.circular(100),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.gold.withValues(alpha: 0.18)
                    : AppColors.bgCard,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: active
                      ? AppColors.gold.withValues(alpha: 0.55)
                      : AppColors.gold.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(c.icon),
                      size: 15, color: active ? AppColors.gold : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    '${c.title} · $count',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? AppColors.goldSoft : AppColors.cream,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static IconData _iconFor(String key) {
    switch (key) {
      case 'psychology':
        return Icons.psychology_alt_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'gavel':
        return Icons.gavel_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
      case 'fact_check':
        return Icons.fact_check_rounded;
      default:
        return Icons.folder_rounded;
    }
  }
}

class _MindMapCard extends StatelessWidget {
  final MindMapItem item;
  final VoidCallback onTap;

  const _MindMapCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: AppColors.bgSurface,
                  child: Image.asset(
                    item.file,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stack) => const Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: AppColors.muted, size: 26),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors.cream,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 44, color: AppColors.muted),
          SizedBox(height: 12),
          Text(
            'لا توجد خطاطات مطابقة',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
