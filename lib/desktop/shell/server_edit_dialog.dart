import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/desktop_server.dart';
import '../providers/desktop_server_provider.dart';

Future<void> showServerEditDialog(
  BuildContext context,
  WidgetRef ref, {
  DesktopServer? initial,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ServerEditDialog(initial: initial),
  );
}

class ServerEditDialog extends ConsumerStatefulWidget {
  final DesktopServer? initial;
  const ServerEditDialog({super.key, this.initial});

  @override
  ConsumerState<ServerEditDialog> createState() => _ServerEditDialogState();
}

class _ServerEditDialogState extends ConsumerState<ServerEditDialog> {
  late final _nameCtrl = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final _hostCtrl = TextEditingController(
    text: widget.initial?.host ?? '',
  );
  late final _portCtrl = TextEditingController(
    text: (widget.initial?.port ?? 22).toString(),
  );
  late final _userCtrl = TextEditingController(
    text: widget.initial?.username ?? 'root',
  );
  late final _passCtrl = TextEditingController(
    text: widget.initial?.password ?? '',
  );
  late final _keyCtrl = TextEditingController(
    text: widget.initial?.privateKey ?? '',
  );
  late final _panelUrlCtrl = TextEditingController(
    text: widget.initial?.panelUrl ?? '',
  );
  late bool _useKey =
      widget.initial?.privateKey != null &&
      widget.initial!.privateKey!.isNotEmpty;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _keyCtrl.dispose();
    _panelUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial != null ? '编辑服务器' : '添加服务器'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名称（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hostCtrl,
                decoration: const InputDecoration(
                  labelText: '主机地址',
                  hintText: 'example.com 或 1.2.3.4',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SSH 端口',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _useKey ? _keyCtrl : _passCtrl,
                decoration: InputDecoration(
                  labelText: _useKey ? '私钥内容' : '密码',
                  border: const OutlineInputBorder(),
                ),
                obscureText: !_useKey,
                maxLines: _useKey ? 4 : 1,
              ),
              CheckboxListTile(
                title: const Text('使用密钥'),
                value: _useKey,
                onChanged: (v) => setState(() => _useKey = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              TextField(
                controller: _panelUrlCtrl,
                decoration: const InputDecoration(
                  labelText: '面板网址（可选，1Panel/宝塔）',
                  hintText: 'http://host:port 或带面板路径',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;
    final server = DesktopServer(
      id:
          widget.initial?.id ??
          '${DateTime.now().millisecondsSinceEpoch}_$host',
      name: _nameCtrl.text.trim(),
      host: host,
      port: int.tryParse(_portCtrl.text.trim()) ?? 22,
      username: _userCtrl.text.trim(),
      password: _useKey ? null : _passCtrl.text.trim(),
      privateKey: _useKey ? _keyCtrl.text.trim() : null,
      panelUrl: _panelUrlCtrl.text.trim(),
    );
    final notifier = ref.read(desktopServersProvider.notifier);
    if (widget.initial != null) {
      notifier.update(server);
    } else {
      notifier.add(server);
    }
    Navigator.pop(context);
  }
}
