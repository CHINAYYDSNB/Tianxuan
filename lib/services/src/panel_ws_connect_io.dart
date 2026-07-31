import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// IO implementation: connects directly with the 1Panel auth [headers].
WebSocketChannel connectPanelWs(Uri uri, Map<String, dynamic>? headers) {
  return IOWebSocketChannel.connect(uri, headers: headers);
}
