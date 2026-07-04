import 'package:flutter/material.dart';
import 'package:xterm/ui.dart';
import 'package:xterm/xterm.dart';
import '../../services/ssh_service.dart';
import '../../services/storage_service.dart';

class SshTerminalPage extends StatefulWidget {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;

  const SshTerminalPage({
    super.key,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
  });

  @override
  State<SshTerminalPage> createState() => _SshTerminalPageState();
}

class _SshTerminalPageState extends State<SshTerminalPage> {
  static const _termTheme = TerminalTheme(
    cursor: Color(0xFFD4D4D4),
    selection: Color(0x40FFFFFF),
    foreground: Color(0xFFD4D4D4),
    background: Color(0xFF1E1E1E),
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF0DBC79),
    yellow: Color(0xFFE5E510),
    blue: Color(0xFF2472C8),
    magenta: Color(0xFFBC3FBC),
    cyan: Color(0xFF11A8CD),
    white: Color(0xFFE5E5E5),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFF14C4C),
    brightGreen: Color(0xFF23D18B),
    brightYellow: Color(0xFFF5F543),
    brightBlue: Color(0xFF3B8EEA),
    brightMagenta: Color(0xFFD670D6),
    brightCyan: Color(0xFF00B7C3),
    brightWhite: Color(0xFFFFFFFF),
    searchHitForeground: Color(0xFF000000),
    searchHitBackground: Color(0xFFE5E510),
    searchHitBackgroundCurrent: Color(0xFFF5F543),
  );

  late final Terminal _terminal;
  final _sshService = SshService();
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 2000);
    _terminal.onOutput = _onTerminalOutput;
    _terminal.onResize = _onTerminalResize;
    _sshService.onData = _onSshData;
    _sshService.onStateChange = _onSshState;
    _connect();
  }

  void _onTerminalOutput(String data) {
    _sshService.write(data);
  }

  void _onTerminalResize(int w, int h, int pw, int ph) {
    _sshService.resize(w, h);
  }

  void _onSshData(String data) {
    _terminal.write(data);
  }

  void _onSshState(bool connected) {
    if (mounted) setState(() => _connecting = !connected);
  }

  Future<void> _connect() async {
    // 获取 proxy URL (APK 连服务器, Web 连本地)
    String? proxyUrl;
    try {
      final serverUrl = await StorageService.instance.getServerUrl();
      if (serverUrl != null && serverUrl.isNotEmpty) {
        proxyUrl = SshService.buildProxyUrl(serverUrl);
      }
    } catch (_) {}

    try {
      await _sshService.connect(
        host: widget.host,
        port: widget.port,
        username: widget.username,
        password: widget.password,
        privateKey: widget.privateKey,
        proxyUrl: proxyUrl,
      );
    } catch (e) {
      if (mounted) setState(() {
        _connecting = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _sshService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.username}@${widget.host}:${widget.port}'),
        actions: [
          if (_sshService.isConnected)
            IconButton(
              icon: const Icon(Icons.keyboard),
              tooltip: '虚拟键盘',
              onPressed: _showKeyboard,
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '断开',
            onPressed: () {
              _sshService.disconnect();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: _connecting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.greenAccent),
                  SizedBox(height: 16),
                  Text('正在连接 SSH...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text('连接失败',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _error = null;
                              _connecting = true;
                            });
                            _connect();
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : TerminalView(
                  _terminal,
                  theme: _termTheme,
                  textStyle: const TerminalStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontFamilyFallback: [
                      'Menlo', 'Consolas', 'Courier New',
                      'Noto Sans Mono CJK SC', 'monospace',
                    ],
                  ),
                  autofocus: true,
                ),
    );
  }

  void _showKeyboard() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      builder: (ctx) => _TerminalKeyboard(
        onKey: (key) => _terminal.textInput(key),
      ),
    );
  }
}

class _TerminalKeyboard extends StatelessWidget {
  final void Function(String key) onKey;

  const _TerminalKeyboard({required this.onKey});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Esc', 'Tab', 'Ctrl', 'Alt', 'Space'],
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
      ['.', '-', '_', '/', '@'],
      ['Enter', 'Backspace'],
    ];
    final keyToChar = <String, String>{
      'Enter': '\n',
      'Backspace': '\x7f',
      'Esc': '\x1b',
      'Tab': '\t',
      'Space': ' ',
    };
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('虚拟键盘',
              style: TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((key) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: key.length > 2
                          ? Colors.blueGrey
                          : const Color(0xFF3C3C3C),
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        onTap: () => onKey(keyToChar[key] ?? key),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Text(key,
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class QuickSshDialog extends StatefulWidget {
  const QuickSshDialog({super.key});

  @override
  State<QuickSshDialog> createState() => _QuickSshDialogState();
}

class _QuickSshDialogState extends State<QuickSshDialog> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController(text: 'root');
  final _passCtrl = TextEditingController();
  bool _useKey = false;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SSH 连接'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                  labelText: '主机地址', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portCtrl,
              decoration: const InputDecoration(
                  labelText: '端口', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                  labelText: '用户名', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
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
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _connect,
          child: const Text('连接'),
        ),
      ],
    );
  }

  void _connect() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;
    final port = int.tryParse(_portCtrl.text.trim()) ?? 22;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SshTerminalPage(
          host: host,
          port: port,
          username: _userCtrl.text.trim(),
          password: _useKey ? null : _passCtrl.text.trim(),
          privateKey: _useKey ? _passCtrl.text.trim() : null,
        ),
      ),
    );
  }
}
