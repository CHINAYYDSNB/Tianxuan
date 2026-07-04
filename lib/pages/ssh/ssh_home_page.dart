import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/ssh_service.dart';
import 'ssh_terminal_page.dart';

class SshHomePage extends StatefulWidget {
  const SshHomePage({super.key});

  @override
  State<SshHomePage> createState() => _SshHomePageState();
}

class _SshHomePageState extends State<SshHomePage> {
  List<_SavedSsh> _connections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.instance.getSshConnections();
    if (raw != null && mounted) {
      setState(() => _connections = raw.map((m) => _SavedSsh.fromJson(m)).toList());
    }
  }

  Future<void> _save() async {
    await StorageService.instance.saveSshConnections(
        _connections.map((c) => c.toJson()).toList());
  }

  void _add() {
    showDialog(
      context: context,
      builder: (_) => _SshEditDialog(
        onSave: (conn) {
          setState(() => _connections.add(conn));
          _save();
        },
      ),
    );
  }

  void _edit(int index) {
    showDialog(
      context: context,
      builder: (_) => _SshEditDialog(
        initial: _connections[index],
        onSave: (conn) {
          setState(() => _connections[index] = conn);
          _save();
        },
      ),
    );
  }

  void _delete(int index) {
    setState(() => _connections.removeAt(index));
    _save();
  }

  void _connect(int index) {
    final conn = _connections[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SshConnectPage(
          host: conn.host,
          port: conn.port,
          username: conn.username,
          password: conn.password,
          privateKey: conn.privateKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSH 终端')),
      body: _connections.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terminal, size: 80,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('暂无 SSH 连接',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('点击右下角 + 添加服务器',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: _connections.length,
                itemBuilder: (_, i) {
                  final c = _connections[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.computer, color: Colors.green),
                      title: Text(c.name.isNotEmpty ? c.name : c.host),
                      subtitle: Text('${c.username}@${c.host}:${c.port}'),
                      trailing: PopupMenuButton(
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(value: 'del', child: Text('删除')),
                        ],
                        onSelected: (v) {
                          if (v == 'edit') _edit(i);
                          if (v == 'del') _delete(i);
                        },
                      ),
                      onTap: () => _connect(i),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 连接进度页（实时显示 SSH 日志）
class _SshConnectPage extends StatefulWidget {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;

  const _SshConnectPage({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
  });

  @override
  State<_SshConnectPage> createState() => _SshConnectPageState();
}

class _SshConnectPageState extends State<_SshConnectPage> {
  final _logs = <_LogLine>[];
  bool _done = false;
  bool _failed = false;
  SshService? _ssh;

  @override
  void initState() {
    super.initState();
    _addLog('正在连接到 ${widget.host}:${widget.port}...');
    _connect();
  }

  void _addLog(String msg, {bool isError = false, bool isOk = false}) {
    if (!mounted) return;
    setState(() => _logs.add(_LogLine(msg, isError, isOk)));
  }

  Future<void> _connect() async {
    _addLog('正在解析主机名...');
    await Future.delayed(const Duration(milliseconds: 300));

    _addLog('正在连接 SSH 服务器 ${widget.host}:${widget.port}...');
    await Future.delayed(const Duration(milliseconds: 300));

    _ssh = SshService();

    // 获取 proxy URL (APK 连服务器, Web 连本地)
    String? proxyUrl;
    try {
      final serverUrl = await StorageService.instance.getServerUrl();
      if (serverUrl != null && serverUrl.isNotEmpty) {
        proxyUrl = SshService.buildProxyUrl(serverUrl);
        _addLog('SSH 代理: $proxyUrl');
      }
    } catch (_) {}

    _addLog('身份验证方式: ${widget.password != null ? "密码" : "密钥"}');

    _ssh!.onData = (data) {
      final clean = data.replaceAll('\r\n', '\n').trim();
      if (clean.isEmpty) return;
      // 只显示服务端消息，不显示终端原始输出
      // 消息格式：[xxx] 来自 ssh_service.dart
      if (clean.startsWith('[')) {
        _addLog(clean.replaceAll('[', '').replaceAll(']', ''),
            isError: clean.contains('错误'),
            isOk: clean.contains('成功'));
        // 连接成功 → 跳终端
        if (clean.contains('连接成功')) {
          _done = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SshTerminalPage(
                    host: widget.host, port: widget.port,
                    username: widget.username,
                    password: widget.password,
                    privateKey: widget.privateKey,
                  ),
                ),
              );
            }
          });
        }
      }
    };

    _ssh!.onStateChange = (ok) {
      if (!ok && !_done && !_failed && mounted) {
        _addLog('连接已断开', isError: true);
        setState(() => _failed = true);
      }
    };

    try {
      await _ssh!.connect(
        host: widget.host,
        port: widget.port,
        username: widget.username,
        password: widget.password,
        privateKey: widget.privateKey,
        proxyUrl: proxyUrl,
      );
    } catch (e) {
      if (mounted) {
        _addLog('$e', isError: true);
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    if (!_done) _ssh?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSH 连接')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                if (!_done && !_failed)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (!_done && !_failed) const SizedBox(width: 8),
                Text(
                  _done ? '连接成功' : _failed ? '连接失败' : '正在连接...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_failed)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (_, i) {
                final log = _logs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        log.isError ? Icons.error : log.isOk ? Icons.check_circle : Icons.arrow_right,
                        size: 16,
                        color: log.isError ? Colors.red : log.isOk ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.msg,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: log.isError ? Colors.red : log.isOk ? Colors.green : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLine {
  final String msg;
  final bool isError;
  final bool isOk;
  const _LogLine(this.msg, [this.isError = false, this.isOk = false]);
}

/// 连接信息模型
class _SavedSsh {
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;

  const _SavedSsh({
    this.name = '',
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
  });

  Map<String, dynamic> toJson() => {
    'name': name, 'host': host, 'port': port,
    'username': username, 'password': password, 'privateKey': privateKey,
  };

  factory _SavedSsh.fromJson(Map<String, dynamic> m) => _SavedSsh(
    name: m['name']?.toString() ?? '',
    host: m['host']?.toString() ?? '',
    port: m['port'] as int? ?? 22,
    username: m['username']?.toString() ?? 'root',
    password: m['password']?.toString(),
    privateKey: m['privateKey']?.toString(),
  );
}

/// 编辑对话框
class _SshEditDialog extends StatefulWidget {
  final _SavedSsh? initial;
  final void Function(_SavedSsh) onSave;
  const _SshEditDialog({this.initial, required this.onSave});

  @override
  State<_SshEditDialog> createState() => _SshEditDialogState();
}

class _SshEditDialogState extends State<_SshEditDialog> {
  late final _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
  late final _hostCtrl = TextEditingController(text: widget.initial?.host ?? '');
  late final _portCtrl = TextEditingController(text: (widget.initial?.port ?? 22).toString());
  late final _userCtrl = TextEditingController(text: widget.initial?.username ?? 'root');
  late final _passCtrl = TextEditingController(text: widget.initial?.password ?? '');
  late final _keyCtrl = TextEditingController(text: widget.initial?.privateKey ?? '');
  late bool _useKey;

  @override
  void initState() {
    super.initState();
    _useKey = widget.initial?.privateKey != null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial != null ? '编辑连接' : '添加连接'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '名称（可选）', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _hostCtrl,
                decoration: const InputDecoration(labelText: '主机地址', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _portCtrl,
                decoration: const InputDecoration(labelText: '端口', border: OutlineInputBorder()),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _userCtrl,
                decoration: const InputDecoration(labelText: '用户名', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
              controller: _useKey ? _keyCtrl : _passCtrl,
              decoration: InputDecoration(
                  labelText: _useKey ? '私钥内容' : '密码',
                  border: const OutlineInputBorder()),
              obscureText: !_useKey,
              maxLines: _useKey ? 4 : 1,
            ),
            CheckboxListTile(
              title: const Text('使用密钥'),
              value: _useKey,
              onChanged: (v) => setState(() => _useKey = v ?? false),
              dense: true, contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;
    widget.onSave(_SavedSsh(
      name: _nameCtrl.text.trim(),
      host: host,
      port: int.tryParse(_portCtrl.text.trim()) ?? 22,
      username: _userCtrl.text.trim(),
      password: _useKey ? null : _passCtrl.text.trim(),
      privateKey: _useKey ? _keyCtrl.text.trim() : null,
    ));
    Navigator.pop(context);
  }
}
