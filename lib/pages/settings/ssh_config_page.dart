import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/ssh_command_service.dart';
import '../../services/storage_service.dart';

class SshConfigPage extends ConsumerStatefulWidget {
  const SshConfigPage({super.key});

  @override
  ConsumerState<SshConfigPage> createState() => _SshConfigPageState();
}

class _SshConfigPageState extends ConsumerState<SshConfigPage> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController(text: 'root');
  final _passCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _usePassword = true;
  bool _loading = false;
  String? _error;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final raw = await StorageService.instance.getSshConnections();
    bool hasSaved = false;
    if (raw != null && raw.isNotEmpty) {
      final first = raw.first;
      _hostCtrl.text = first['host']?.toString() ?? '';
      _portCtrl.text = first['port']?.toString() ?? '22';
      _userCtrl.text = first['username']?.toString() ?? 'root';
      final pwd = first['password']?.toString();
      final key = first['privateKey']?.toString();
      if (pwd != null && pwd.isNotEmpty) {
        _passCtrl.text = pwd;
        _usePassword = true;
        hasSaved = true;
      } else if (key != null && key.isNotEmpty) {
        _keyCtrl.text = key;
        _usePassword = false;
        hasSaved = true;
      }
    }

    // Auto-detect host from 1Panel connection if not saved
    if (!hasSaved && _hostCtrl.text.isEmpty) {
      final host = await SshConnectionNotifier.detectServerHost();
      if (host != null && host.isNotEmpty) {
        _hostCtrl.text = host;
      }
    }

    final ssh = ref.read(sshServiceProvider);
    setState(() => _isConnected = ssh != null);
  }

  Future<void> _connect() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 22;
    final username = _userCtrl.text.trim();

    if (host.isEmpty) {
      setState(() => _error = '请输入主机地址');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final config = SshConfig(
      host: host,
      port: port,
      username: username,
      password: _usePassword ? _passCtrl.text : null,
      privateKey: _usePassword ? null : _keyCtrl.text,
    );

    final err = await ref.read(sshConnectionProvider.notifier).connect(config);
    if (mounted) {
      setState(() {
        _loading = false;
        _error = err;
        _isConnected = err == null;
      });
    }
  }

  void _disconnect() {
    ref.read(sshConnectionProvider.notifier).disconnect();
    setState(() => _isConnected = false);
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(sshConnectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SSH 连接')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status
          Card(
            color: _isConnected
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.link_off,
                    color: _isConnected ? Colors.green : const Color(0xFF686F78),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      connectionState.when(
                        data: (s) => s != null ? '已连接' : '未连接',
                        loading: () => '连接中...',
                        error: (e, _) => '连接失败',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_isConnected)
                    TextButton(
                      onPressed: _disconnect,
                      child: const Text('断开', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.red.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Form
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(
              labelText: '主机地址',
              hintText: '192.168.1.100',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.computer),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portCtrl,
            decoration: const InputDecoration(
              labelText: '端口',
              hintText: '22',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pin),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: 'root',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          // Auth method toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('密码')),
              ButtonSegment(value: false, label: Text('私钥')),
            ],
            selected: {_usePassword},
            onSelectionChanged: (s) => setState(() => _usePassword = s.first),
          ),
          const SizedBox(height: 12),
          if (_usePassword)
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            )
          else
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: '私钥文件路径',
                hintText: '/data/data/com.tianxuan/files/key 或粘贴 PEM 内容',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              maxLines: 5,
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : _connect,
              icon: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link),
              label: Text(_loading ? '连接中...' : '连接'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '用于 Docker 容器、镜像、Compose 管理的 SSH 连接',
            style: TextStyle(fontSize: 12, color: Color(0xFF686F78)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
