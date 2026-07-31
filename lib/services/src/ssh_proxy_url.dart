/// Build the same-origin WebSocket URL for the server-side SSH proxy.
///
/// The web app is always served by `server.mjs` on the same origin/port that
/// hosts the `/ssh-proxy` WebSocket upgrade route, so we can derive the URL
/// directly from `Uri.base` instead of hardcoding a host/port.
String buildSshProxyUrl() {
  final origin = Uri.base;
  final scheme = origin.scheme == 'https' ? 'wss' : 'ws';
  return '$scheme://${origin.host}:${origin.port}/ssh-proxy';
}
