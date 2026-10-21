import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// فضاء «خرائط الذهنية» — فهرس الخطاطات الذهنية المحفوظة داخل التطبيق.
///
/// البنية (تُبنى بـ tools/prep_mindmaps.cjs من مجلد سطح المكتب MINDMAPS):
///   assets/mindmaps/manifest.json   فهرس: المحاور + بطاقات الخطاطات
///   assets/mindmaps/mm_XXX.jpg      صورة الخطاطة (بأسماء آمنة للويب)
///
/// الفهرس يُقرأ مرة واحدة ويُخزَّن مؤقتاً؛ 이후 كل الاستعلامات محلية.
class MindMapCatalog {
  MindMapCatalog._();

  static const String indexAsset = 'assets/mindmaps/manifest.json';

  static List<MindMapCategory>? _categories;
  static List<MindMapItem>? _items;

  /// المحاور مرتّبة كما وردت في الفهرس.
  static Future<List<MindMapCategory>> categories() async {
    await _load();
    return _categories ?? const <MindMapCategory>[];
  }

  /// كل الخطاطات مرتّبة.
  static Future<List<MindMapItem>> items() async {
    await _load();
    return _items ?? const <MindMapItem>[];
  }

  /// الخطاطات المتعلّقة بمحور معيّن.
  static Future<List<MindMapItem>> itemsOf(String categoryId) async {
    final all = await items();
    return all.where((e) => e.categoryId == categoryId).toList();
  }

  /// خطاطة واحدة بمعرّفها.
  static Future<MindMapItem?> byId(String id) async {
    final all = await items();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// بحث نصي في العناوين (يتجاهل التشكيل وصور الألف والياء).
  static Future<List<MindMapItem>> search(String query) async {
    final all = await items();
    final q = _norm(query);
    if (q.isEmpty) return all;
    return all.where((e) => _norm(e.title).contains(q)).toList();
  }

  static Future<void> _load() async {
    if (_categories != null && _items != null) return;
    try {
      final raw = await rootBundle.loadString(indexAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cats = <MindMapCategory>[];
      for (final c in (decoded['categories'] as List?) ?? const []) {
        if (c is! Map) continue;
        final m = c.cast<String, dynamic>();
        final id = (m['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) continue;
        cats.add(MindMapCategory(
          id: id,
          title: (m['title'] as String?)?.trim().isNotEmpty == true
              ? (m['title'] as String).trim()
              : id,
          icon: (m['icon'] as String?) ?? 'folder',
        ));
      }
      final its = <MindMapItem>[];
      for (final i in (decoded['items'] as List?) ?? const []) {
        if (i is! Map) continue;
        final m = i.cast<String, dynamic>();
        final file = (m['file'] as String?)?.trim() ?? '';
        if (file.isEmpty) continue;
        its.add(MindMapItem(
          id: (m['id'] as String?)?.trim() ?? file,
          file: file,
          title: (m['title'] as String?)?.trim().isNotEmpty == true
              ? (m['title'] as String).trim()
              : 'خطاطة ذهنية',
          source: (m['source'] as String?) ?? '',
          categoryId: (m['category'] as String?)?.trim() ?? '',
        ));
      }
      _categories = cats;
      _items = its;
    } catch (e) {
      debugPrint('MindMapCatalog: تعذّر قراءة الفهرس — $e');
      _categories = const <MindMapCategory>[];
      _items = const <MindMapItem>[];
    }
  }

  /// تطبيع للمطابقة: إزالة التشكيل وتوحيد صور الألف والياء والتاء المربوطة.
  static String _norm(String s) => s
      .replaceAll(RegExp('[ً-ٰٟ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .trim()
      .toLowerCase();
}

/// محور تصنيف الخطاطات الذهنية.
class MindMapCategory {
  final String id;
  final String title;
  final String icon;

  const MindMapCategory({
    required this.id,
    required this.title,
    required this.icon,
  });
}

/// خطاطة ذهنية واحدة.
class MindMapItem {
  final String id;
  final String file;
  final String title;
  final String source;
  final String categoryId;

  const MindMapItem({
    required this.id,
    required this.file,
    required this.title,
    required this.source,
    required this.categoryId,
  });
}
