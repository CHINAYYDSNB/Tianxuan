import 'dart:async';
import 'dart:convert';
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

  const SshResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  bool get isSuccess => exitCode == 0;
}

class SshCommandService {
  SSHClient? _client;
  bool _connected = false;

  bool get isConnected => _connected;

  Future<void> connect(SshConfig config) async {
    disconnect();
    final socket = await SSHSocket.connect(
      config.host,
      config.port,
      timeout: const Duration(seconds: 15),
    );

    _client = SSHClient(
      socket,
      username: config.username,
      onPasswordRequest: () => config.password ?? '',
      onUserInfoRequest: (req) => [config.password ?? ''],
    );

    _connected = true;
  }

  Future<SshResult> execute(
    String command, {
    Duration? timeout,
  }) async {
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

  void disconnect() {
    _client?.close();
    _client = null;
    _connected = false;
  }
}
