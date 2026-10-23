import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const String _viewType = 'jawaaher-frame';

String _frameUrl = '';
bool _registered = false;

/// تضمين اللعبة داخل الشاشة على الويب — iframe بنفس أصل التطبيق
/// (رابط نسبي يتجنّب مشكلة عنوان الخادم الثابت) مع هوية المستخدم.
Widget? buildJawaaherFrame(String userName) {
  _frameUrl = Uri.base
      .resolve('jawaaher/?u=${Uri.encodeComponent(userName)}')
      .toString();
  if (!_registered) {
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe
        ..src = _frameUrl
        ..style.cssText =
            'border:0;margin:0;padding:0;width:100%;height:100%;display:block;background:transparent';
      iframe.setAttribute('allow', 'autoplay');
      iframe.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-popups allow-modals allow-downloads',
      );
      return iframe;
    });
  }
  return const HtmlElementView(viewType: _viewType);
}
