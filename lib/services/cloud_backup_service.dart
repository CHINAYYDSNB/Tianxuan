import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/file_api.dart';
import '../models/backup_item.dart';
import '../providers/server_list_provider.dart';
import '../services/storage_service.dart';

class CloudBackupService {
  static const _backupPath = '/opt/1panel/.tianxuan-backup.json';

  /// 备份：按所选项目收集数据 → 加密敏感项 → 写到 1Panel
  static Future<void> backup({
    required List<SavedServer> servers,
    required List<BackupItem> items,
  }) async {
    // 0. 包含当前服务器（如果已连接）
    final allServers = List<SavedServer>.from(servers);
    final currentUrl = await StorageService.instance.getServerUrl();
    final currentKey = await StorageService.instance.getApiKey();
    if (currentUrl != null &&
        currentUrl.isNotEmpty &&
        currentKey != null &&
        items.contains(BackupItem.servers)) {
      final alreadyInList = allServers.any((s) => s.url == currentUrl);
      if (!alreadyInList) {
        allServers.insert(
          0,
          SavedServer(
            id: 'current',
            name: '当前服务器',
            url: currentUrl,
            apiKey: currentKey,
          ),
        );
      }
    }

    // 1. 加密敏感数据
    final key = await _deriveKey();
    final sensitive = <String, String>{};
    if (items.contains(BackupItem.servers)) {
      for (final s in allServers) {
        sensitive['server_key_${s.id}'] = s.apiKey;
      }
    }
    if (items.contains(BackupItem.aiConfig)) {
      final ai = await _collectAiConfig();
      sensitive['ai_config'] = jsonEncode(ai);
    }
    if (items.contains(BackupItem.sshConnections)) {
      final ssh = await StorageService.instance.getSshConnections();
      if (ssh != null) {
        sensitive['ssh_connections'] = jsonEncode(ssh);
      }
    }
    if (items.contains(BackupItem.logtoTokens)) {
      final tokens = await _collectLogtoTokens();
      if (tokens.isNotEmpty) {
        sensitive['logto_tokens'] = jsonEncode(tokens);
      }
    }
    final encryptedKeys = key != null
        ? _encrypt(jsonEncode(sensitive), key)
        : jsonEncode(sensitive);

    // 2. 构建备份数据
    final data = <String, dynamic>{
      'version': 2,
      'encryptedKeys': encryptedKeys,
      'keyEncrypted': key != null,
      'exportedAt': DateTime.now().toIso8601String(),
      'items': items.map((i) => i.name).toList(),
    };
    if (items.contains(BackupItem.servers)) {
      data['servers'] = allServers.map((s) => s.toJson()).toList();
    }
    if (items.contains(BackupItem.theme)) {
      final theme = await _collectTheme();
      data['theme'] = theme;
    }

    // 3. 写文件
    final json = jsonEncode(data);
    final dir = _backupPath.substring(0, _backupPath.lastIndexOf('/'));
    try {
      await FileApi.create(dir, isDir: true, mode: 493);
    } catch (_) {}
    try {
      await FileApi.create(_backupPath, isDir: false);
    } catch (e) {}
    await FileApi.save(_backupPath, json);
  }

  /// 恢复备份（返回备份数据供调用方选择性恢复）
  static Future<BackupData?> restore() async {
    try {
      final raw = await FileApi.getContent(_backupPath);
      final json = raw.content;
      if (json == null || json.isEmpty) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      if (data['version'] != 2) return null;

      // 解密敏感数据
      final key = await _deriveKey();
      final sensitive = <String, String>{};
      final encryptedKeysStr = data['encryptedKeys'] as String?;
      final keyEncrypted = data['keyEncrypted'] as bool? ?? false;
      if (encryptedKeysStr != null) {
        if (keyEncrypted && key != null) {
          final decrypted = _decrypt(encryptedKeysStr, key);
          if (decrypted != null) {
            sensitive.addAll(
              (jsonDecode(decrypted) as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, v.toString()),
              ),
            );
          }
        } else if (!keyEncrypted) {
          sensitive.addAll(
            (jsonDecode(encryptedKeysStr) as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v.toString()),
            ),
          );
        }
      }

      // 解析服务器列表
      final serversRaw = data['servers'] as List? ?? [];
      final servers = <SavedServer>[];
      for (final e in serversRaw) {
        final m = e as Map<String, dynamic>;
        final id = m['id']?.toString() ?? '';
        servers.add(
          SavedServer(
            id: id,
            name: m['name']?.toString() ?? '',
            url: m['url']?.toString() ?? '',
            apiKey: sensitive['server_key_$id'] ?? '',
          ),
        );
      }

      // 解析备份项目
      final itemsRaw = data['items'] as List? ?? <String>[];
      final items = itemsRaw
          .map((n) => BackupItem.values.asNameMap()[n])
          .whereType<BackupItem>()
          .toList();

      return BackupData(
        servers: servers,
        exportedAt: data['exportedAt']?.toString() ?? '',
        items: items,
        theme: data['theme'] as Map<String, dynamic>?,
        sensitive: sensitive,
      );
    } catch (e) {
      throw Exception('恢复失败: $e');
    }
  }

  /// 检查是否有备份
  static Future<bool> hasBackup() async {
    try {
      await FileApi.getContent(_backupPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 获取备份时间
  static Future<String?> getBackupTime() async {
    try {
      final raw = await FileApi.getContent(_backupPath);
      if (raw.content == null) return null;
      final data = jsonDecode(raw.content!) as Map<String, dynamic>;
      return data['exportedAt']?.toString();
    } catch (_) {
      return null;
    }
  }

  // ─── 收集辅助 ───

  static Future<Map<String, dynamic>> _collectAiConfig() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('ai_config');
      if (raw != null) {
        return (jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> _collectLogtoTokens() async {
    final at = await StorageService.instance.getLogtoAccessToken();
    final rt = await StorageService.instance.getLogtoRefreshToken();
    final id = await StorageService.instance.getLogtoIdToken();
    return {
      if (at != null) 'access_token': at,
      if (rt != null) 'refresh_token': rt,
      if (id != null) 'id_token': id,
    };
  }

  static Future<Map<String, dynamic>> _collectTheme() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('app_theme_v1');
      if (raw != null) return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  // ─── 加密 ───

  static Future<List<int>?> _deriveKey() async {
    final idToken = await StorageService.instance.getLogtoIdToken();
    if (idToken == null || idToken.isEmpty) return null;
    return sha256.convert(utf8.encode(idToken)).bytes.toList();
  }

  static String _encrypt(String plain, List<int> key) {
    final bytes = utf8.encode(plain);
    final result = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ key[i % key.length],
    );
    return base64Url.encode(result);
  }

  static String? _decrypt(String cipher, List<int> key) {
    try {
      final bytes = base64Url.decode(cipher);
      final result = List<int>.generate(
        bytes.length,
        (i) => bytes[i] ^ key[i % key.length],
      );
      return utf8.decode(result);
    } catch (_) {
      return null;
    }
  }
}

/// 通过 SharedPreferences 读取（供主题收集）

class BackupData {
  final List<SavedServer> servers;
  final String exportedAt;
  final List<BackupItem> items;
  final Map<String, dynamic>? theme;
  final Map<String, String> sensitive;

  BackupData({
    required this.servers,
    this.exportedAt = '',
    this.items = const [],
    this.theme,
    this.sensitive = const {},
  });
}
