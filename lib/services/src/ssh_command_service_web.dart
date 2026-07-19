import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  WebSocketChannel? _channel;
  bool _connected = false;
  String? _proxyUrl;
  // Pending exec callbacks
  final _pending = <String, Completer<SshResult>>{};
  final _streamCtrl = <String, StreamController<String>>{};
  int _reqId = 0;

  bool get isConnected => _connected;

  Future<void> connect(SshConfig config) async {
    disconnect();
    _proxyUrl = 'ws://localhost:25569/ssh-proxy';

    _channel = WebSocketChannel.connect(Uri.parse(_proxyUrl!));
    await _channel!.ready;

    // Send connect config
    _channel!.sink.add(jsonEncode({
      'type': 'connect',
      ...config.toJson(),
    }));

    // Wait for ready
    final completer = Completer<void>();
    _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          switch (msg['type']) {
            case 'ready':
              _connected = true;
              completer.complete();
              break;
            case 'exec-result':
              final id = msg['id'] as String?;
              if (id != null && _pending.containsKey(id)) {
                _pending.remove(id)!.complete(SshResult(
                  exitCode: (msg['exitCode'] as num?)?.toInt() ?? -1,
                  stdout: utf8.decode(
                      base64Decode((msg['stdout'] as String?) ?? '')),
                  stderr: utf8.decode(
                      base64Decode((msg['stderr'] as String?) ?? '')),
                ));
              }
              break;
            case 'stream-data':
              final id = msg['id'] as String?;
              if (id != null) {
                final data = utf8.decode(
                    base64Decode((msg['data'] as String?) ?? ''));
                _streamCtrl[id]?.add(data);
              }
              break;
            case 'stream-done':
              final id = msg['id'] as String?;
              if (id != null) {
                _streamCtrl[id]?.close();
                _streamCtrl.remove(id);
              }
              break;
            case 'stream-error':
              final id = msg['id'] as String?;
              if (id != null) {
                _streamCtrl[id]
                    ?.addError('${msg['message']}');
                _streamCtrl[id]?.close();
                _streamCtrl.remove(id);
              }
              break;
            case 'error':
              if (!completer.isCompleted) {
                completer.completeError(
                    '${msg['message']}');
              }
              break;
          }
        } catch (_) {}
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        _connected = false;
      },
      onDone: () {
        _connected = false;
      },
    );

    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('SSH connection timeout'),
    );
  }

  Future<SshResult> execute(
    String command, {
    Duration? timeout,
  }) async {
    if (!_connected || _channel == null) {
      return const SshResult(exitCode: -1, stderr: 'SSH not connected');
    }

    final id = 'exec-${_reqId++}';
    final completer = Completer<SshResult>();
    _pending[id] = completer;

    _channel!.sink.add(jsonEncode({
      'type': 'exec',
      'id': id,
      'command': command,
      'timeout': timeout?.inSeconds ?? 30,
    }));

    try {
      return await completer.future.timeout(
        timeout ?? const Duration(seconds: 60),
        onTimeout: () {
          _pending.remove(id);
          return SshResult(exitCode: -1, stderr: 'Command timed out');
        },
      );
    } catch (e) {
      _pending.remove(id);
      return SshResult(exitCode: -1, stderr: e.toString());
    }
  }

  Stream<String> stream(String command) {
    final id = 'stream-${_reqId++}';
    final controller = StreamController<String>();
    _streamCtrl[id] = controller;

    _channel?.sink.add(jsonEncode({
      'type': 'stream-exec',
      'id': id,
      'command': command,
    }));

    return controller.stream;
  }

  void disconnect() {
    _connected = false;
    for (final c in _pending.values) {
      c.complete(const SshResult(exitCode: -1, stderr: 'Disconnected'));
    }
    _pending.clear();
    for (final c in _streamCtrl.values) {
      c.close();
    }
    _streamCtrl.clear();
    _channel?.sink.close();
    _channel = null;
  }
}
