import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// SSH service for Web — connect via WebSocket proxy.
class SshService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;

  void Function(String data)? onData;
  void Function(List<int> bytes)? onBytes;
  void Function(bool connected)? onStateChange;

  bool get isConnected => _connected;
  dynamic get client => null; // Web has no direct SSHClient

  static String buildProxyUrl(String serverUrl) {
    final uri = Uri.parse(serverUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:25569/ssh-proxy';
  }

  Future<void> connect({
    required String host,
    int port = 22,
    required String username,
    String? password,
    String? privateKey,
    String? proxyUrl,
  }) async {
    if (proxyUrl == null || proxyUrl.isEmpty) {
      proxyUrl = 'ws://localhost:25569/ssh-proxy';
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(proxyUrl));
      await _channel!.ready;

      final config = {
        'type': 'connect',
        'host': host,
        'port': port,
        'username': username,
        if (password != null) 'password': password,
        if (privateKey != null) 'privateKey': privateKey,
      };
      _channel!.sink.add(jsonEncode(config));

      _sub = _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _handleMessage(msg);
        },
        onError: (e) {
          final msg = '\r\n[连接错误] $e\r\n';
          onData?.call(msg);
          _connected = false;
          onStateChange?.call(false);
        },
        onDone: () {
          onData?.call('\r\n[连接已关闭]\r\n');
          _connected = false;
          onStateChange?.call(false);
        },
      );
    } catch (e) {
      onData?.call('\r\n[连接失败] $e\r\n');
      rethrow;
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'ready':
        _connected = true;
        onStateChange?.call(true);
        onData?.call('\r\n[SSH 连接成功]\r\n');
        break;
      case 'data':
        final base64 = msg['data'] as String;
        final bytes = base64Decode(base64);
        onBytes?.call(bytes);
        onData?.call(utf8.decode(bytes));
        break;
      case 'error':
        onData?.call('\r\n[错误] ${msg['message']}\r\n');
        break;
      case 'close':
        onData?.call('\r\n[SSH 会话关闭]\r\n');
        _connected = false;
        onStateChange?.call(false);
        break;
    }
  }

  void resize(int cols, int rows) {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'resize',
      'cols': cols,
      'rows': rows,
    }));
  }

  void write(String input) {
    if (!_connected || _channel == null) return;
    final bytes = utf8.encode(input);
    _channel!.sink.add(jsonEncode({
      'type': 'input',
      'data': base64Encode(bytes),
    }));
  }

  Future<bool> ping() async {
    if (!_connected || _channel == null) return false;
    try {
      _channel!.sink.add(jsonEncode({'type': 'ping'}));
      return true;
    } catch (_) {
      return false;
    }
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    onStateChange?.call(false);
  }
}
