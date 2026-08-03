/// 云备份可选项目定义
enum BackupItem {
  servers('服务器配置', '已保存的服务器 + API Key'),
  aiConfig('AI 配置', 'API Endpoint / Key / 模型'),
  theme('个性化设置', '主题配色 + 背景'),
  sshConnections('SSH 连接', 'SSH 主机 / 凭据'),
  logtoTokens('登录状态', 'Casdoor 登录令牌');

  final String label;
  final String description;

  const BackupItem(this.label, this.description);
}

/// 备份内容（version 2）
class BackupPayload {
  final List<BackupItem> items;
  final int version;

  const BackupPayload({required this.items, this.version = 2});

  List<String> get itemNames => items.map((i) => i.name).toList();
}
