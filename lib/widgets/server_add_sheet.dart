import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/server_list_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/storage_service.dart';

/// 添加服务器成功后自动配置 SSH 连接
Future<void> _autoSetupSsh(
  BuildContext context,
  String serverUrl,
  String serverName,
) async {
  if (kIsWeb) return;
  try {
    final host = Uri.parse(serverUrl).host;
    if (host.isEmpty) return;
    // 保存一条 SSH 连接（主机 + root，凭据待用户补全）
    final connections = await StorageService.instance.getSshConnections();
    final list = List<Map<String, dynamic>>.from(connections ?? []);
    final exists = list.any((c) => c['host'] == host);
    if (!exists) {
      list.add({
        'host': host,
        'port': 22,
        'username': 'root',
        'name': serverName,
      });
      await StorageService.instance.saveSshConnections(list);
    }
  } catch (_) {}
}

/// 从底部弹出"添加服务器"表单
void showServerAddSheet(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final ipCtrl = TextEditingController();
  final portCtrl = TextEditingController();
  final keyCtrl = TextEditingController();
  bool https = false;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              32 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '添加服务器',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    border: OutlineInputBorder(),
                    hintText: '我的服务器',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP 地址',
                    border: OutlineInputBorder(),
                    hintText: '192.168.1.100',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(
                    labelText: '端口',
                    border: OutlineInputBorder(),
                    hintText: '9999',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                Row(
                  children: [
                    Checkbox(
                      value: https,
                      onChanged: (v) => setSheetState(() => https = v ?? false),
                    ),
                    const Text('使用 HTTPS'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final ip = ipCtrl.text.trim();
                      final port = portCtrl.text.trim();
                      final key = keyCtrl.text.trim();
                      if (name.isEmpty ||
                          ip.isEmpty ||
                          port.isEmpty ||
                          key.isEmpty)
                        return;
                      final proto = https ? 'https' : 'http';
                      final url = '$proto://$ip:$port';
                      final id = DateTime.now().millisecondsSinceEpoch
                          .toString();
                      final svr = SavedServer(
                        id: id,
                        name: name,
                        url: url,
                        apiKey: key,
                      );
                      // Web 跨域不能直连其他服务器, 跳过测试直接保存
                      if (kIsWeb) {
                        await ref.read(savedServersProvider.notifier).add(svr);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('已保存, 点击切换即可连接')),
                        );
                        return;
                      }
                      final err = await ref
                          .read(savedServersProvider.notifier)
                          .switchTo(svr, test: true);
                      if (!ctx.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('连接测试失败: $err'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      await ref.read(savedServersProvider.notifier).add(svr);
                      Navigator.pop(ctx);
                      ref.read(serverStatusProvider.notifier).refresh();
                      // 自动配置 SSH 连接（从 1Panel 地址提取主机）
                      await _autoSetupSsh(ctx, url, name);
                    },
                    child: const Text('测试并添加'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
