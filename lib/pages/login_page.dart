import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

// TODO: UI 同学 — 重新设计此页面样式
// 逻辑已写好：IP + 端口 + HTTPS 复选框 → 组装 URL → 连接
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _keyController = TextEditingController();
  bool _useHttps = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _ipController.text = 'localhost';
      _portController.text = '25568';
    }
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    final key = _keyController.text.trim();
    if (ip.isEmpty || port.isEmpty || key.isEmpty) return;

    final protocol = _useHttps ? 'https' : 'http';
    final url = '$protocol://$ip:$port';
    setState(() => _loading = true);

    final ok = await ref.read(settingsProvider.notifier).connect(url, key);

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      final err = ref.read(settingsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '连接失败'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('连接服务器')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // IP 地址
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: '192.168.1.100',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 端口
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '9999',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // API Key
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            // HTTPS 复选框
            Row(
              children: [
                Checkbox(
                  value: _useHttps,
                  onChanged: (v) => setState(() => _useHttps = v ?? false),
                ),
                const Text('使用 HTTPS'),
              ],
            ),
            const SizedBox(height: 16),
            // 连接按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _connect,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('连接', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
