import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../api/file_api.dart';
import '../providers/server_list_provider.dart';
import '../services/storage_service.dart';

class CloudBackupService {
  static const _backupPath = '/opt/1panel/.tianxuan-backup.json';

  /// 备份：当前连接 + 已保存服务器 + API Key(加密) + 设置 → 写到 1Panel
  static Future<void> backup({
    required List<SavedServer> servers,
  }) async {
    // 0. 包含当前服务器（如果已连接）
    final allServers = List<SavedServer>.from(servers);
    final currentUrl = await StorageService.instance.getServerUrl();
    final currentKey = await StorageService.instance.getApiKey();
    if (currentUrl != null && currentUrl.isNotEmpty && currentKey != null) {
      final alreadyInList = allServers.any((s) => s.url == currentUrl);
      if (!alreadyInList) {
        allServers.insert(0, SavedServer(
          id: 'current',
          name: '当前服务器',
          url: currentUrl,
          apiKey: currentKey,
        ));
      }
    }
    // 1. 加密 API Keys
    final key = await _deriveKey();
    final keysMap = <String, String>{};
    for (final s in allServers) {
      keysMap[s.id] = s.apiKey;
    }
    final encryptedKeys = key != null
        ? _encrypt(jsonEncode(keysMap), key)
        : jsonEncode(keysMap); // no Logto → plaintext

    // 2. 构建备份数据
    final data = {
      'version': 1,
      'encryptedKeys': encryptedKeys,
      'keyEncrypted': key != null,
      'exportedAt': DateTime.now().toIso8601String(),
      'servers': allServers.map((s) => s.toJson()).toList(),
    };

    // 3. 写文件 — 先确保文件存在
    final json = jsonEncode(data);
    final dir = _backupPath.substring(0, _backupPath.lastIndexOf('/'));
    try { await FileApi.create(dir, isDir: true, mode: 493); } catch (_) {}
    try { await FileApi.create(_backupPath, isDir: false); } catch (e) {
      // 文件已存在 → 忽略
    }
    await FileApi.save(_backupPath, json);
  }

  /// 恢复：读文件 → 解析 → 解密 → 返回
  static Future<BackupData?> restore() async {
    try {
      final raw = await FileApi.getContent(_backupPath);
      final json = raw.content;
      if (json == null || json.isEmpty) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      if (data['version'] != 1) return null;

      // 解析服务器列表
      final serversRaw = data['servers'] as List? ?? [];
      final servers = <SavedServer>[];

      // 解密 API Keys
      final key = await _deriveKey();
      final keysMap = <String, String>{};
      final encryptedKeysStr = data['encryptedKeys'] as String?;
      final keyEncrypted = data['keyEncrypted'] as bool? ?? false;

      if (encryptedKeysStr != null) {
        if (keyEncrypted && key != null) {
          final decrypted = _decrypt(encryptedKeysStr, key);
          if (decrypted != null) {
            keysMap.addAll(
              (jsonDecode(decrypted) as Map<String, dynamic>)
                  .map((k, v) => MapEntry(k, v.toString())),
            );
          }
        } else if (!keyEncrypted) {
          keysMap.addAll(
            (jsonDecode(encryptedKeysStr) as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, v.toString())),
          );
        }
      }

      for (final e in serversRaw) {
        final m = e as Map<String, dynamic>;
        final id = m['id']?.toString() ?? '';
        servers.add(SavedServer(
          id: id,
          name: m['name']?.toString() ?? '',
          url: m['url']?.toString() ?? '',
          apiKey: keysMap[id] ?? '',
        ));
      }

      return BackupData(
        servers: servers,
        exportedAt: data['exportedAt']?.toString() ?? '',
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

  /// 从 Logto ID token 派生加密 key
  /// 没登录 → 返回 null（不加密）
  static Future<List<int>?> _deriveKey() async {
    final idToken = await StorageService.instance.getLogtoIdToken();
    if (idToken == null || idToken.isEmpty) return null;
    return sha256.convert(utf8.encode(idToken)).bytes.toList();
  }

  /// XOR 加密（可逆）
  static String _encrypt(String plain, List<int> key) {
    final bytes = utf8.encode(plain);
    final result = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return base64Url.encode(result);
  }

  /// XOR 解密
  static String? _decrypt(String cipher, List<int> key) {
    try {
      final bytes = base64Url.decode(cipher);
      final result = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
      return utf8.decode(result);
    } catch (_) {
      return null;
    }
  }
}

class BackupData {
  final List<SavedServer> servers;
  final String exportedAt;

  BackupData({
    required this.servers,
    this.exportedAt = '',
  });
}
