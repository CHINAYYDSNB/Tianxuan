import 'package:web_socket_channel/web_socket_channel.dart';

/// Web implementation: browsers forbid custom WS handshake headers, so
/// [headers] is ignored — `server.mjs` injects the 1Panel auth instead.
WebSocketChannel connectPanelWs(Uri uri, Map<String, dynamic>? headers) {
  return WebSocketChannel.connect(uri);
}
