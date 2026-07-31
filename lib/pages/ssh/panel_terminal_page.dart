import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/panel_ws_ssh_service.dart';
import '../../services/storage_service.dart';
import '../../data/ssh/terminal_output_buffer.dart';
import 'package:xterm/xterm.dart';

/// 1Panel 主机终端：打开 1Panel 服务器本机 PTY，无需 SSH 凭据（自动连接）。
class PanelTerminalPage extends StatefulWidget {
  const PanelTerminalPage({super.key});

  @override
  State<PanelTerminalPage> createState() => _PanelTerminalPageState();
}

class _PanelTerminalPageState extends State<PanelTerminalPage> {
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
  final _panelService = PanelWsSshService();
  late final TerminalOutputBuffer _buffer;
  bool _connecting = true;
  String? _error;

  // Mobile direct-connection params (filled from storage).
  String? _apiHost;
  int? _apiPort;
  String? _apiKey;

  // Reconnect
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 2000);
    _terminal.onOutput = _onTerminalOutput;
    _terminal.onResize = _onTerminalResize;

    _buffer = TerminalOutputBuffer((bytes) {
      _terminal.write(String.fromCharCodes(bytes));
    });

    _panelService.onBytes = _onPanelBytes;
    _panelService.onStateChange = _onPanelState;
    _connect();
  }

  void _onTerminalOutput(String data) {
    _panelService.write(data);
  }

  void _onTerminalResize(int w, int h, int pw, int ph) {
    _panelService.resize(w, h);
  }

  void _onPanelBytes(List<int> bytes) {
    _buffer.add(bytes);
  }

  void _onPanelState(bool connected) {
    if (!mounted) return;
    setState(() {
      _connecting = !connected;
    });
    if (!connected && !_isReconnecting) {
      _startReconnect();
    }
  }

  // ─── Reconnect ───

  Future<void> _startReconnect() async {
    if (_isReconnecting) return;
    _isReconnecting = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('终端连接断开'),
        content: const Text('正在尝试重新连接...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (ok != true) {
      _isReconnecting = false;
      if (mounted) Navigator.pop(context);
      return;
    }

    var attempt = 0;
    const maxAttempts = 10;
    const baseDelayMs = 200;
    const maxDelayMs = 3000;

    while (attempt < maxAttempts && mounted && _isReconnecting) {
      attempt++;
      try {
        _panelService.disconnect();
        await _connect();
        if (mounted && _panelService.isConnected) {
          _isReconnecting = false;
          _buffer.flushNow();
          if (mounted) {
            setState(() {
              _connecting = false;
              _error = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已重新连接'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }
      } catch (_) {}

      final delayMs = (baseDelayMs * (1 << (attempt - 1))).clamp(0, maxDelayMs);
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    _isReconnecting = false;
    if (mounted) {
      setState(() {
        _connecting = false;
        _error = '重连失败（已尝试 $maxAttempts 次）';
      });
    }
  }

  // ─── Connect ───

  Future<void> _connect() async {
    try {
      if (!kIsWeb) {
        final url = await StorageService.instance.getServerUrl();
        final key = await StorageService.instance.getApiKey();
        if (url == null || url.isEmpty || key == null || key.isEmpty) {
          if (mounted) {
            setState(() {
              _connecting = false;
              _error = '未配置 1Panel 服务器，请先在设置中连接';
            });
          }
          return;
        }
        final u = Uri.parse(url);
        _apiHost = u.host;
        _apiPort = u.port;
        _apiKey = key;
      }
      await _panelService.connect(
        cols: 80,
        rows: 24,
        apiHost: _apiHost,
        apiPort: _apiPort,
        apiKey: _apiKey,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _buffer.dispose();
    _panelService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1Panel 主机终端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '断开',
            onPressed: () {
              _panelService.disconnect();
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
                  Text('正在连接主机终端...', style: TextStyle(color: Colors.grey)),
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '连接失败',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
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
                  'Menlo',
                  'Consolas',
                  'Courier New',
                  'Noto Sans Mono CJK SC',
                  'monospace',
                ],
              ),
              autofocus: true,
            ),
    );
  }
}
