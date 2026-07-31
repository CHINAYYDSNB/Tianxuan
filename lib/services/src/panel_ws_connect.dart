/// Platform-aware WebSocket connection for the 1Panel terminal.
///
/// On IO (Android / desktop) the 1Panel auth headers are sent as WebSocket
/// handshake headers. On the web the headers are ignored — the same-origin
/// `server.mjs` proxy (`/panel-terminal`) injects them instead, because
/// browsers forbid custom WS headers.
library panel_ws_connect;

export 'panel_ws_connect_io.dart'
    if (dart.library.html) 'panel_ws_connect_web.dart';
