import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/container_log_provider.dart';

class ContainerLogPage extends ConsumerStatefulWidget {
  final String containerName;

  const ContainerLogPage({super.key, required this.containerName});

  @override
  ConsumerState<ContainerLogPage> createState() => _ContainerLogPageState();
}

class _ContainerLogPageState extends ConsumerState<ContainerLogPage> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // Start SSE connection
    Future.microtask(() {
      ref.read(containerLogProvider(widget.containerName).notifier).connect();
    });
  }

  @override
  void dispose() {
    ref
        .read(containerLogProvider(widget.containerName).notifier)
        .disconnect();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(containerLogProvider(widget.containerName));
    final notifier = ref.read(containerLogProvider(widget.containerName).notifier);
    final theme = Theme.of(context);

    // Auto-scroll when new lines arrive
    if (state.lines.isNotEmpty && _autoScroll) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.containerName} 日志'),
        actions: [
          // Source switch
          TextButton.icon(
            icon: Icon(
              state.source == LogSource.ssh ? Icons.terminal : Icons.wifi,
              size: 16,
            ),
            label: Text(
              state.source == LogSource.ssh ? 'SSH' : '1Panel',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => notifier.switchSource(
              state.source == LogSource.ssh ? LogSource.sse : LogSource.ssh,
            ),
          ),
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              state.isConnected ? Icons.wifi : Icons.wifi_off,
              size: 18,
              color: state.isConnected ? Colors.green : Colors.red,
            ),
          ),
          // Auto-scroll toggle
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
            ),
            tooltip: _autoScroll ? '自动滚动' : '手动滚动',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          // Pause/resume
          IconButton(
            icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: state.isPaused ? '继续' : '暂停',
            onPressed: () => notifier.togglePause(),
          ),
          // Clear
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: '清空',
            onPressed: () => notifier.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '连接断开: ${state.error}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => notifier.connect(),
                    child: const Text('重连'),
                  ),
                ],
              ),
            ),
          if (state.isPaused)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.orange.withValues(alpha: 0.2),
              child: Text('已暂停',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.orange)),
            ),
          // Log content
          Expanded(
            child: state.lines.isEmpty && state.isConnected
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: state.lines.length,
                    itemBuilder: (ctx, i) {
                      final line = state.lines[i];
                      return _LogLine(text: line);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final String text;

  const _LogLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}
