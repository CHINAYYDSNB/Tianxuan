import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'src/panel_ws_connect.dart';

/// 1Panel terminal service for Web / Mobile.
///
/// Connects to the 1Panel `GET /api/v2/hosts/terminal` WebSocket endpoint.
/// Without a host `id` the 1Panel agent opens a PTY on the local machine, so
/// no separate SSH credentials are needed — this is the "auto-connect" host
/// terminal.
///
/// On Web the connection goes through the same-origin `server.mjs` proxy
/// (`/panel-terminal`), which injects the 1Panel auth headers. On mobile it
/// connects directly to the 1Panel endpoint with the auth headers set on the
/// WebSocket handshake.
///
/// Wire protocol (1Panel WsSSH):
///   server → client: `{"type":"cmd","data": base64(stdout)}`
///   client → server: `{"type":"cmd","data": base64(input)}`
///   resize:          `{"type":"resize","cols":N,"rows":M}`
class PanelWsSshService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;

  void Function(String data)? onData;
  void Function(List<int> bytes)? onBytes;
  void Function(bool connected)? onStateChange;

  bool get isConnected => _connected;

  /// Web: same-origin proxy URL (see server.mjs `/panel-terminal`).
  /// 从页面来源 [Uri.base] 推导，保证与访问地址同主机同端口：
  /// 经 localhost 隧道、远程 IP、或域名访问都正确（HTTP→ws / HTTPS→wss）。
  /// 注意必须用 `authority`（含端口），否则 `Uri.base` 只取 host 会丢掉端口，
  /// 导致 `ws://localhost/panel-terminal` 连不上。
  static String buildProxyUrl() {
    final base = Uri.base;
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${base.authority}/panel-terminal';
  }

  /// Mobile: direct 1Panel WsSSH endpoint with auth headers.
  static ({Uri uri, Map<String, dynamic> headers}) buildDirectUrl({
    required String apiHost,
    required int apiPort,
    required String apiKey,
    required int cols,
    required int rows,
  }) {
    final scheme = apiPort == 443 ? 'wss' : 'ws';
    final ts = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final token = md5.convert(utf8.encode('1panel$apiKey$ts')).toString();
    final uri = Uri.parse(
      '$scheme://$apiHost:$apiPort/api/v2/hosts/terminal?cols=$cols&rows=$rows',
    );
    final headers = {'1Panel-Token': token, '1Panel-Timestamp': ts.toString()};
    return (uri: uri, headers: headers);
  }

  /// WebSocket 握手的最大等待时间。超过则抛 [TimeoutException]，避免界面
  /// 卡在「正在拉取」且无任何请求记录（典型的代理/网络不可达）。
  Duration connectTimeout;

  PanelWsSshService({this.connectTimeout = const Duration(seconds: 15)});

  Future<void> connect({
    int cols = 80,
    int rows = 24,
    String? proxyUrl,
    // Mobile direct connection params (ignored on web).
    String? apiHost,
    int? apiPort,
    String? apiKey,
  }) async {
    Uri uri;
    Map<String, dynamic>? headers;

    if (kIsWeb) {
      final url = (proxyUrl != null && proxyUrl.isNotEmpty)
          ? proxyUrl
          : buildProxyUrl();
      uri = Uri.parse(url);
    } else {
      if (apiHost == null || apiPort == null || apiKey == null) {
        throw Exception('1Panel 终端需要服务端配置（host / port / apiKey）');
      }
      final direct = buildDirectUrl(
        apiHost: apiHost,
        apiPort: apiPort,
        apiKey: apiKey,
        cols: cols,
        rows: rows,
      );
      uri = direct.uri;
      headers = direct.headers;
    }

    WebSocketChannel? pending;
    try {
      pending = connectPanelWs(uri, headers);
      // 带超时的握手：超时或失败时及时关闭通道并给出明确错误。
      await pending.ready.timeout(
        connectTimeout,
        onTimeout: () {
          try {
            pending?.sink.close();
          } catch (_) {}
          throw TimeoutException(
            '终端连接超时（${connectTimeout.inSeconds}s）：请确认 server.mjs 代理是否运行、地址是否可达。',
            connectTimeout,
          );
        },
      );
      _channel = pending;

      // Set the initial PTY size immediately; the real size follows once the
      // TerminalView is laid out and fires onResize.
      resize(cols, rows);

      _sub = _channel!.stream.listen(
        _handleMessage,
        onError: (e) {
          onData?.call('\r\n[1Panel 终端连接错误] $e\r\n');
          _connected = false;
          onStateChange?.call(false);
        },
        onDone: () {
          onData?.call('\r\n[1Panel 终端已关闭]\r\n');
          _connected = false;
          onStateChange?.call(false);
        },
      );
    } catch (e) {
      onData?.call('\r\n[1Panel 终端连接失败] $e\r\n');
      rethrow;
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      // Only `cmd` frames carry terminal data; heartbeat / other frames are
      // ignored.
      if (msg['type'] != 'cmd') return;
      final b64 = (msg['data'] as String?) ?? '';
      final bytes = base64Decode(b64);
      onBytes?.call(bytes);
      onData?.call(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      // Non-JSON heartbeat frames are ignored.
    }
  }

  void resize(int cols, int rows) {
    if (_channel == null) return;
    _channel!.sink.add(
      jsonEncode({'type': 'resize', 'cols': cols, 'rows': rows}),
    );
  }

  void write(String input) {
    if (_channel == null) return;
    final bytes = utf8.encode(input);
    _channel!.sink.add(
      jsonEncode({'type': 'cmd', 'data': base64Encode(bytes)}),
    );
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    onStateChange?.call(false);
  }
}
