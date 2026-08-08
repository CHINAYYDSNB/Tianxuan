import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified storage backend.
/// - Mobile: flutter_secure_storage (Android Keystore / iOS Keychain) for secrets
/// - Web: SharedPreferences (flutter_secure_storage_web may not be registered)
class StorageService {
  StorageService._();

  static final _instance = StorageService._();
  static StorageService get instance => _instance;

  // On web, use SharedPreferences directly since flutter_secure_storage_web
  // may not be auto-registered. On mobile, use FlutterSecureStorage for key material.
  static bool get _useSharedPrefs => kIsWeb;

  final _secure = _useSharedPrefs ? null : const FlutterSecureStorage();

  Future<void> _write(String key, String value) async {
    if (_useSharedPrefs) {
      final p = await SharedPreferences.getInstance();
      // Base64 encode for consistency with flutter_secure_storage_web
      await p.setString(key, base64Encode(utf8.encode(value)));
    } else {
      try {
        await _secure!.write(key: key, value: value);
      } catch (e) {
        debugPrint('StorageService._write error: $e');
        // Fallback: store in SharedPreferences on secure-storage failure
        final p = await SharedPreferences.getInstance();
        await p.setString('ss_$key', base64Encode(utf8.encode(value)));
      }
    }
  }

  Future<String?> _read(String key) async {
    if (_useSharedPrefs) {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null) return null;
      try {
        return utf8.decode(base64Decode(raw));
      } catch (_) {
        return raw;
      }
    } else {
      try {
        return await _secure!.read(key: key);
      } catch (e) {
        debugPrint('StorageService._read error: $e');
        // Fallback: read from SharedPreferences
        final p = await SharedPreferences.getInstance();
        final raw = p.getString('ss_$key');
        if (raw == null) return null;
        try {
          return utf8.decode(base64Decode(raw));
        } catch (_) {
          return raw;
        }
      }
    }
  }

  bool get isWeb => _useSharedPrefs;

  Future<void> _delete(String key) async {
    if (_useSharedPrefs) {
      final p = await SharedPreferences.getInstance();
      await p.remove(key);
    } else {
      try {
        await _secure!.delete(key: key);
      } catch (e) {
        debugPrint('StorageService._delete error: $e');
      }
      // Also clean fallback
      final p = await SharedPreferences.getInstance();
      await p.remove('ss_$key');
    }
  }

  // ─── API Key (sensitive, encrypted) ───

  Future<void> saveApiKey(String key) => _write('api_key', key);

  Future<String?> getApiKey() => _read('api_key');

  Future<void> deleteApiKey() => _delete('api_key');

  // ─── Server URL (non-sensitive) ───

  Future<void> saveServerUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('server_url', url);
  }

  Future<String?> getServerUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('server_url');
  }

  Future<void> deleteServerUrl() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('server_url');
  }

  // ─── Saved Servers List (keep apiKey encrypted, rest in prefs) ───

  /// Save server list metadata (without apiKey).
  /// Keys stored separately in secure storage.
  Future<void> saveServersJson(String json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('saved_servers', json);
  }

  Future<String?> getServersJson() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('saved_servers');
  }

  /// Encrypt/store a single saved server's apiKey.
  Future<void> saveServerKey(String serverId, String apiKey) =>
      _write('srv_key_$serverId', apiKey);

  /// Decrypt/load a single saved server's apiKey.
  Future<String?> getServerKey(String serverId) => _read('srv_key_$serverId');

  /// Delete a single saved server's apiKey.
  Future<void> deleteServerKey(String serverId) => _delete('srv_key_$serverId');

  /// 单个已保存服务器的 SSH 凭据（密码/私钥，加密存储）
  Future<void> saveServerSshPass(String serverId, String? pass) async {
    if (pass == null || pass.isEmpty) {
      await _delete('srv_ssh_pass_$serverId');
    } else {
      await _write('srv_ssh_pass_$serverId', pass);
    }
  }

  Future<String?> getServerSshPass(String serverId) =>
      _read('srv_ssh_pass_$serverId');

  Future<void> saveServerSshKey(String serverId, String? key) async {
    if (key == null || key.isEmpty) {
      await _delete('srv_ssh_key_$serverId');
    } else {
      await _write('srv_ssh_key_$serverId', key);
    }
  }

  Future<String?> getServerSshKey(String serverId) =>
      _read('srv_ssh_key_$serverId');

  // ─── Database instances (metadata in prefs, passwords encrypted) ───

  Future<void> saveDatabaseInstancesJson(String json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('db_instances', json);
  }

  Future<String?> getDatabaseInstancesJson() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('db_instances');
  }

  /// 加密保存单个数据库实例密码
  Future<void> saveDatabasePass(String id, String? pass) async {
    if (pass == null || pass.isEmpty) {
      await _delete('db_pass_$id');
    } else {
      await _write('db_pass_$id', pass);
    }
  }

  Future<String?> getDatabasePass(String id) => _read('db_pass_$id');

  // ─── First-launch migration (SharedPreferences → secure storage) ───

  Future<void> migrateIfNeeded() async {
    final p = await SharedPreferences.getInstance();
    final migrated = p.getBool('_migrated_v1');
    if (migrated == true) return;

    // migrate api_key
    final oldKey = p.getString('api_key');
    if (oldKey != null && oldKey.isNotEmpty) {
      await saveApiKey(oldKey);
      await p.remove('api_key');
    }

    // migrate saved server apiKeys
    final serversRaw = p.getString('saved_servers');
    if (serversRaw != null) {
      try {
        final list = (jsonDecode(serversRaw) as List)
            .cast<Map<String, dynamic>>();
        for (final s in list) {
          final key = s['apiKey'] as String?;
          final id = s['id'] as String?;
          if (key != null && id != null && key.isNotEmpty) {
            await saveServerKey(id, key);
          }
        }
        // Strip apiKey from saved_servers JSON
        final cleaned = list.map((s) {
          final m = Map<String, dynamic>.from(s);
          m.remove('apiKey');
          return m;
        }).toList();
        await saveServersJson(jsonEncode(cleaned));
      } catch (_) {}
    }

    await p.setBool('_migrated_v1', true);
  }

  // ─── Logto OIDC Pending (PKCE verifier + state 暂存) ───

  Future<void> saveLogtoPending(String verifier, String state) async {
    await _write(
      'logto_pending',
      jsonEncode({'verifier': verifier, 'state': state}),
    );
  }

  Future<Map<String, String>?> getLogtoPending() async {
    final raw = await _read('logto_pending');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map;
      return {
        'verifier': m['verifier']?.toString() ?? '',
        'state': m['state']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLogtoPending() => _delete('logto_pending');

  // ─── Logto OIDC Tokens ───

  Future<void> saveLogtoTokens({
    required String accessToken,
    String refreshToken = '',
    String idToken = '',
    int expiresIn = 3600,
  }) async {
    final expiry = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
    await _write('logto_at', accessToken);
    if (refreshToken.isNotEmpty) await _write('logto_rt', refreshToken);
    if (idToken.isNotEmpty) await _write('logto_id', idToken);
    await _write('logto_exp', expiry.toString());
  }

  Future<String?> getLogtoAccessToken() => _read('logto_at');
  Future<String?> getLogtoRefreshToken() => _read('logto_rt');
  Future<String?> getLogtoIdToken() => _read('logto_id');
  Future<bool> getLogtoTokenValid() async {
    final exp = await _read('logto_exp');
    if (exp == null) return false;
    final expiry = int.tryParse(exp) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  Future<void> deleteLogtoTokens() async {
    await _delete('logto_at');
    await _delete('logto_rt');
    await _delete('logto_id');
    await _delete('logto_exp');
  }

  // ─── SSH 连接保存 ───

  Future<void> saveSshConnections(
    List<Map<String, dynamic>> connections,
  ) async {
    await _write('ssh_connections', jsonEncode(connections));
  }

  Future<List<Map<String, dynamic>>?> getSshConnections() async {
    final raw = await _read('ssh_connections');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  // ─── 桌面版服务器（独立存储，与手机端 key 隔离） ───

  /// 桌面服务器列表元数据（不含密码/私钥）
  Future<void> saveDesktopServersJson(String json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('desktop_servers', json);
  }

  Future<String?> getDesktopServersJson() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('desktop_servers');
  }

  /// 桌面服务器密码（加密存储）
  Future<void> saveDesktopServerPass(String id, String? pass) async {
    if (pass == null || pass.isEmpty) {
      await _delete('desktop_ssh_pass_$id');
    } else {
      await _write('desktop_ssh_pass_$id', pass);
    }
  }

  Future<String?> getDesktopServerPass(String id) =>
      _read('desktop_ssh_pass_$id');

  /// 桌面服务器私钥（加密存储）
  Future<void> saveDesktopServerKey(String id, String? key) async {
    if (key == null || key.isEmpty) {
      await _delete('desktop_ssh_key_$id');
    } else {
      await _write('desktop_ssh_key_$id', key);
    }
  }

  Future<String?> getDesktopServerKey(String id) =>
      _read('desktop_ssh_key_$id');

  Future<void> deleteDesktopServerPass(String id) =>
      _delete('desktop_ssh_pass_$id');

  Future<void> deleteDesktopServerKey(String id) =>
      _delete('desktop_ssh_key_$id');
}
