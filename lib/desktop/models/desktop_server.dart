class DesktopServer {
  final String id;
  String name;
  String host;
  int port;
  String username;
  String? password;
  String? privateKey;

  /// 可选：面板网页地址（1Panel/宝塔），webview 打开用
  String? panelUrl;

  DesktopServer({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    this.username = 'root',
    this.password,
    this.privateKey,
    this.panelUrl,
  });

  bool get hasCredential =>
      (password != null && password!.isNotEmpty) ||
      (privateKey != null && privateKey!.isNotEmpty);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    if (panelUrl != null && panelUrl!.isNotEmpty) 'panelUrl': panelUrl,
  };

  factory DesktopServer.fromJson(Map<String, dynamic> m) => DesktopServer(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    host: m['host']?.toString() ?? '',
    port: m['port'] as int? ?? 22,
    username: m['username']?.toString() ?? 'root',
    panelUrl: m['panelUrl']?.toString(),
  );
}
