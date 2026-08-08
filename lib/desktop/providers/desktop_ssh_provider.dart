import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/desktop_server.dart';
import '../../services/ssh_command_service.dart';

/// 桌面端每服务器一个 SshCommandService（文件/监控/命令复用）。
final desktopSshCommandProvider =
    Provider.family<SshCommandService, DesktopServer>((ref, server) {
      final svc = SshCommandService();
      ref.onDispose(svc.disconnect);
      return svc;
    });

/// 建立连接（若未连接）。
Future<String?> desktopSshConnect(DesktopServer server) async {
  final svc = SshCommandService();
  try {
    await svc.connect(
      SshConfig(
        host: server.host,
        port: server.port,
        username: server.username,
        password: server.password,
        privateKey: server.privateKey,
      ),
    );
    return null;
  } catch (e) {
    svc.disconnect();
    return e.toString().replaceAll('Exception: ', '');
  }
}
