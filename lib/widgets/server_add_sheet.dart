import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/server_list_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/ssh_connection_provider.dart';
import '../services/ssh_cert_service.dart';
import '../services/ssh_command_service.dart';
import '../services/storage_service.dart';
import 'package:tianxuan/theme/app_colors.dart';

/// 添加 1Panel 服务器后自动获取 SSH 密钥并添加连接
Future<void> _autoSetupSshFor1Panel(
  BuildContext context,
  String serverUrl,
  String serverName,
) async {
  // 优先：1Panel API 自动获取本机 SSH 私钥并添加连接（含去重）
  try {
    final result = await SshCertImporter.importFromCurrentServer();
    if (result.success) return;
  } catch (_) {}
  // 兜底：仅添加一条主机连接（凭据待用户补全）
  if (kIsWeb) return;
  try {
    final host = Uri.parse(serverUrl).host;
    if (host.isEmpty) return;
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

/// 从底部弹出"添加服务器"表单（支持 1Panel API / 纯 SSH 两种类型）
void showServerAddSheet(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final ipCtrl = TextEditingController();
  final portCtrl = TextEditingController();
  final keyCtrl = TextEditingController();
  // SSH 直连字段
  final sshUserCtrl = TextEditingController(text: 'root');
  final sshPassCtrl = TextEditingController();
  final sshKeyCtrl = TextEditingController();
  bool https = false;
  String serverType = '1panel';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '添加服务器',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '支持 1Panel API 或纯 SSH 直连',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  // 类型选择
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '1panel', label: Text('1Panel')),
                      ButtonSegment(value: 'ssh', label: Text('SSH 直连')),
                    ],
                    selected: {serverType},
                    onSelectionChanged: (s) =>
                        setSheetState(() => serverType = s.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      border: OutlineInputBorder(),
                      hintText: '我的服务器',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ipCtrl,
                    decoration: InputDecoration(
                      labelText: serverType == '1panel' ? 'IP 地址' : 'SSH 地址',
                      border: const OutlineInputBorder(),
                      hintText: '192.168.1.100',
                      prefixIcon: const Icon(Icons.public),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: portCtrl,
                    decoration: InputDecoration(
                      labelText: serverType == '1panel' ? '端口' : 'SSH 端口',
                      border: const OutlineInputBorder(),
                      hintText: serverType == '1panel' ? '9999' : '22',
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (serverType == '1panel') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      obscureText: true,
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: https,
                          onChanged: (v) =>
                              setSheetState(() => https = v ?? false),
                        ),
                        const Text('使用 HTTPS'),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: sshUserCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SSH 用户名',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sshPassCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SSH 密码',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sshKeyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SSH 私钥（可选，粘贴 PEM）',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                      maxLines: 3,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final ip = ipCtrl.text.trim();
                        final port = portCtrl.text.trim();
                        if (name.isEmpty || ip.isEmpty || port.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('请填写名称、地址和端口')),
                          );
                          return;
                        }
                        if (serverType == '1panel' &&
                            keyCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('请填写 API Key')),
                          );
                          return;
                        }
                        final id = DateTime.now().millisecondsSinceEpoch
                            .toString();

                        if (serverType == 'ssh') {
                          // 纯 SSH 服务器
                          final svr = SavedServer(
                            id: id,
                            name: name,
                            url: 'ssh://$ip:$port',
                            apiKey: '',
                            type: 'ssh',
                            sshHost: ip,
                            sshPort: int.tryParse(port) ?? 22,
                            sshUsername: sshUserCtrl.text.trim(),
                            sshPassword: sshPassCtrl.text.isEmpty
                                ? null
                                : sshPassCtrl.text,
                            sshPrivateKey: sshKeyCtrl.text.isEmpty
                                ? null
                                : sshKeyCtrl.text,
                          );
                          await ref
                              .read(savedServersProvider.notifier)
                              .add(svr);
                          // 测试 SSH 连接
                          final config = SshConfig(
                            host: ip,
                            port: int.tryParse(port) ?? 22,
                            username: sshUserCtrl.text.trim(),
                            password: sshPassCtrl.text.isEmpty
                                ? null
                                : sshPassCtrl.text,
                            privateKey: sshKeyCtrl.text.isEmpty
                                ? null
                                : sshKeyCtrl.text,
                          );
                          final err = await ref
                              .read(sshConnectionProvider.notifier)
                              .connect(config);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  err == null
                                      ? 'SSH 服务器已添加并连接'
                                      : '已添加，但 SSH 连接失败: $err',
                                ),
                                backgroundColor: err == null
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            );
                          }
                          return;
                        }

                        // 1Panel 服务器
                        final proto = https ? 'https' : 'http';
                        final url = '$proto://$ip:$port';
                        final svr = SavedServer(
                          id: id,
                          name: name,
                          url: url,
                          apiKey: keyCtrl.text.trim(),
                        );
                        // Web 跨域不能直连, 跳过测试
                        if (kIsWeb) {
                          await ref
                              .read(savedServersProvider.notifier)
                              .add(svr);
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
                        // 自动获取 SSH 密钥并添加连接
                        await _autoSetupSshFor1Panel(ctx, url, name);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('测试并添加'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
