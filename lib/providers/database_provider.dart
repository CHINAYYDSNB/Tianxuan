import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import 'ssh_connection_provider.dart';

/// 数据库管理服务：SSH 已连接时可用（自动检测/认证/库/用户管理）
final databaseServiceProvider = Provider<DatabaseService?>((ref) {
  final ssh = ref.watch(sshServiceProvider);
  if (ssh == null || !ssh.isConnected) return null;
  return DatabaseService(ssh);
});
