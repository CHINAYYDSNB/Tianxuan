/// Native Logto bridge — url_launcher + MethodChannel/EventChannel for deep links
import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _methodChannel = MethodChannel('com.tianxuan.app/deeplink');
const _eventChannel = EventChannel('com.tianxuan.app/deeplink/events');

class LogtoBridge {
  /// Open Logto auth page in system browser
  static Future<void> redirect(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok) {
        throw Exception('launchUrl returned false');
      }
    } catch (e) {
      log('LogtoBridge.redirect error', error: e);
      rethrow;
    }
  }

  /// Native: callback params come via deep link URI, not URL params
  static Map<String, String> extractCallbackParams() => {};

  static void clearCallbackParams() {}

  /// Logto redirect URI registered for APK
  static String get callbackUri => 'com.tianxuan.app://callback';

  static String get origin => 'http://localhost:25568';

  /// Stream of incoming deep links (from onNewIntent)
  static Stream<Uri> get onCallback {
    return _eventChannel.receiveBroadcastStream().map(
      (e) => Uri.parse(e.toString()),
    );
  }

  /// Get initial deep link that launched the app
  static Future<Uri?> getInitialLink() async {
    try {
      final link = await _methodChannel.invokeMethod<String>('getInitialLink');
      if (link != null && link.isNotEmpty) return Uri.parse(link);
    } catch (_) {}
    return null;
  }
}
