import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tianxuan/models/script_store.dart';
import 'package:tianxuan/providers/ssh_connection_provider.dart';
import 'package:tianxuan/services/ssh_command_service.dart';
import 'package:tianxuan/services/script_store_service.dart';

class ScriptDetailPage extends ConsumerStatefulWidget {
  final String id;
  const ScriptDetailPage({super.key, required this.id});

  @override
  ConsumerState<ScriptDetailPage> createState() => _ScriptDetailPageState();
}

class _ScriptDetailPageState extends ConsumerState<ScriptDetailPage> {
  late final Future<ScriptDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ScriptStoreService().getDetail(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('脚本详情')),
      body: FutureBuilder<ScriptDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final theme = Theme.of(context);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      snap.error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _future = ScriptStoreService().getDetail(widget.id);
                      }),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _ScriptDetailBody(detail: snap.data!);
        },
      ),
    );
  }
}

class _ScriptDetailBody extends ConsumerStatefulWidget {
  final ScriptDetail detail;
  const _ScriptDetailBody({required this.detail});

  @override
  ConsumerState<_ScriptDetailBody> createState() => _ScriptDetailBodyState();
}

class _ScriptDetailBodyState extends ConsumerState<_ScriptDetailBody> {
  late final CodeController _codeCtrl;
  bool _sourceLoading = false;
  String? _sourceError;

  @override
  void initState() {
    super.initState();
    _codeCtrl = CodeController(readOnly: true);
    _loadSource();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSource() async {
    if (widget.detail.source.isNotEmpty) {
      _codeCtrl.text = widget.detail.source;
      return;
    }
    final url = widget.detail.rawUrl;
    if (url.isEmpty) return;
    setState(() => _sourceLoading = true);
    try {
      final text = await ScriptStoreService().fetchText(url);
      _codeCtrl.text = text;
    } catch (e) {
      _sourceError = '$e';
    } finally {
      if (mounted) setState(() => _sourceLoading = false);
    }
  }

  void _install() {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未连接 SSH，请先在连接页建立连接'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InstallTerminal(detail: widget.detail, ssh: ssh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.detail;
    final connected = ref.watch(sshServiceProvider) != null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(d.desc, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.category_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text(d.category, style: theme.textTheme.bodySmall),
                          const Spacer(),
                          const Icon(Icons.person_outline, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              d.author.isEmpty ? '未知作者' : d.author,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('源码', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          if (_sourceLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      if (_sourceError != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _sourceError!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      Container(
                        width: double.infinity,
                        height: 320,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CodeField(
                          controller: _codeCtrl,
                          minLines: 1,
                          maxLines: null,
                          textStyle: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: connected ? _install : null,
                icon: const Icon(Icons.terminal),
                label: const Text('安装'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 安装终端：下载脚本到临时文件，经 SSH 执行并流式输出。
class _InstallTerminal extends StatefulWidget {
  final ScriptDetail detail;
  final SshCommandService ssh;
  const _InstallTerminal({required this.detail, required this.ssh});

  @override
  State<_InstallTerminal> createState() => _InstallTerminalState();
}

class _InstallTerminalState extends State<_InstallTerminal> {
  final List<String> _lines = [];
  bool _running = true;
  bool _hadError = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _append(String s) {
    if (mounted) setState(() => _lines.add(s));
  }

  Future<void> _run() async {
    try {
      _append('> 下载脚本: ${widget.detail.downloadUrl}');
      final script = await ScriptStoreService().fetchText(widget.detail.downloadUrl);
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'script_${widget.detail.id}.sh'));
      await file.writeAsString(script);
      _append('> 已保存到 ${file.path}');
      _append('\$ bash ${file.path}');

      _sub = widget.ssh.stream('bash ${file.path}').listen(
        (chunk) {
          _append(chunk);
          if (chunk.startsWith('Error:')) _hadError = true;
        },
        onDone: () {
          _append(_hadError ? '✗ 安装失败' : '✓ 安装完成');
          if (mounted) setState(() => _running = false);
        },
      );
    } catch (e) {
      _append('错误: $e');
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Text('安装终端', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (_running)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _lines.join('\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!_running)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_hadError ? '关闭' : '完成'),
              ),
            ),
        ],
      ),
    );
  }
}
