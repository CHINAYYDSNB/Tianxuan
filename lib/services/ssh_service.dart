import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SshService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;

  /// 收到终端输出的回调（从 SSH 读到数据后写入 xterm）
  void Function(String data)? onData;

  /// 连接/断开状态变化回调
  void Function(bool connected)? onStateChange;

  bool get isConnected => _connected;

  /// 从 1Panel 服务器 URL 构建 SSH proxy WebSocket 地址
  /// APK: 连服务器上的 ssh-proxy (port 25569)
  /// Web: 连本地 server.mjs (port 25568)
  static String buildProxyUrl(String serverUrl) {
    final uri = Uri.parse(serverUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:25569/';
  }

  /// 连接 SSH 服务器通过 WebSocket 代理
  /// [proxyUrl] — WebSocket 代理地址（APK: 连 1Panel 服务器的 SSH proxy）
  Future<void> connect({
    required String host,
    int port = 22,
    required String username,
    String? password,
    String? privateKey,
    String? proxyUrl,
  }) async {
    if (proxyUrl == null || proxyUrl.isEmpty) {
      proxyUrl = 'ws://localhost:25568/ssh-proxy'; // Web dev fallback
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(proxyUrl));
      await _channel!.ready;

      // 发送连接配置
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

  /// 发送 resize 事件
  void resize(int cols, int rows) {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'resize',
      'cols': cols,
      'rows': rows,
    }));
  }

  /// 发送键盘输入（来自 xterm onOutput）
  void write(String input) {
    if (!_connected || _channel == null) return;
    final bytes = utf8.encode(input);
    _channel!.sink.add(jsonEncode({
      'type': 'input',
      'data': base64Encode(bytes),
    }));
  }

  /// 断开
  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    onStateChange?.call(false);
  }
}
