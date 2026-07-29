import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/script_store_provider.dart';
import '../../api/script_store_api.dart';
import '../../models/script_store_item.dart';

class ScriptDetailPage extends ConsumerStatefulWidget {
  final String id;
  const ScriptDetailPage({super.key, required this.id});

  @override
  ConsumerState<ScriptDetailPage> createState() => _ScriptDetailPageState();
}

class _ScriptDetailPageState extends ConsumerState<ScriptDetailPage> {
  ScriptDetail? _detail;
  bool _loading = true;
  String? _error;
  String? _scriptContent;
  bool _loadingScript = false;
  String? _loadErr;
  final _remotePath = '/opt/scripts/';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ScriptStoreApi.fetchDetail(widget.id);
      if (mounted)
        setState(() {
          _detail = d;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  Future<void> _loadScript() async {
    if (_loadingScript || _detail == null) return;
    setState(() {
      _loadingScript = true;
      _loadErr = null;
    });
    try {
      final c = await ScriptStoreApi.downloadScript(_detail!.downloadUrl);
      if (mounted)
        setState(() {
          _scriptContent = c;
          _loadingScript = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loadErr = '$e';
          _loadingScript = false;
        });
    }
  }

  Future<void> _exec() async {
    if (_detail == null) return;
    if (_scriptContent == null) {
      await _loadScript();
      if (!mounted || _loadErr != null || _scriptContent == null) return;
    }
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('确认执行'),
        content: Text('下载脚本到 $_remotePath 并执行?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认执行'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    ref.read(scriptDownloadStateProvider.notifier).downloading();
    try {
      final ext = _detail!.language == 'python' ? 'py' : 'sh';
      final path = '$_remotePath/start.$ext';
      await ScriptStoreApi.uploadToServer(path, _scriptContent!);
      if (mounted) {
        ref.read(scriptDownloadStateProvider.notifier).preview();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已上传到 $path')));
      }
    } catch (e) {
      if (mounted) {
        ref.read(scriptDownloadStateProvider.notifier).failed();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = ref.watch(scriptDownloadStateProvider);
    final busy =
        _loadingScript ||
        st == ScriptDownloadState.downloading ||
        st == ScriptDownloadState.running;

    return Scaffold(
      appBar: AppBar(title: Text(_detail?.name ?? '加载中...')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _fetch, child: const Text('重试')),
                  ],
                ),
              ),
            )
          : _buildContent(theme, busy, st),
    );
  }

  Widget _buildContent(ThemeData theme, bool busy, ScriptDownloadState st) {
    final d = _detail!;
    final hasContent = _scriptContent != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _Badge(d.language),
                  ],
                ),
                const SizedBox(height: 8),
                Text(d.description, style: theme.textTheme.bodyMedium),
                if (d.author.hasInfo) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(d.author.name, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.update,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'v${d.version} · ${d.updatedAt}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (d.dependencies.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('依赖', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: d.dependencies
                        .map(
                          (dep) => Chip(
                            label: Text(
                              dep,
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('脚本预览', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (!hasContent && !_loadingScript)
                      TextButton.icon(
                        onPressed: _loadScript,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('加载'),
                      ),
                    if (_loadingScript)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (_loadErr != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _loadErr!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                if (hasContent)
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 300),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey.shade900
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _scriptContent!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: theme.brightness == Brightness.dark
                              ? Colors.green.shade300
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: busy ? null : (hasContent ? _exec : _loadScript),
            icon: Icon(hasContent ? Icons.play_arrow : Icons.download),
            label: Text(
              _loadingScript
                  ? '加载中...'
                  : hasContent
                  ? '下载并执行'
                  : '加载脚本',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String lang;
  const _Badge(this.lang);
  @override
  Widget build(BuildContext context) {
    final isPy = lang == 'python';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isPy ? Colors.blue : Colors.green).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPy ? 'Python' : 'Shell',
        style: TextStyle(
          fontSize: 12,
          color: isPy ? Colors.blue : Colors.green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
