import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// 桌面版自动更新：启动时检查 GitHub Releases latest。
/// 有新版本 → 下载 setup.exe → 静默安装（NSIS /S）→ 重启。
class DesktopUpdater {
  DesktopUpdater._();
  static final instance = DesktopUpdater._();

  static const _repo = 'CHINAYYDSNB/Tianxuan';
  static const _api = 'https://api.github.com/repos/$_repo/releases/latest';

  /// 检查并下载。返回新版本 tag；无更新返回 null。
  Future<String?> checkOnStartup() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final resp = await http.get(
        Uri.parse(_api),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Tianxuan-Desktop',
        },
      );
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = data['tag_name']?.toString() ?? '';
      if (tag.isEmpty) return null;
      if (!_isNewer(tag, info.version)) return null;
      return tag;
    } catch (e) {
      debugPrint('DesktopUpdater check error: $e');
      return null;
    }
  }

  static bool _isNewer(String remote, String current) {
    final a = remote
        .replaceAll(RegExp(r'^v'), '')
        .split(RegExp(r'[-+]'))[0]
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    final b = current
        .replaceAll(RegExp(r'^v'), '')
        .split(RegExp(r'[-+]'))[0]
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return a.length > b.length;
  }

  /// 下载 setup.exe 并静默安装。返回错误消息或 null。
  Future<String?> downloadAndInstall() async {
    try {
      final resp = await http.get(
        Uri.parse(_api),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Tianxuan-Desktop',
        },
      );
      if (resp.statusCode != 200) return '无法获取发布信息 (HTTP ${resp.statusCode})';
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final assets = (data['assets'] as List?)?.cast<Map<String, dynamic>>();
      final setupList = assets
          ?.where((a) => (a['name']?.toString() ?? '').endsWith('.exe'))
          .toList();
      final setup = (setupList == null || setupList.isEmpty)
          ? null
          : setupList.first;
      if (setup == null) return '发布中没有找到安装包';
      final url = setup['browser_download_url']?.toString() ?? '';
      if (url.isEmpty) return '安装包下载地址为空';

      final dir = await Directory.systemTemp.createTemp('tianxuan_update');
      final target = '${dir.path}${Platform.pathSeparator}setup.exe';
      final file = File(target);
      final downloadResp = await http.get(Uri.parse(url));
      if (downloadResp.statusCode != 200)
        return '下载失败 (HTTP ${downloadResp.statusCode})';
      await file.writeAsBytes(downloadResp.bodyBytes);

      // NSIS 静默安装
      await Process.run(target, ['/S', '/D=C:\\Program Files\\Tianxuan']);
      return null;
    } catch (e) {
      debugPrint('DesktopUpdater install error: $e');
      return e.toString();
    }
  }
}
