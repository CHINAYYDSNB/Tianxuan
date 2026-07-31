import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/sse_client.dart';

class ContainerLogState {
  final List<String> lines;
  final bool isConnected;
  final String? error;
  final bool isPaused;

  const ContainerLogState({
    this.lines = const [],
    this.isConnected = false,
    this.error,
    this.isPaused = false,
  });

  ContainerLogState copyWith({
    List<String>? lines,
    bool? isConnected,
    String? error,
    bool? isPaused,
  }) {
    return ContainerLogState(
      lines: lines ?? this.lines,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

class ContainerLogNotifier extends StateNotifier<ContainerLogState> {
  StreamSubscription<String>? _subscription;
  final String _containerName;
  final int _tailLines;

  ContainerLogNotifier(this._containerName, {int tailLines = 200})
    : _tailLines = tailLines,
      super(const ContainerLogState());

  /// 通过 1Panel SSE 接口流式拉取容器日志。
  void connect() {
    _subscription?.cancel();
    state = state.copyWith(isConnected: false, error: null);

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
    StateNotifierProvider.family<
      ContainerLogNotifier,
      ContainerLogState,
      String
    >((ref, containerName) {
      return ContainerLogNotifier(containerName);
    });
