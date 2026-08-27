import 'dart:html' as html;

/// True when the app runs in Safari (or other browsers) on iPhone/iPad/iPod.
bool get isIosBrowser {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod') ||
      (ua.contains('macintosh') && ua.contains('mobile'));
}

bool get isMobileWeb {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return isIosBrowser || ua.contains('android') || ua.contains('mobile');
}
