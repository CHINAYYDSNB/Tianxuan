import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

class SshConfig {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;

  const SshConfig({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    if (password != null) 'password': password,
    if (privateKey != null) 'privateKey': privateKey,
  };
}

class SshResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const SshResult({required this.exitCode, this.stdout = '', this.stderr = ''});

  bool get isSuccess => exitCode == 0;
}

class SshCommandService {
  SSHClient? _client;
  bool _connected = false;
  Timer? _keepAliveTimer;

  bool get isConnected => _connected;

  /// 连接是否已断开（transport closed）
  bool get isBroken => _client != null && _client!.isClosed && !_connected;

  Future<void> connect(SshConfig config) async {
    disconnect();
    final socket = await SSHSocket.connect(
      config.host,
      config.port,
      timeout: const Duration(seconds: 15),
    );

    // Build SSH client
    // 有私钥时优先私钥认证；私钥解析失败则明确抛错，避免静默 fallback
    // 到无凭据认证（那会导致 "All authentication methods failed"）。
    if (config.privateKey != null && config.privateKey!.isNotEmpty) {
      final keyContent = await _readKeyContent(config.privateKey!);
      if (keyContent == null) {
        socket.close();
        throw Exception('私钥内容为空，无法认证');
      }
      SSHKeyPair keyPairs;
      try {
        keyPairs = SSHKeyPair.fromPem(keyContent).first;
      } catch (e) {
        socket.close();
        throw Exception('私钥解析失败: $e');
      }
      _client = SSHClient(
        socket,
        username: config.username,
        identities: [keyPairs],
        onPasswordRequest: () => config.password ?? '',
      );
    } else {
      // 无私钥 → 密码认证（或服务器允许免密）
      _client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => config.password ?? '',
        onUserInfoRequest: (req) => [config.password ?? ''],
      );
    }

    // 等待认证完成：认证失败（SSHAuthFailError 等）会在此抛出，由上层捕获
    await _client!.authenticated;

    _connected = true;
    _startKeepAlive();
  }

  /// Read key content: try as file path first, fallback to treating input as PEM.
  Future<String?> _readKeyContent(String keyInput) async {
    // Try reading as file path
    try {
      final file = File(keyInput);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    // Assume keyInput is already the PEM content
    return keyInput;
  }

  Future<SshResult> execute(String command, {Duration? timeout}) async {
    if (_client == null) {
      return const SshResult(exitCode: -1, stderr: 'SSH not connected');
    }

    try {
      final session = await _client!.execute(command);

      final outBuf = StringBuffer();
      final errBuf = StringBuffer();

      final outSub = session.stdout.listen((d) => outBuf.write(utf8.decode(d)));
      final errSub = session.stderr.listen((d) => errBuf.write(utf8.decode(d)));

      await session.done;
      final exitCode = session.exitCode ?? 0;
      await outSub.cancel();
      await errSub.cancel();

      return SshResult(
        exitCode: exitCode,
        stdout: outBuf.toString(),
        stderr: errBuf.toString(),
      );
    } catch (e) {
      // 连接已断开（transport closed）时标记，供上层自动重连
      if (_client?.isClosed == true) {
        _connected = false;
      }
      return SshResult(exitCode: -1, stderr: e.toString());
    }
  }

  Stream<String> stream(String command) async* {
    if (_client == null) {
      yield 'SSH not connected';
      return;
    }

    try {
      final session = await _client!.execute(command);

      await for (final chunk in session.stdout) {
        yield utf8.decode(chunk);
      }

      await for (final chunk in session.stderr) {
        yield utf8.decode(chunk);
      }

      await session.done;
    } catch (e) {
      yield 'Error: $e';
    }
  }

  /// 启动 keepalive：每 30s ping 一次，防止空闲断连；失败时标记断开
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_connected || _client == null) return;
      execute('echo pong');
    });
  }

  void disconnect() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _client?.close();
    _client = null;
    _connected = false;
  }
}
