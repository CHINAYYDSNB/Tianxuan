import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../api/client.dart';
import '../../services/storage_service.dart';

class ConnectionTestPage extends ConsumerStatefulWidget {
  const ConnectionTestPage({super.key});

  @override
  ConsumerState<ConnectionTestPage> createState() => _ConnectionTestPageState();
}

class _ConnectionTestPageState extends ConsumerState<ConnectionTestPage> {
  bool _testing = false;
  String? _apiUrl;
  int? _latencyMs;
  bool? _apiOk;
  String? _error;

  // SSH 检测
  bool _sshTesting = false;
  int? _sshLatencyMs;
  bool? _sshOk;
  String? _sshError;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final settings = ref.read(settingsProvider);
    if (!settings.isConnected) return;
    final url = await StorageService.instance.getServerUrl();
    if (mounted) setState(() => _apiUrl = url);
  }

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _error = null;
      _apiOk = null;
      _latencyMs = null;
    });

    try {
      final start = DateTime.now();
      final res = await ApiClient.instance.get('/dashboard/base/0/0');
      final ms = DateTime.now().difference(start).inMilliseconds;

      setState(() {
        _latencyMs = ms;
        _apiOk = res.data['code'] == 200;
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _apiOk = false;
        _error = e.toString();
        _testing = false;
      });
    }
  }

  Future<void> _runSshTest() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) {
      setState(() {
        _sshOk = false;
        _sshError = 'SSH 未连接，请先在服务器设置中配置 SSH';
      });
      return;
    }
    setState(() {
      _sshTesting = true;
      _sshError = null;
      _sshOk = null;
      _sshLatencyMs = null;
    });
    try {
      final start = DateTime.now();
      final res = await ssh.execute('echo pong');
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (!mounted) return;
      setState(() {
        _sshLatencyMs = ms;
        _sshOk = res.isSuccess;
        _sshError = res.isSuccess ? null : res.stderr.trim();
        _sshTesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sshOk = false;
        _sshError = e.toString();
        _sshTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = ref.watch(settingsProvider.select((s) => s.isConnected));

    return Scaffold(
      appBar: AppBar(title: const Text('连接检测')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    connected ? Icons.wifi_find : Icons.cloud_off,
                    size: 48,
                    color: connected
                        ? const Color(0xFFAAB4BF)
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    connected ? 'API 连接检测' : '未连接服务器',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_apiUrl != null)
                    Text(
                      _apiUrl!,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  if (!connected)
                    Text(
                      '请先添加服务器后再检测连接',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (connected) ...[
                    const SizedBox(height: 24),
                    if (_latencyMs != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _apiOk == true ? Icons.check_circle : Icons.error,
                            color: _apiOk == true ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _apiOk == true ? '连接正常' : '连接失败',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '响应时间: $_latencyMs ms',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _testing ? null : _runTest,
                        icon: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_testing ? '测试中...' : '运行 API 检测'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // SSH 连接与延迟检测
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, size: 20),
                      const SizedBox(width: 8),
                      Text('SSH 连接', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_sshLatencyMs != null) ...[
                    Row(
                      children: [
                        Icon(
                          _sshOk == true ? Icons.check_circle : Icons.error,
                          color: _sshOk == true ? Colors.green : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _sshOk == true ? 'SSH 连接正常' : 'SSH 连接异常',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_sshOk == true)
                      Text(
                        'SSH 延迟: $_sshLatencyMs ms',
                        style: theme.textTheme.bodyMedium,
                      ),
                    if (_sshError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _sshError!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _sshTesting ? null : _runSshTest,
                      icon: _sshTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.speed_outlined),
                      label: Text(_sshTesting ? '检测中...' : '检测 SSH 连接与延迟'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
