import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// GitHub release update checker.
class UpdateService {
  static const _repo = 'CHINAYYDSNB/Tianxuan';
  static const _api = 'https://api.github.com/repos/$_repo/releases/latest';

  /// Keep in sync with pubspec.yaml version.
  static const currentVersion = '0.0.10+1';

  /// GitHub repo URL for download.
  static const repoUrl = 'https://github.com/$_repo';

  /// Compare semver strings. Returns >0 if a > b, <0 if a < b, 0 if equal.
  static int _compareVersion(String a, String b) {
    String clean(String s) =>
        s.replaceAll(RegExp(r'^v'), '').split(RegExp(r'[-+]'))[0];
    final pa = clean(a).split('.').map(int.tryParse).whereNotNull().toList();
    final pb = clean(b).split('.').map(int.tryParse).whereNotNull().toList();
    for (int i = 0; i < pa.length && i < pb.length; i++) {
      if (pa[i] != pb[i]) return pa[i] - pb[i];
    }
    return pa.length - pb.length;
  }

  /// Build headers for GitHub API.
  /// Note: User-Agent is a forbidden header in browser XHR, skip on web.
  static Map<String, String> get _headers {
    final h = <String, String>{'Accept': 'application/vnd.github.v3+json'};
    if (!kIsWeb) h['User-Agent'] = 'Tianxuan';
    return h;
  }

  /// Fetch latest release from GitHub.
  /// Returns null on error, or (tag, url, newer) on success.
  static Future<({String tag, String url, bool newer})?> check() async {
    try {
      final resp = await http.get(Uri.parse(_api), headers: _headers);
      if (resp.statusCode != 200) {
        debugPrint('Update check: HTTP ${resp.statusCode}');
        return null;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = data['tag_name']?.toString() ?? '';
      final url = data['html_url']?.toString() ?? '';
      if (tag.isEmpty) return null;

      return (tag: tag, url: url, newer: _compareVersion(tag, currentVersion) > 0);
    } catch (e) {
      debugPrint('Update check error: $e');
      return null;
    }
  }
}

extension _NonNullIterable<T> on Iterable<T?> {
  Iterable<T> whereNotNull() => where((e) => e != null).cast<T>();
}
