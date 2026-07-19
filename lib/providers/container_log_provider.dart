import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/sse_client.dart';
import '../services/docker_service.dart';
import '../services/ssh_command_service.dart';
import 'ssh_connection_provider.dart';

enum LogSource { ssh, sse }

class ContainerLogState {
  final List<String> lines;
  final bool isConnected;
  final String? error;
  final bool isPaused;
  final LogSource source;

  const ContainerLogState({
    this.lines = const [],
    this.isConnected = false,
    this.error,
    this.isPaused = false,
    this.source = LogSource.ssh,
  });

  ContainerLogState copyWith({
    List<String>? lines,
    bool? isConnected,
    String? error,
    bool? isPaused,
    LogSource? source,
  }) {
    return ContainerLogState(
      lines: lines ?? this.lines,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      isPaused: isPaused ?? this.isPaused,
      source: source ?? this.source,
    );
  }
}

class ContainerLogNotifier extends StateNotifier<ContainerLogState> {
  StreamSubscription<String>? _subscription;
  final String _containerName;
  final int _tailLines;
  final SshCommandService? _ssh;

  ContainerLogNotifier(this._containerName, {int tailLines = 200, SshCommandService? ssh})
      : _tailLines = tailLines,
        _ssh = ssh,
        super(const ContainerLogState());

  void connect({LogSource? source}) {
    _subscription?.cancel();
    final src = source ?? state.source;
    state = state.copyWith(isConnected: false, error: null, source: src);

    if (src == LogSource.sse) {
      _connectSse();
    } else {
      _connectSsh();
    }
  }

  void _connectSsh() {
    if (_ssh == null) {
      // SSH not connected, try SSE fallback
      _connectSse();
      return;
    }
    final svc = DockerService(_ssh);
    final stream = svc.logs(_containerName, tail: _tailLines, follow: true);

    _subscription = stream.listen(
      (line) {
        if (state.isPaused) return;
        final updated = [...state.lines, line];
        if (updated.length > 1000) {
          updated.removeRange(0, updated.length - 1000);
        }
        state = state.copyWith(lines: updated, isConnected: true);
      },
      onError: (e) {
        // SSH log stream failed, fallback to SSE
        state = state.copyWith(error: 'SSH log error: $e');
        _connectSse();
      },
      onDone: () {
        state = state.copyWith(isConnected: false);
      },
    );
  }

  void _connectSse() {
    _subscription?.cancel();
    state = state.copyWith(source: LogSource.sse);

    final stream = SseClient.connect(
      '/containers/search/log',
      queryParams: {
        'container': _containerName,
        'tail': _tailLines.toString(),
        'follow': 'true',
      },
    );

    _subscription = stream.listen(
      (line) {
        if (state.isPaused) return;
        final updated = [...state.lines, line];
        if (updated.length > 1000) {
          updated.removeRange(0, updated.length - 1000);
        }
        state = state.copyWith(lines: updated, isConnected: true);
      },
      onError: (e) {
        state = state.copyWith(isConnected: false, error: e.toString());
      },
      onDone: () {
        state = state.copyWith(isConnected: false);
      },
    );
  }

  void switchSource(LogSource source) {
    connect(source: source);
  }

  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  void clear() {
    state = state.copyWith(lines: []);
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(isConnected: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final containerLogProvider =
    StateNotifierProvider.family<ContainerLogNotifier, ContainerLogState, String>(
  (ref, containerName) {
    final ssh = ref.watch(sshServiceProvider);
    return ContainerLogNotifier(containerName, ssh: ssh);
  },
);
