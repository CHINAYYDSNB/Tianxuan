import 'ssh_command_service.dart';

/// 通过 SSH 执行脚本（替代依赖本地代理的 executeViaProxy）。
/// 脚本已上传到服务器路径后，用 bash 执行。
class SshScriptExecutor {
  final SshCommandService _ssh;

  SshScriptExecutor(this._ssh);

  bool get isConnected => _ssh.isConnected;

  /// 执行脚本，返回输出。
  /// [timeout] 默认 60s。
  Future<String> execute(
    String scriptPath, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final result = await _ssh.execute(
      'bash "$scriptPath" 2>&1',
      timeout: timeout,
    );
    if (!result.isSuccess) {
      throw Exception(result.stderr.isEmpty ? '执行失败' : result.stderr);
    }
    return result.stdout;
  }
}
