import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../models/desktop_server.dart';
import '../../services/ssh_service.dart';
import '../../data/ssh/terminal_output_buffer.dart';

/// 桌面终端标签页（无 Scaffold，嵌入工作区 Tab）。
class TerminalTab extends StatefulWidget {
  final DesktopServer server;
  const TerminalTab({super.key, required this.server});

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
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
  late final TerminalOutputBuffer _buffer;
  bool _connecting = true;
  String? _error;
  Timer? _keepAliveTimer;
  int _missedPings = 0;
  static const _keepAliveInterval = Duration(seconds: 60);
  static const _maxMissedPings = 3;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 2000);
    _terminal.onOutput = _onTerminalOutput;
    _terminal.onResize = _onTerminalResize;
    _buffer = TerminalOutputBuffer((bytes) {
      _terminal.write(String.fromCharCodes(bytes));
    });
    _sshService.onBytes = _onSshBytes;
    _sshService.onStateChange = _onSshState;
    _connect();
  }

  void _onTerminalOutput(String data) => _sshService.write(data);

  void _onTerminalResize(int w, int h, int pw, int ph) {
    _sshService.resize(w, h);
  }

  void _onSshBytes(List<int> bytes) => _buffer.add(bytes);

  void _onSshState(bool connected) {
    if (!mounted) return;
    setState(() => _connecting = !connected);
    if (connected) {
      _startKeepAlive();
    } else {
      _stopKeepAlive();
    }
  }

  void _startKeepAlive() {
    _stopKeepAlive();
    _missedPings = 0;
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) async {
      final ok = await _sshService.ping();
      if (!ok) {
        _missedPings++;
        if (_missedPings >= _maxMissedPings) {
          _stopKeepAlive();
          if (mounted) setState(() => _connecting = true);
        }
      } else {
        _missedPings = 0;
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  Future<void> _connect() async {
    try {
      await _sshService.connect(
        host: widget.server.host,
        port: widget.server.port,
        username: widget.server.username,
        password: widget.server.password,
        privateKey: widget.server.privateKey,
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
    _stopKeepAlive();
    _buffer.dispose();
    _sshService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: _connecting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.greenAccent),
                  SizedBox(height: 16),
                  Text('正在连接 SSH...', style: TextStyle(color: Colors.grey)),
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
                    Flexible(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
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
