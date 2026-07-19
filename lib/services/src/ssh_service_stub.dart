import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

/// SSH service for APK — direct SSH via dartssh2.
class SshService {
  SSHClient? _client;
  SSHSession? _session;
  bool _connected = false;

  void Function(String data)? onData;
  void Function(List<int> bytes)? onBytes;
  void Function(bool connected)? onStateChange;

  bool get isConnected => _connected;
  SSHClient? get client => _client;

  /// Build proxy URL (APK 不用, 保留兼容).
  static String buildProxyUrl(String serverUrl) => '';

  Future<void> connect({
    required String host,
    int port = 22,
    required String username,
    String? password,
    String? privateKey,
    String? proxyUrl,
  }) async {
    try {
      final socket = await SSHSocket.connect(host, port,
          timeout: const Duration(seconds: 10));

      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
        onUserInfoRequest: (req) => [password ?? ''],
      );
      _client = client;

      final shell = await client.shell(
        pty: const SSHPtyConfig(
          type: 'xterm-256color',
          width: 80,
          height: 24,
        ),
      );
      _session = shell;

      shell.stdout.listen(
        (data) {
          onBytes?.call(data);
          onData?.call(utf8.decode(data));
        },
        onError: (e) {
          onData?.call('\r\n[连接错误] $e\r\n');
          _connected = false;
          onStateChange?.call(false);
        },
        onDone: () {
          onData?.call('\r\n[SSH 会话关闭]\r\n');
          _connected = false;
          onStateChange?.call(false);
        },
        cancelOnError: false,
      );

      _connected = true;
      onStateChange?.call(true);
      onData?.call('\r\n[SSH 连接成功]\r\n');
    } catch (e) {
      onData?.call('\r\n[连接失败] $e\r\n');
      rethrow;
    }
  }

  void resize(int cols, int rows) {
    _session?.resizeTerminal(cols, rows);
  }

  void write(String input) {
    _session?.write(utf8.encode(input));
  }

  /// Keep-alive ping via SSH exec. Returns true if connection is healthy.
  Future<bool> ping() async {
    if (_client == null || !_connected) return false;
    try {
      final session = await _client!.execute('echo pong');
      await session.done.timeout(const Duration(seconds: 10));
      return session.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void disconnect() {
    _session?.close();
    _client?.close();
    _client = null;
    _session = null;
    _connected = false;
    onStateChange?.call(false);
  }
}
