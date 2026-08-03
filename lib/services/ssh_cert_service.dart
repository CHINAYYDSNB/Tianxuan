import 'package:flutter/foundation.dart';
import '../api/client.dart';
import 'storage_service.dart';

/// 自动导入结果
class SshCertImportResult {
  final bool success;
  final bool hasKey;
  final bool alreadyExists;
  final String? reason;

  const SshCertImportResult({
    required this.success,
    this.hasKey = false,
    this.alreadyExists = false,
    this.reason,
  });
}

/// 用 1Panel API 自动获取本机 SSH 私钥并添加为 SSH 连接。
///
/// 流程：
///  1. `POST /api/v2/hosts/ssh/search` 拿 SSH 端口与当前用户（通常是 root）。
///  2. `POST /api/v2/hosts/ssh/cert` 拿服务器私钥（best-effort —— 部分 1Panel
///     版本在已有密钥时该接口的「替换」分支会异常，此时私钥为 null，但连接仍
///     可添加，用户可改用免密的「主机终端」入口）。
///
/// 主机地址：web 端只知道同源代理，用 sentinel `'panel'`，由 `server.mjs` 的
/// `/ssh-proxy` 解析为真实 1Panel 主机；移动端用真实服务器地址直连。
class SshCertImporter {
  static Future<SshCertImportResult> importFromCurrentServer() async {
    final api = ApiClient.instance;
    if (api.serverUrl.isEmpty) {
      return const SshCertImportResult(success: false, reason: '未连接到服务器');
    }

    // 1) SSH 服务信息
    Map<String, dynamic> sshInfo = {};
    try {
      final resp = await api.post(
        '/hosts/ssh/search',
        data: <String, dynamic>{},
      );
      final body = resp.data;
      if (body is Map) {
        sshInfo = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
      }
    } catch (e) {
      return SshCertImportResult(success: false, reason: '获取 SSH 信息失败: $e');
    }

    final port = int.tryParse(sshInfo['port']?.toString() ?? '22') ?? 22;
    final username = (sshInfo['currentUser']?.toString().isNotEmpty == true)
        ? sshInfo['currentUser'].toString()
        : 'root';
    final host = kIsWeb ? 'panel' : _realHost(api.serverUrl);

    // 2) 私钥（best-effort）
    //    优先用官方接口 `/hosts/ssh/cert`；该接口在某些 1Panel 上因
    //    服务端残留状态（.tmp）而失败，此时回退到读取已授权的 root 私钥文件
    //    （1Panel 标准文件名 `/<home>/.ssh/id_<type>_1panel`）。
    final privateKey = await _fetchPrivateKey(api, username);

    // 3) 组装 + 去重保存
    final conn = <String, dynamic>{
      'name': '1Panel 主机 (自动)',
      'host': host,
      'port': port,
      'username': username,
      'password': null,
      'privateKey': privateKey,
    };

    final existing = await StorageService.instance.getSshConnections() ?? [];
    final dup = existing.any(
      (c) =>
          c['host'] == host &&
          (c['port'] ?? 22) == port &&
          (c['username'] ?? '') == username,
    );
    if (dup) {
      return SshCertImportResult(
        success: true,
        alreadyExists: true,
        hasKey: privateKey != null,
        reason: privateKey == null ? '已有连接但未获取到私钥，请手动配置' : null,
      );
    }

    existing.add(conn);
    await StorageService.instance.saveSshConnections(existing);
    return SshCertImportResult(
      success: true,
      hasKey: privateKey != null,
      reason: privateKey == null ? '已添加连接，但自动获取私钥失败，请手动编辑配置私钥' : null,
    );
  }

  /// 获取本机 root 私钥。
  ///
  /// 优先调用官方接口 `POST /hosts/ssh/cert`（在健康的 1Panel 上返回私钥）。
  /// 若该接口因服务端残留状态（如 `/root/.ssh/.tmp` 未清理）而失败，则回退到
  /// 通过文件读取接口 `POST /files/content` 读取 1Panel 已生成的、已加入
  /// authorized_keys 的 root 私钥文件 —— 两者本质相同，都能直接用于 SSH 登录。
  static Future<String?> _fetchPrivateKey(
    ApiClient api,
    String username,
  ) async {
    // 1) 官方接口：不同 1Panel 版本参数不同，尝试多种 payload
    for (final payload in [
      <String, dynamic>{'encryptionMode': 'ed25519', 'passPhrase': ''},
      <String, dynamic>{'id': 1, 'encryptionMode': 'ed25519', 'passPhrase': ''},
    ]) {
      try {
        final certResp = await api.post('/hosts/ssh/cert', data: payload);
        final body = certResp.data;
        if (body is Map) {
          final data = body['data'];
          if (data is Map) {
            final k =
                data['privateKey'] ??
                data['private_key'] ??
                data['key'] ??
                data['privateKeyPem'];
            if (k is String && k.trim().isNotEmpty) return k.trim();
          }
        }
      } catch (e) {
        debugPrint('[ssh-cert] ssh/cert 失败，尝试下一 payload: $e');
      }
    }

    // 2) 回退：读取已授权的 root 私钥文件
    final home = username == 'root' ? '/root' : '/home/$username';
    final candidates = [
      'id_ed25519_1panel',
      'id_rsa_1panel',
      'id_ecdsa_1panel',
      'id_ed25519',
      'id_rsa',
    ];
    for (final name in candidates) {
      try {
        final resp = await api.post(
          '/files/content',
          data: <String, dynamic>{'path': '$home/.ssh/$name'},
        );
        final body = resp.data;
        if (body is Map) {
          final data = body['data'];
          if (data is Map) {
            final content = data['content'];
            if (content is String && content.contains('PRIVATE KEY')) {
              return content;
            }
          }
        }
      } catch (_) {
        // 该候选不存在，尝试下一个
      }
    }
    return null;
  }

  static String _realHost(String serverUrl) {
    try {
      return Uri.parse(serverUrl).host;
    } catch (_) {
      return 'localhost';
    }
  }
}
